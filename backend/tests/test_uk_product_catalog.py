"""UK proposals must not fabricate packs, provenance, national stock or writes."""

import asyncio
from copy import deepcopy
from dataclasses import FrozenInstanceError
from datetime import date, timedelta
from decimal import Decimal
from uuid import UUID, uuid4

import pytest
from pydantic import ValidationError

from app.db.uk_product_catalog import (
    WRITE_BLOCKERS,
    CanonicalProductReference,
    UKCatalogueWriteBlocked,
    UKProductProposal,
    apply_uk_product_catalogue,
    plan_uk_product_catalogue,
)
from app.db.uk_store_catalog import UK_STORES


AS_OF = date(2026, 10, 15)
CANONICAL_ID = UUID("00000000-0000-4000-8000-000000000001")


def example_row():
    # Synthetic test fixture, not a factual retailer product/price observation.
    source = {
        "url": "https://www.tesco.com/groceries/en-GB/products/test-fixture",
        "publisher": "Synthetic test fixture",
        "checked_on": AS_OF.isoformat(),
    }
    return {
        "country_code": "GB",
        "retailer_slug": "tesco",
        "retailer_sku": "test-fixture",
        "canonical_product_id": str(CANONICAL_ID),
        "name_en": "Synthetic oats",
        "package": {"quantity": "500", "unit": "g", "source": deepcopy(source)},
        "price": {
            "amount": "1.25", "currency_code": "GBP", "kind": "observed",
            "source": deepcopy(source),
        },
        "availability_scope": "online_catalogue",
        "availability_status": "available_online",
        "availability_source": deepcopy(source),
    }


def canonical_references(*, unit="g", review_status="approved"):
    return {CANONICAL_ID: CanonicalProductReference(
        product_id=CANONICAL_ID, base_unit=unit, review_status=review_status,
    )}


def plan(rows, **kwargs):
    return plan_uk_product_catalogue(
        rows, canonical_products=canonical_references(), as_of=AS_OF, **kwargs,
    )


def test_one_row_targets_only_one_store_and_keeps_quoted_local_pack():
    proposal_plan = plan([example_row()])
    assert len(proposal_plan.actions) == 1
    proposal = proposal_plan.actions[0].proposal
    assert proposal.store_id == next(store.id for store in UK_STORES if store.slug == "tesco")
    assert proposal.country_code == "GB"
    assert proposal.package.quantity == Decimal("500")
    assert proposal.package.unit == "g"
    assert proposal.price.amount == Decimal("1.25")
    assert proposal.price.currency_code == "GBP"
    assert proposal.availability_scope == "online_catalogue"
    assert proposal.availability_status == "available_online"
    assert proposal_plan.can_write is False
    assert proposal_plan.write_blockers == WRITE_BLOCKERS


def test_missing_package_never_becomes_100_grams():
    row = example_row()
    del row["package"]["quantity"]
    with pytest.raises(ValidationError):
        plan([row])
    # A genuine, explicitly sourced 100 g pack is nevertheless valid.
    row["package"]["quantity"] = "100"
    assert plan([row]).actions[0].proposal.package.quantity == Decimal("100")


def test_online_listing_is_not_implicitly_in_stock():
    row = example_row()
    del row["availability_status"]
    with pytest.raises(ValidationError):
        plan([row])
    for status in ("unknown", "out_of_stock"):
        row["availability_status"] = status
        proposal_plan = plan([row])
        assert proposal_plan.actions[0].proposal.availability_status == status
        assert proposal_plan.can_write is False


@pytest.mark.parametrize("quantity", ["0", "-1", "NaN", "Infinity", True, 500.0, "1.0001"])
def test_invalid_or_inexact_package_is_rejected(quantity):
    row = example_row()
    row["package"]["quantity"] = quantity
    with pytest.raises(ValidationError):
        plan([row])


@pytest.mark.parametrize("amount", ["0", "-1", "NaN", "Infinity", True, 1.25, "1.001"])
def test_invalid_or_inexact_price_is_rejected(amount):
    row = example_row()
    row["price"]["amount"] = amount
    with pytest.raises(ValidationError):
        plan([row])


@pytest.mark.parametrize(("field", "value"), [
    ("country_code", "PL"), ("retailer_slug", "unknown-retailer"),
    ("availability_scope", "all_branches"), ("retailer_sku", "../sku"),
    ("name_en", "  "),
])
def test_rejects_other_markets_ambiguous_identity_and_national_stock_claim(field, value):
    row = example_row()
    row[field] = value
    with pytest.raises(ValidationError):
        plan([row])


def test_a_pln_price_cannot_become_gbp_by_omitting_country_context():
    row = example_row()
    row["price"]["currency_code"] = "PLN"
    with pytest.raises(ValidationError):
        plan([row])


def test_estimate_is_explicit_and_requires_a_reason():
    row = example_row()
    row["price"]["kind"] = "estimate"
    with pytest.raises(ValidationError, match="requires an explicit"):
        plan([row])
    row["price"]["estimate_reason"] = "Local reviewer estimate using the linked UK pack listing."
    proposal = plan([row]).actions[0].proposal
    assert proposal.price.kind == "estimate"
    assert proposal.price.estimate_reason.startswith("Local reviewer")
    assert not plan([row]).can_write


