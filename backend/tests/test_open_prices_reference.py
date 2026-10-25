"""Real public price observations are references, never live retailer offers."""

from copy import deepcopy
from datetime import date, datetime, timedelta
from decimal import Decimal
import json
from pathlib import Path
from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest
from pydantic import ValidationError

from app.db.seed import PRODUCTS_DATA, PRODUCT_BRANDS, NUTRITION_DATA
from app.db.uk_product_catalog import UKProductProposal
from app.models import Product
from app.services import open_prices_reference as subject
from app.services.off_catalogue import catalogue_values


HERE = Path(__file__).parent / "fixtures"
PRICES = json.loads((HERE / "open_prices_uk_20261023.json").read_text(encoding="utf-8"), parse_float=Decimal)
FOODS = json.loads((HERE / "off_uk_staples_20261023.json").read_text(encoding="utf-8"))
AS_OF = date(2026, 10, 23)


def example(index=0):
    observation = deepcopy(PRICES["records"][index])
    link = next(deepcopy(row) for row in FOODS["proposals"] if row["off_barcode"] == observation["product_code"])
    raw = next(row["product"] for row in FOODS["products"] if row["barcode_requested"] == link["off_barcode"])
    off = SimpleNamespace(**catalogue_values(raw, retrieved_at=datetime.fromisoformat(FOODS["retrieved_at"])))
    seed = next(row for row in PRODUCTS_DATA if row[0] == link["product_name"])
    canonical = Product(id=UUID(link["product_id"]), name=seed[0], brand=PRODUCT_BRANDS[seed[0]],
        unit=seed[1], default_quantity=seed[2], review_status="approved",
        nutrition_per_100=dict(NUTRITION_DATA[seed[0]]))
    return observation, link, off, canonical


def prepare(observation, link, off, canonical, *, as_of=AS_OF):
    return subject.prepare_open_prices_reference(observation, mapping=link, off_product=off,
        canonical_product=canonical, as_of=as_of)


@pytest.mark.parametrize("index,amount,pack", [(0, "1.79", "1000"), (1, "0.45", "500"), (2, "1.85", "250")])
def test_public_observation_has_exact_price_pack_source_and_no_canonical_overwrite(index, amount, pack):
    observation, link, off, canonical = example(index)
    before = deepcopy(observation), deepcopy(vars(off)), canonical.name, canonical.brand, canonical.default_quantity, deepcopy(canonical.nutrition_per_100)
    value = prepare(observation, link, off, canonical)
    assert value.amount == Decimal(amount) and value.package_quantity == Decimal(pack)
    assert value.package_unit == "g" and value.currency_code == "GBP"
    assert value.price_is_estimated and not value.current_stock_confirmed
    assert value.availability_scope == "community_observation"
    assert value.retailer_slug == "lidl" and value.product_id == canonical.id
    assert value.observed_on.isoformat() == observation["date"]
    assert value.source_url == f'https://prices.openfoodfacts.org/prices/{observation["id"]}'
    assert value.licence == "ODbL-1.0" and value.proof_id == observation["proof_id"]
    assert before == (observation, vars(off), canonical.name, canonical.brand, canonical.default_quantity, canonical.nutrition_per_100)
    assert "owner" not in value.__dataclass_fields__ and "address" not in value.__dataclass_fields__


@pytest.mark.parametrize("path,value", [
    ("type", "CATEGORY"), ("currency", "EUR"), ("duplicate_of", 99),
    ("price_is_discounted", True), ("price_is_discounted", None), ("discount_type", "LOYALTY_PRICE"),
    ("price_without_discount", "2.00"), ("price_per", "KILOGRAM"), ("receipt_quantity", "2"),
    ("price", "0"), ("price", "-1"), ("price", "NaN"), ("price", "Infinity"),
    ("price", True), ("price", 1.79), ("price", "1.799"), ("price", "100000000"),
    ("id", True), ("id", 0), ("date", "2026-10-24"), ("date", "2026-09-22"),
    ("date", "2026-10-17T00:00:00Z"), ("product_code", "00000000"),
    ("product.id", 1), ("product.code", "20522605"), ("product.source", "obf"),
    ("product.product_quantity", "500"), ("product.product_quantity_unit", "ml"),
    ("product.product_name", "A different SKU"), ("location.osm_address_country_code", "PL"),
    ("location.osm_brand", "Lidl counterfeit"), ("location.id", 1),
    ("location.osm_id", 1), ("location.osm_type", "WAY"),
    ("proof.id", 1), ("proof.location_id", 1), ("proof.location_osm_id", 1),
    ("proof.location_osm_type", "WAY"), ("proof.currency", "PLN"),
    ("proof.type", "OTHER"), ("proof.draft", True), ("proof.draft", None),
    ("proof.date", "2026-10-16"), ("proof.type", []), ("location_osm_type", []),
])
def test_inconsistent_ambiguous_or_non_uk_observation_is_rejected(path, value):
    observation, link, off, canonical = example()
    target = observation
    parts = path.split(".")
    for part in parts[:-1]:
        target = target[part]
    target[parts[-1]] = value
    before = deepcopy(observation)
    with pytest.raises(ValueError):
        prepare(observation, link, off, canonical)
    assert observation == before


