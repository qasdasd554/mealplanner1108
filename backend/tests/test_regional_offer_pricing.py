"""Synthetic UK packs/prices only; no assertions about real retailer stock."""

from datetime import date, datetime, timezone, timedelta
from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.db.uk_product_catalog import UKProductProposal
from app.services.regional_offer_pricing import normalize_requirement, select_uk_offer_quote


TODAY = date(2026, 10, 16)
PRODUCT = uuid4()


def offer(*, sku="test-500", quantity="500", unit="g", price="2.00", kind="observed",
          status="available_online", checked=TODAY, retailer="tesco"):
    domain = "tesco.com" if retailer == "tesco" else "lidl.co.uk"
    source = {"url": f"https://www.{domain}/synthetic-test/{sku}",
              "publisher": "Synthetic fixture", "checked_on": checked.isoformat()}
    proposal = UKProductProposal.model_validate({
        "retailer_slug": retailer, "retailer_sku": sku,
        "canonical_product_id": PRODUCT, "name_en": "Synthetic ingredient",
        "package": {"quantity": quantity, "unit": unit, "source": source},
        "price": {"amount": price, "kind": kind, "source": source,
                  "estimate_reason": "Synthetic estimate for testing" if kind == "estimate" else None},
        "availability_status": status, "availability_source": source,
    })
    return SimpleNamespace(
        id=proposal.proposal_id, store_id=proposal.store_id, product_id=PRODUCT,
        country_code="GB", currency_code="GBP", retailer_sku=sku,
        name_en=proposal.name_en, package_quantity=proposal.package.quantity,
        package_unit=unit, price=proposal.price.amount, price_kind=kind,
        estimate_reason=proposal.price.estimate_reason,
        package_source=source.copy(), price_source=source.copy(), availability_source=source.copy(),
        availability_scope="online_catalogue", availability_status=status,
        reviewed_by_user_id=uuid4(), reviewed_at=datetime(2026, 10, 16, 8, tzinfo=timezone.utc),
        fingerprint=proposal.fingerprint,
    )


def quote(offers, *, amount="500", unit="g", store_id=None):
    return select_uk_offer_quote(
        offers, product_id=PRODUCT, store_id=store_id or offers[0].store_id,
        quantity=amount, unit=unit, as_of=TODAY,
    )


@pytest.mark.parametrize("quantity,unit,expected,base", [
    ("1.25", "kg", "1250", "g"), ("1.136", "l", "1136", "ml"),
    ("150", "g", "150", "g"), ("250.5", "ml", "250.5", "ml"),
])
def test_base_units_are_exact_without_g_ml_density_assumptions(quantity, unit, expected, base):
    amount, actual_unit = normalize_requirement(quantity, unit)
    assert amount == Decimal(expected)
    assert actual_unit == base


@pytest.mark.parametrize("amount", [0, -1, "NaN", "Infinity", "-Infinity", True, 0.1, None])
def test_unknown_or_float_requirements_are_not_free_food(amount):
    with pytest.raises(ValueError):
        normalize_requirement(amount, "g")


@pytest.mark.parametrize("unit", ["szt", "opak", "cup", "lyzeczka", "", "grams", None])
def test_unproven_measures_are_not_guessed(unit):
    with pytest.raises(ValueError):
        normalize_requirement("1", unit)


@pytest.mark.parametrize("amount,packs,total", [
    ("0.001", 1, "2.00"), ("500", 1, "2.00"), ("500.001", 2, "4.00"),
    ("1500", 3, "6.00"),
])
def test_whole_packages_use_decimal_ceiling_not_a_100g_fallback(amount, packs, total):
    result = quote([offer()], amount=amount)
    assert result is not None
    assert result.package_count == packs
    assert result.total_price == Decimal(total)
    assert result.package_quantity == Decimal("500")
    assert result.purchased_quantity == Decimal("500") * packs
    assert result.currency_code == "GBP"
    assert result.price_is_estimated is False


def test_local_1136ml_pack_is_not_replaced_by_100ml_or_polish_pack():
    result = quote([offer(quantity="1136", unit="ml", price="1.65")], amount="1.136", unit="l")
    assert result.package_count == 1
    assert result.total_price == Decimal("1.65")
    assert result.required_quantity == Decimal("1136")
    assert result.unit == "ml"


@pytest.mark.parametrize("amount,unit,expected", [
    ("500.0000000000000000000000001", "g", "500.0000000000000000000000001"),
    ("0.5000000000000000000000000001", "kg", "500.0000000000000000000000001"),
    ("0.5000000000000000000000000000001", "kg", "500.0000000000000000000000000001"),
])
def test_tiny_remainder_never_disappears_during_unit_conversion_or_pack_ceiling(amount, unit, expected):
    result = quote([offer()], amount=amount, unit=unit)
    assert result is not None
    assert result.required_quantity == Decimal(expected)
    assert result.package_count == 2
    assert result.purchased_quantity >= result.required_quantity
    assert result.total_price == Decimal("4.00")


