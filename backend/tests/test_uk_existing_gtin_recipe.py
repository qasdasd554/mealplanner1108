"""A verified exact GTIN may already have an approved local author/label."""

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.models import OffCatalogueProduct, Product
from app.services.recipe_ingredient_catalogue import materialize_recipe_ingredients
from tests.test_recipe_off_on_demand_parity import CODE, external, resolve
from tests.test_regional_shopping import db, run


def existing(session, user, *, name="Ciasto filo", unit="g", status="approved", owner=True):
    product = Product(id=uuid4(), name=name, unit=unit, barcode=CODE,
        brand="Existing label", serving_quantity=200, default_quantity=200,
        nutrition_per_100={"kcal": 290, "protein": 6, "fat": 9, "carbs": 45},
        measure_options=[{"code": "g", "base_quantity": 1, "base_unit": "g"}],
        created_by_user_id=user.id if owner else None, review_status=status,
        submitted_country_code="PL")
    session.add(product)
    session.commit()
    return product


@pytest.mark.parametrize("owner,unit", [(False, "g"), (True, "g"), (True, "opak")])
def test_verified_uk_gtin_reuses_approved_product_without_renaming_or_reattributing(db, monkeypatch, owner, unit):
    session, adapter, user, *_ = db
    original = existing(session, user, owner=owner, unit=unit)
    before = (original.name, original.brand, original.unit, original.created_by_user_id,
        original.submitted_country_code, original.serving_quantity, deepcopy(original.nutrition_per_100))
    count = session.scalar(select(func.count()).select_from(Product))
    pairs, lookup = resolve(monkeypatch, external())
    saved = run(materialize_recipe_ingredients(adapter, pairs))
    assert all(product.id == original.id for _, product in saved)
    assert session.scalar(select(func.count()).select_from(Product)) == count
    assert (original.name, original.brand, original.unit, original.created_by_user_id,
        original.submitted_country_code, original.serving_quantity, original.nutrition_per_100) == before
    assert session.get(OffCatalogueProduct, CODE) is not None
    assert lookup.await_count == 1
    session.rollback()
    assert session.get(Product, original.id) is not None
    assert session.get(OffCatalogueProduct, CODE) is None


@pytest.mark.parametrize("unsafe", ["pending", "rejected", "wrong_dimension", "whole_meal", "no_proof", "foreign_proof", "stale_proof"])
def test_gtin_reuse_does_not_promote_private_or_incompatible_food(db, monkeypatch, unsafe):
    session, adapter, user, *_ = db
    original = existing(session, user, status=unsafe if unsafe in {"pending", "rejected"} else "approved",
        unit="ml" if unsafe == "wrong_dimension" else "g",
        name="Kotlet schabowy z buraczkami i puree" if unsafe == "whole_meal" else "Ciasto filo")
    result = external()
    if unsafe == "no_proof": result.off_retrieved_at = None
    if unsafe == "foreign_proof": result.off_product["countries_tags"] = ["en:poland"]
    if unsafe == "stale_proof": result.off_retrieved_at = (datetime.now(timezone.utc) - timedelta(days=8)).isoformat()
    pairs, _ = resolve(monkeypatch, result)
    with pytest.raises(ValueError, match="conflicts"):
        run(materialize_recipe_ingredients(adapter, pairs))
    assert original.review_status == (unsafe if unsafe in {"pending", "rejected"} else "approved")
    assert session.get(OffCatalogueProduct, CODE) is None


def test_complete_uk_recipe_reuses_the_approved_gtin_and_its_existing_nutrition(db, monkeypatch):
    from app.api.v1.recipes import _create_ai_recipe
    from app.schemas.recipe import AIRecipeImportRequest
    from app.services import ai_recipe_import, barcode_lookup

    session, adapter, user, *_ = db
    original = existing(session, user)
    lookup = AsyncMock(return_value=[external()])
    monkeypatch.setattr(barcode_lookup, "search_products_external", lookup)
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value={
        "name": "Synthetic filo dish", "servings": 1, "meal_type": "obiad",
        "ingredients": [{"product_name": "Filo pastry", "quantity": 100, "unit": "g"}],
        "instructions": ["Prepare the filo pastry."],
    }))
    recipe = run(_create_ai_recipe(AIRecipeImportRequest(text="Synthetic filo dish"), user, adapter, skip_rate_limit=True))
    assert recipe.ingredients[0].product_id == original.id
    assert recipe.nutrition_total["kcal"] == 290  # Existing approved facts, not a silent replacement.
    assert session.get(OffCatalogueProduct, CODE) is not None
    assert lookup.await_count == 1
    again = run(_create_ai_recipe(AIRecipeImportRequest(text="Synthetic filo dish"), user, adapter, skip_rate_limit=True))
    assert again.ingredients[0].product_id == original.id
    assert again.nutrition_total["kcal"] == 290
    assert lookup.await_count == 1  # The saved English alias must now be local.