@pytest.mark.parametrize("kind", ["changed_off", "stale_off", "future_off", "wrong_off_country", "wrong_off_source",
    "wrong_canonical", "changed_name", "changed_brand", "authored", "branded_barcode", "pending", "unit"])
def test_reference_needs_current_exact_reviewed_food_identity(kind):
    observation, link, off, canonical = example()
    if kind == "changed_off": off.fingerprint = "a" * 64
    elif kind == "stale_off": off.retrieved_at = datetime.fromisoformat(FOODS["retrieved_at"]) - timedelta(days=31)
    elif kind == "future_off": off.retrieved_at = datetime.fromisoformat(FOODS["retrieved_at"]) + timedelta(days=2)
    elif kind == "wrong_off_country": off.country_code = "PL"
    elif kind == "wrong_off_source": off.source_url = "https://example.invalid/food"
    elif kind == "wrong_canonical": canonical.id = uuid4()
    elif kind == "changed_name": canonical.name = "A ready meal with rice"
    elif kind == "changed_brand": canonical.brand = "A different SKU"
    elif kind == "authored": canonical.created_by_user_id = uuid4()
    elif kind == "branded_barcode": canonical.barcode = observation["product_code"]
    elif kind == "pending": canonical.review_status = "pending"
    else: canonical.unit = "ml"
    with pytest.raises(ValueError):
        prepare(observation, link, off, canonical)


def test_reference_cannot_be_mislabelled_as_existing_online_catalogue_proposal():
    from dataclasses import asdict
    value = prepare(*example())
    with pytest.raises(ValidationError):
        UKProductProposal.model_validate(asdict(value))


def test_observed_date_does_not_reset_when_source_is_fetched_again():
    observation, link, off, canonical = example(2)
    assert prepare(observation, link, off, canonical).observed_on == date(2026, 9, 23)
    with pytest.raises(ValueError):
        prepare(observation, link, off, canonical, as_of=AS_OF + timedelta(days=1))


@pytest.mark.parametrize("proof_type,quantity,allowed", [
    ("RECEIPT", Decimal("1"), True), ("RECEIPT", 1, True),
    ("RECEIPT", None, False), ("RECEIPT", Decimal("0.5"), False),
    ("RECEIPT", True, False), ("PRICE_TAG", None, True),
    ("PRICE_TAG", Decimal("1"), True), ("PRICE_TAG", Decimal("2"), False),
])
def test_one_pack_price_is_never_inferred_from_ambiguous_receipt_total(proof_type, quantity, allowed):
    observation, link, off, canonical = example()
    observation["proof"]["type"] = proof_type
    observation["receipt_quantity"] = quantity
    if allowed:
        assert prepare(observation, link, off, canonical).amount == Decimal("1.79")
    else:
        with pytest.raises(ValueError):
            prepare(observation, link, off, canonical)


def test_explicit_kilogram_source_pack_is_normalised_without_using_polish_default():
    observation, link, off, canonical = example()
    canonical.default_quantity = Decimal("200")
    observation["product"]["product_quantity"] = Decimal("1")
    observation["product"]["product_quantity_unit"] = "kg"
    value = prepare(observation, link, off, canonical)
    assert value.package_quantity == 1000 and value.package_unit == "g"
    assert canonical.default_quantity == 200


@pytest.mark.parametrize("payload", [None, [], "not a record", 1])
def test_invalid_top_level_payload_is_an_explicit_rejection(payload):
    _, link, off, canonical = example()
    with pytest.raises(ValueError):
        prepare(payload, link, off, canonical)


@pytest.mark.parametrize("key", ["product", "location", "proof"])
def test_missing_expanded_source_is_not_accepted_by_its_id_alone(key):
    observation, link, off, canonical = example()
    observation.pop(key)
    with pytest.raises(ValueError):
        prepare(observation, link, off, canonical)


def test_no_as_of_datetime_or_missing_physical_package_is_guessed():
    observation, link, off, canonical = example()
    with pytest.raises(ValueError):
        prepare(observation, link, off, canonical, as_of=datetime(2026, 10, 23))
    off.package_quantity = None
    with pytest.raises(ValueError):
        prepare(observation, link, off, canonical)