@pytest.mark.parametrize("source_key", ["package", "price", "availability_source"])
@pytest.mark.parametrize("url", [
    "http://www.tesco.com/product/1", "https://tesco.com.attacker.example/product/1",
    "https://www.sainsburys.co.uk/groceries/product/1", "https://pl.openfoodfacts.org/product/1",
    "https://user:password@www.tesco.com/product/1", "https://localhost/product/1",
    "https://www.tesco.com:8443/product/1", "https://www.tesco.com/product/1#secret",
])
def test_each_source_requires_the_specific_retailer_https_domain(source_key, url):
    row = example_row()
    source = row[source_key] if source_key == "availability_source" else row[source_key]["source"]
    source["url"] = url
    with pytest.raises(ValidationError):
        plan([row])


@pytest.mark.parametrize("days", [-1, 31])
@pytest.mark.parametrize("source_key", ["package", "price", "availability_source"])
def test_rejects_future_and_expired_evidence_for_each_observation(days, source_key):
    row = example_row()
    source = row[source_key] if source_key == "availability_source" else row[source_key]["source"]
    source["checked_on"] = (AS_OF - timedelta(days=days)).isoformat()
    with pytest.raises(ValueError, match="future-dated or too old"):
        plan([row])


@pytest.mark.parametrize("max_age", [0, 366, True, 30.5])
def test_freshness_policy_cannot_be_bypassed_with_invalid_type_or_range(max_age):
    with pytest.raises(ValueError, match="freshness"):
        plan([example_row()], max_evidence_age_days=max_age)


def test_explicit_approved_mapping_and_matching_dimension_are_mandatory():
    row = example_row()
    with pytest.raises(ValueError, match="explicit existing"):
        plan_uk_product_catalogue([row], canonical_products={}, as_of=AS_OF)
    for status in ("pending", "rejected"):
        with pytest.raises(ValueError, match="approved canonical"):
            plan_uk_product_catalogue(
                [row], canonical_products=canonical_references(review_status=status), as_of=AS_OF,
            )
    with pytest.raises(ValueError, match="dimension"):
        plan_uk_product_catalogue(
            [row], canonical_products=canonical_references(unit="ml"), as_of=AS_OF,
        )


def test_duplicate_inputs_are_idempotent_and_equivalent_decimal_formats_have_same_hash():
    row = example_row()
    other = deepcopy(row)
    other["package"]["quantity"] = "500.000"
    other["price"]["amount"] = "1.250"
    first = plan([row, other])
    assert len(first.actions) == 1
    assert first.actions[0].action == "new_proposal"
    proposal = first.actions[0].proposal
    repeated = plan([other], previous_fingerprints={proposal.proposal_id: proposal.fingerprint})
    assert repeated.actions[0].action == "unchanged"


def test_revision_preserves_identity_but_never_silently_overwrites_stock():
    original = plan([example_row()]).actions[0].proposal
    revised = example_row()
    revised["price"]["amount"] = "1.30"
    result = plan([revised], previous_fingerprints={original.proposal_id: original.fingerprint})
    assert result.actions[0].action == "revise_proposal"
    assert result.actions[0].proposal.proposal_id == original.proposal_id
    assert result.can_write is False


def test_conflicting_duplicate_sku_aborts_whole_batch():
    row = example_row()
    other = deepcopy(row)
    other["package"]["quantity"] = "250"
    with pytest.raises(ValueError, match="Conflicting observations"):
        plan([row, other])


def test_a_second_sku_is_a_separate_pack_proposal_not_a_canonical_product_overwrite():
    row = example_row()
    other = deepcopy(row)
    other["retailer_sku"] = "another-test-fixture"
    other["package"]["quantity"] = "250"
    result = plan([row, other])
    assert len({action.proposal.proposal_id for action in result.actions}) == 2
    assert {action.proposal.package.quantity for action in result.actions} == {Decimal("250"), Decimal("500")}
    assert {action.proposal.canonical_product_id for action in result.actions} == {CANONICAL_ID}
    assert not result.can_write


def test_plan_order_is_deterministic_independent_of_input_order():
    rows = [example_row(), example_row()]
    rows[1]["retailer_sku"] = "another-test-fixture"
    assert plan(rows) == plan(reversed(rows))


def test_unknown_fields_are_not_silently_discarded():
    row = example_row()
    row["is_available_everywhere"] = True
    with pytest.raises(ValidationError):
        plan([row])


def test_constructed_instances_cannot_bypass_validation():
    unsafe = UKProductProposal.model_construct(**{**example_row(), "country_code": "PL"})
    with pytest.raises(ValidationError):
        plan([unsafe])


def test_invalid_previous_hash_does_not_hide_a_revision():
    with pytest.raises(ValueError, match="SHA-256"):
        plan([example_row()], previous_fingerprints={uuid4(): "anything"})


@pytest.mark.parametrize("rows", [[], [example_row()]])
def test_persistence_is_blocked_before_any_session_access(rows):
    class UntouchableSession:
        def __getattribute__(self, name):
            raise AssertionError(f"No DB access is allowed: {name}")

    with pytest.raises(UKCatalogueWriteBlocked, match="dry-run only"):
        asyncio.run(apply_uk_product_catalogue(UntouchableSession(), plan(rows)))


def test_prepared_plan_and_nested_provenance_are_immutable():
    proposal_plan = plan([example_row()])
    with pytest.raises(FrozenInstanceError):
        proposal_plan.as_of = AS_OF  # type: ignore[misc]
    with pytest.raises(ValidationError):
        proposal_plan.actions[0].proposal.package.quantity = Decimal("1")
    with pytest.raises(ValidationError):
        proposal_plan.actions[0].proposal.price.source.publisher = "Unverified"
