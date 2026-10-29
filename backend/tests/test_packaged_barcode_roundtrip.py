"""A catalogue row is one pack; barcode nutrition still has a g/ml basis."""
import asyncio
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import BackgroundTasks

from app.api.v1.products import lookup_barcode, list_scanned_products, search_products_by_name
from app.models import BarcodeProductCache, Product, User
from app.services.product_measures import explicit_physical_unit
from types import SimpleNamespace
from tests.test_meal_plan_lifecycle import db


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("unit,size", [("g", 250), ("ml", 500)])
@pytest.mark.parametrize("bad_cache", [False, "pack_unit", "wrong_basis", "wrong_size"])
def test_rescanning_one_catalogue_pack_keeps_its_physical_unit(db, monkeypatch, country, unit, size, bad_cache):
    user = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test", country_code=country)
    # This is the actual persisted representation after import to catalogue.
    product = Product(id=uuid4(), name="Neutral label without liquid-name hints", unit="opak",
        default_quantity=1, serving_quantity=size, barcode="5901234123457",
        nutrition_per_100={"kcal":200,"protein":10,"fat":4,"carbs":30},
        measure_options=[{"code":unit,"base_unit":unit,"base_quantity":1},
                         {"code":"opak","base_unit":unit,"base_quantity":size}])
    db.session.add_all([user,product])
    if bad_cache:
        db.session.add(BarcodeProductCache(barcode=product.barcode, name=product.name,
            unit=("opak" if bad_cache == "pack_unit" else
                  ("g" if unit == "ml" else "ml") if bad_cache == "wrong_basis" else unit),
            serving_quantity=999, nutrition_per_100=product.nutrition_per_100,
            price_min=1, price_max=3, source="catalog"))
    db.session.commit()
    external = AsyncMock(return_value=None)
    monkeypatch.setattr("app.api.v1.products.lookup_barcode_external",external)
    result=asyncio.run(lookup_barcode(product.barcode, BackgroundTasks(), db, user,
                                    release_read_transaction=False))
    assert result.unit == unit
    assert result.serving_quantity == size
    assert result.kcal_per_100 == 200 and result.protein_per_100 == 10
    assert product.unit == "opak" and product.default_quantity == 1
    external.assert_not_awaited()


@pytest.mark.parametrize("measures", [None, [], [{"base_unit":"g","base_quantity":0}],
    [{"base_unit":"g","base_quantity":float("inf")}],
    [{"base_unit":"ml","base_quantity":1},{"base_unit":"g","base_quantity":1}]])
def test_unreliable_pack_basis_is_not_guessed_from_name(measures):
    product = SimpleNamespace(unit="opak", name="Mleko / milk", measure_options=measures)
    assert explicit_physical_unit(product) is None


@pytest.mark.parametrize("unit", ["g", "ml"])
def test_scanned_catalogue_preserves_pack_basis_without_name_guessing(db, unit):
    db.session.add(BarcodeProductCache(barcode="5901234123457", name="Neutral label",
        unit=unit, serving_quantity=500, nutrition_per_100={"kcal":60},
        price_min=1, price_max=3, source="open_food_facts"))
    db.session.commit()
    result = asyncio.run(list_scanned_products(0, 50, None, db))
    assert len(result) == 1 and result[0]["unit"] == "opak"
    assert result[0]["default_quantity"] == 1
    package = next(m for m in result[0]["measure_options"] if m["code"] == "opak")
    assert package["base_unit"] == unit and package["base_quantity"] == 500


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("unit", ["g", "ml"])
def test_name_suggestion_keeps_explicit_pack_unit(db, monkeypatch, country, unit):
    user = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test", country_code=country)
    product = Product(id=uuid4(), name="Neutral label", unit="opak", default_quantity=1,
        serving_quantity=500, submitted_country_code=country, review_status="approved",
        nutrition_per_100={"kcal":60,"protein":3,"fat":2,"carbs":7},
        measure_options=[{"code":"opak","base_unit":unit,"base_quantity":500}])
    db.session.add_all([user, product])
    db.session.commit()
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", AsyncMock(return_value=[]))
    monkeypatch.setattr("app.services.off_catalogue.search_off_catalogue", AsyncMock(return_value=[]))
    suggestions = asyncio.run(search_products_by_name("Neutral", 10, db, user))
    match = next(s for s in suggestions if s.existing_product_id == product.id)
    assert match.unit == unit and match.serving_quantity == 500


def test_old_cache_without_physical_unit_does_not_invent_a_pack_size(db):
    db.session.add(BarcodeProductCache(barcode="5901234123457", name="Unknown old pack",
        unit="opak", serving_quantity=999, nutrition_per_100={"kcal":60},
        price_min=1, price_max=3, source="catalog"))
    db.session.commit()
    result = asyncio.run(list_scanned_products(0, 50, None, db))
    assert result[0]["serving_quantity"] is None
    assert result[0]["unit"] == "g" and result[0]["default_quantity"] == 100
    assert result[0]["measure_options"] == []
