"""Used OFF recipe hits must retain their country facts, without a bulk feed."""

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.models import OffCatalogueProduct, OffIngredientMapping, Product, Recipe, RecipeIngredient, RegionalProductOffer, StoreProduct
from app.services import barcode_lookup
from app.services.market_catalog import recipe_market_availability
from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients, materialize_recipe_ingredients
from tests.test_regional_shopping import db, run


CODE = "5901234123457"


def external(*, fetched_at=None, **changes):
    raw = {"code": CODE, "product_name_en": "Filo pastry", "product_name_pl": "Filo pastry",
        "countries_tags": ["en:united-kingdom"], "last_modified_t": 1700000000,
        "product_quantity": 250, "product_quantity_unit": "g",
        "nutriments": {"energy-kcal_100g": 300, "proteins_100g": 7,
                       "fat_100g": 10, "carbohydrates_100g": 50}, **changes}
    result = barcode_lookup._result_from_off_product(raw, country_code="GB")
    assert result is not None
    result.off_product = raw
    result.off_retrieved_at = (fetched_at or datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    return result


def resolve(monkeypatch, result, *, country="GB"):
    search = AsyncMock(return_value=[result])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    pairs = run(resolve_recipe_ingredients(
        [{"product_name": "Filo pastry", "quantity": 100, "unit": "g"}] * 2,
        [], country=country))
    assert all(product is not None for _, product in pairs)
    search.assert_awaited_once_with("Filo pastry", limit=10, country_code=country)
    return pairs, search


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_first_used_recipe_hit_is_cached_once_and_uk_recipe_can_be_listed(db, monkeypatch, country):
    session, adapter, *_ = db
    result = external()
    counts = {model: session.scalar(select(func.count()).select_from(model))
              for model in (StoreProduct, RegionalProductOffer, OffIngredientMapping)}
    pairs, search = resolve(monkeypatch, result, country=country)
    # Searching alone is read-only, just as in the scanner.
    assert session.get(OffCatalogueProduct, CODE) is None
    saved = run(materialize_recipe_ingredients(adapter, pairs))
    product = saved[0][1]
    assert product.id == saved[1][1].id
    assert product.nutrition_per_100["kcal"] == 300
    cached = session.get(OffCatalogueProduct, CODE)
    if country == "GB":
        assert cached is not None
        assert cached.retrieved_at.replace(tzinfo=timezone.utc) == datetime.fromisoformat(result.off_retrieved_at)
    else:
        assert cached is None  # PL has no new country-cache requirement.
    dish = Recipe(id=uuid4(), name="Synthetic filo dish", meal_type="obiad")
    session.add(dish)
    session.flush()
    session.add(RecipeIngredient(id=uuid4(), recipe_id=dish.id, product_id=product.id,
        quantity=100, unit="g", is_optional=False))
    session.flush()
    available = session.scalar(select(Recipe.id).where(Recipe.id == dish.id,
        recipe_market_availability("GB")))
    assert (available is not None) == (country == "GB")
    for model, count in counts.items():
        assert session.scalar(select(func.count()).select_from(model)) == count
    # A later use is local, not another lookup or a manual OFF mapping.
    repeated = run(resolve_recipe_ingredients([pairs[0][0]], [product], country=country))
    assert repeated[0][1].id == product.id and search.await_count == 1


@pytest.mark.parametrize("bad", ["foreign", "wrong_code", "future", "missing_clock", "wrong_name", "obsolete"])
def test_missing_or_inconsistent_evidence_does_not_create_uk_availability(db, monkeypatch, bad):
    session, adapter, *_ = db
    result = external()
    raw = deepcopy(result.off_product)
    if bad == "foreign": raw["countries_tags"] = ["en:poland"]
    elif bad == "wrong_code": raw["code"] = "5025125000006"
    elif bad == "future": result.off_retrieved_at = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    elif bad == "missing_clock": result.off_retrieved_at = None
    elif bad == "wrong_name": raw["product_name_en"] = "Different food"
    else: raw["obsolete"] = 1
    result.off_product = raw
    pairs, _ = resolve(monkeypatch, result)
    saved = run(materialize_recipe_ingredients(adapter, pairs))
    assert saved[0][1].name == "Filo pastry"
    assert session.scalar(select(func.count()).select_from(OffCatalogueProduct)) == 0


def test_recipe_and_used_country_cache_rollback_together(db, monkeypatch):
    session, adapter, *_ = db
    pairs, _ = resolve(monkeypatch, external())
    result = run(materialize_recipe_ingredients(adapter, pairs))
    product_id = result[0][1].id
    assert session.get(OffCatalogueProduct, CODE) is not None
    session.rollback()
    assert session.get(Product, product_id) is None
    assert session.get(OffCatalogueProduct, CODE) is None