def test_choose_lowest_whole_pack_cost_not_lowest_unit_price():
    small = offer(sku="small", quantity="500", price="2.00")
    big = offer(sku="big", quantity="1000", price="3.00")
    assert quote([small, big], amount="500").offer_id == small.id
    assert quote([small, big], amount="750").offer_id == big.id
    assert quote([big, small], amount="750").offer_id == big.id


def test_equal_costs_are_deterministic_independent_of_query_order():
    first, second = offer(sku="one"), offer(sku="two")
    assert quote([first, second]) == quote([second, first])


@pytest.mark.parametrize("unit", ["ml", "l"])
def test_mass_offer_never_covers_volume(unit):
    assert quote([offer()], amount="1", unit=unit) is None


@pytest.mark.parametrize("status", ["out_of_stock", "unknown"])
def test_a_listing_alone_does_not_prove_available_stock(status):
    assert quote([offer(status=status)]) is None


def test_other_store_or_product_and_stale_evidence_are_excluded():
    current = offer()
    foreign = offer(retailer="lidl")
    stale = offer(sku="stale", checked=TODAY - timedelta(days=31))
    other_product = offer(sku="other")
    other_product.product_id = uuid4()
    assert quote([foreign, stale, other_product], store_id=current.store_id) is None


@pytest.mark.parametrize("field,value", [
    ("country_code", "PL"), ("currency_code", "PLN"),
    ("package_quantity", Decimal("0")), ("package_quantity", None),
    ("package_unit", "kg"), ("price", Decimal("-1")), ("price", Decimal("NaN")),
    ("price_kind", "unknown"), ("availability_scope", "all_branches"),
    ("reviewed_at", None), ("reviewed_at", datetime(2026, 10, 17, tzinfo=timezone.utc)),
    ("reviewed_at", datetime(2026, 10, 15, tzinfo=timezone.utc)),
    ("fingerprint", "0" * 64), ("id", uuid4()),
])
def test_invalid_unreviewed_or_modified_rows_are_not_quoted(field, value):
    item = offer()
    setattr(item, field, value)
    assert quote([item]) is None


def test_deleted_reviewer_does_not_remove_completed_price_review():
    item = offer()
    item.reviewed_by_user_id = None
    assert quote([item]) is not None


def test_sqlite_naive_utc_review_round_trip_keeps_date_policy():
    item = offer()
    item.reviewed_at = item.reviewed_at.replace(tzinfo=None)
    assert quote([item]) is not None


def test_estimate_stays_estimate_even_with_dated_sources():
    result = quote([offer(kind="estimate")])
    assert result.price_is_estimated is True
    assert result.last_verified is None
    assert result.price_source["checked_on"] == TODAY.isoformat()


@pytest.mark.parametrize("source", ["package_source", "price_source", "availability_source"])
def test_missing_future_or_foreign_source_is_not_trusted(source):
    for replacement in [None, {}, {"url": "https://example.invalid/item"},
                        {"url": "https://www.tesco.com/item", "publisher": "Fixture", "checked_on": "2026-10-17"}]:
        item = offer()
        setattr(item, source, replacement)
        assert quote([item]) is None


def test_empty_offer_set_is_missing_not_a_zero_price_quote():
    assert select_uk_offer_quote([], product_id=PRODUCT, store_id=uuid4(),
                                quantity="100", unit="g", as_of=TODAY) is None


@pytest.mark.parametrize("invalid_age", [0, 366, True, "30", 30.0])
def test_quote_evidence_age_policy_cannot_be_bypassed(invalid_age):
    with pytest.raises(ValueError):
        select_uk_offer_quote([offer()], product_id=PRODUCT, store_id=offer().store_id,
                             quantity="100", unit="g", as_of=TODAY,
                             max_evidence_age_days=invalid_age)


def test_last_allowed_evidence_day_is_inclusive():
    assert quote([offer(checked=TODAY - timedelta(days=30))]) is not None
    assert quote([offer(checked=TODAY - timedelta(days=31))]) is None


def test_review_date_uses_utc_day_not_the_offset_label():
    item = offer()
    # Local date is the 17th, but this is still the 16th in trusted UTC.
    item.reviewed_at = datetime(2026, 10, 17, 1, tzinfo=timezone(timedelta(hours=2)))
    assert quote([item]) is not None


def test_quote_is_a_snapshot_and_does_not_mutate_source_or_product():
    item = offer()
    result = quote([item])
    result.price_source["publisher"] = "Changed quote display only"
    assert item.price_source["publisher"] == "Synthetic fixture"
    assert item.package_quantity == Decimal("500")
    assert item.price == Decimal("2.00")


def test_bulk_requirement_bound_and_date_are_explicit():
    with pytest.raises(ValueError):
        normalize_requirement("1000000001", "g")
    with pytest.raises(ValueError):
        select_uk_offer_quote([], product_id=PRODUCT, store_id=uuid4(),
                             quantity="100", unit="g", as_of=datetime.now(timezone.utc))
