"""Local synthetic provider results; never call the live OFF API in tests."""

from datetime import datetime, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select, func

from app.api.v1.recipes import _create_ai_recipe, _product_has_complete_nutrition
from app.models import Product, Recipe, User
from app.schemas.recipe import AIRecipeImportRequest
from app.services import ai_recipe_import, barcode_lookup
from app.services.barcode_lookup import BarcodeLookupResult
from tests.test_regional_shopping import db, run


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_missing_ingredient_is_discovered_and_shared_basics_do_not_block(db, monkeypatch, country):
    session, adapter, user, _, _ = db
    if country == "PL":
        user = User(id=uuid4(), email="pl-import@example.test", password_hash="fixture", role="admin", country_code="PL")
        session.add(user)
    salt = Product(id=uuid4(), name="Sól", unit="g", review_status="approved",
        nutrition_per_100={"kcal": 0, "protein": 0, "fat": 0, "carbs": 0})
    pepper = Product(id=uuid4(), name="Pieprz czarny mielony", unit="g", review_status="approved",
        nutrition_per_100={"kcal": 251, "protein": 10.4, "fat": 3.3, "carbs": 64})
    session.add_all([salt, pepper]); session.commit()
    missing = "Schab z kością" if country == "PL" else "Pork loin bone in"
    def parsed():
        return {"name": "Obiad" if country == "PL" else "Lunch", "servings": 2, "meal_type": "obiad",
            "ingredients": [{"product_name": name, "quantity": quantity, "unit": unit}
                for name, quantity, unit in [(missing, 200, "g"), ("Sól" if country == "PL" else "Salt", 2, "g"),
                    ("Pieprz" if country == "PL" else "Pepper", 1, "g"), ("Woda" if country == "PL" else "Water", 300, "ml")]],
            "instructions": ["Przygotuj składniki." if country == "PL" else "Prepare the ingredients."]}
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(side_effect=lambda *args, **kwargs: parsed()))
    external = BarcodeLookupResult(name=missing, brand=None, price_min=0, price_max=0, unit="g", kcal_per_100=143,
        protein_per_100=22, fat_per_100=6, carbs_per_100=0, source="open_food_facts", barcode="5901234123457")
    search = AsyncMock(return_value=[external])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    created = run(_create_ai_recipe(AIRecipeImportRequest(text="Obiad"), user, adapter, skip_rate_limit=True))
    assert len(created.ingredients) == 4
    assert {i.product.name for i in created.ingredients} >= {salt.name, pepper.name, missing}
    found = next(i for i in created.ingredients if i.product.name == missing)
    assert found.quantity == 200 and found.unit == "g"
    assert found.product.review_status == "approved" and found.product.created_by_user_id is None
    assert found.product.nutrition_per_100["kcal"] == 143
    assert found.product.nutrition_per_100["_source"]["provider"] == "open_food_facts"
    assert found.product.serving_quantity is None  # never invent a package
    assert search.await_count == 1
    second = User(id=uuid4(), email=f"second-{country}@example.test", password_hash="fixture", role="admin", country_code=country)
    session.add(second); session.commit()
    again = run(_create_ai_recipe(AIRecipeImportRequest(text="Obiad"), second, adapter, skip_rate_limit=True))
    assert next(i.product_id for i in again.ingredients if i.product.name == missing) == found.product_id
    assert search.await_count == 1  # the next person uses Neon, not the internet


@pytest.mark.parametrize("bad", ["wrong-food", "missing-macros", "infinite", "negative"])
def test_unverified_external_result_saves_every_ingredient_privately_without_fake_macros(db, monkeypatch, bad):
    session, adapter, user, _, _ = db
    name = "Pork loin bone in"
    raw = dict(name="Lunch", ingredients=[dict(product_name=name, quantity=200, unit="g")], instructions=["Cook."], servings=1)
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value=raw))
    item = BarcodeLookupResult(name="Pork ready meal" if bad == "wrong-food" else name, brand=None, price_min=0, price_max=0, unit="g",
        kcal_per_100=143 if bad != "infinite" else float("inf"), protein_per_100=None if bad == "missing-macros" else 22,
        fat_per_100=-1 if bad == "negative" else 6, carbs_per_100=0, source="open_food_facts")
    monkeypatch.setattr(barcode_lookup, "search_products_external", AsyncMock(return_value=[item]))
    before = session.scalar(select(func.count()).select_from(Product))
    created = run(_create_ai_recipe(AIRecipeImportRequest(text="Lunch"), user, adapter, skip_rate_limit=True))
    assert len(created.ingredients) == 1
    ingredient = created.ingredients[0]
    assert ingredient.product.name == name and ingredient.quantity == 200 and ingredient.unit == "g"
    assert ingredient.product.review_status == "pending"
    assert ingredient.product.created_by_user_id == user.id
    assert ingredient.product.barcode is None and ingredient.product.serving_quantity is None
    assert "kcal" not in ingredient.product.nutrition_per_100
    assert created.nutrition_total["_incomplete"] is True
    assert created.nutrition_total["kcal"] is None
    from app.schemas.recipe import RecipeResponse
    response = RecipeResponse.model_validate(created)
    assert response.ingredients[0].kcal is None
    assert response.ingredients[0].protein is None
    assert session.scalar(select(func.count()).select_from(Product)) == before + 1
    assert session.scalar(select(func.count()).select_from(Recipe)) == 1


def test_real_zero_energy_is_not_confused_with_missing_macros():
    zero = {"kcal": 0, "protein": 0, "fat": 0, "carbs": 0}
    assert _product_has_complete_nutrition(Product(name="Sól", nutrition_per_100=zero))
    assert _product_has_complete_nutrition(Product(name="Woda", nutrition_per_100=zero))
    assert not _product_has_complete_nutrition(Product(name="Jogurt", nutrition_per_100=zero))


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("source", ["text", "photo", "url"])
def test_any_recipe_source_preserves_all_unknown_ingredients_and_isolates_owners(db, monkeypatch, country, source):
    import base64
    from io import BytesIO
    from PIL import Image
    session, adapter, _, _, _ = db
    user = User(id=uuid4(), email=f"{source}-{country}@example.test", password_hash="fixture", role="admin", country_code=country)
    other = User(id=uuid4(), email=f"other-{source}-{country}@example.test", password_hash="fixture", role="admin", country_code=country)
    session.add_all([user, other]); session.commit()
    names = ["Masa serowa bez laktozy", "Ciasto filo", "Grzyby suszone"] if country == "PL" else ["Lactose free curd", "Filo pastry", "Dried mushrooms"]
    raw = dict(name="Recipe", ingredients=[dict(product_name=name, quantity=120 + index, unit="g") for index, name in enumerate(names)], instructions=["Prepare ingredients."], servings=2)
    monkeypatch.setattr(ai_recipe_import, f"extract_recipe_from_{source}", AsyncMock(return_value=raw))
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    image = BytesIO(); Image.new("RGB", (2, 2), "green").save(image, format="JPEG")
    payload = AIRecipeImportRequest(**{dict(text="text", photo="photo_base64", url="url")[source]:
        base64.b64encode(image.getvalue()).decode() if source == "photo" else "https://example.test/recipe" if source == "url" else "Recipe"})
    first = run(_create_ai_recipe(payload, user, adapter, skip_rate_limit=True))
    assert [(i.product.name, float(i.quantity), i.unit) for i in first.ingredients] == [(name, 120 + index, "g") for index, name in enumerate(names)]
    assert set(first.nutrition_total["_missing_ingredients"]) == set(names)
    ids = {i.product_id for i in first.ingredients}
    again = run(_create_ai_recipe(payload, user, adapter, skip_rate_limit=True))
    assert {i.product_id for i in again.ingredients} == ids  # no duplicate private placeholders
    other_recipe = run(_create_ai_recipe(payload, other, adapter, skip_rate_limit=True))
    assert not ({i.product_id for i in other_recipe.ingredients} & ids)
    assert all(i.product.created_by_user_id == other.id for i in other_recipe.ingredients)
    assert session.scalar(select(func.count()).select_from(Product).where(Product.id.in_(ids), Product.review_status == "approved")) == 0


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_ai_edit_uses_same_fallback_and_charges_only_one_point(db, monkeypatch, country):
    from app.api.v1.recipes import edit_recipe_with_ai
    from app.models import RecipeIngredient
    from app.schemas.recipe import AIRecipeEditRequest
    session, adapter, _, product, _ = db
    user = User(id=uuid4(), email=f"edit-{country}@example.test", password_hash="fixture", role="admin", country_code=country, premium_points=3)
    recipe = Recipe(id=uuid4(), name="Original", meal_type="obiad", servings=2, difficulty="łatwy", visibility="private", created_by_user_id=user.id, instructions=["Original step."])
    session.add_all([user, recipe]); session.flush()
    session.add(RecipeIngredient(id=uuid4(), recipe_id=recipe.id, product_id=product.id, quantity=100, unit="g", is_optional=False)); session.commit()
    raw = ai_recipe_import.validate_and_clean_recipe_dict(dict(name="Edited", ingredients=[dict(product_name="Filo pastry", quantity=200, unit="g")], instructions=["Prepare it."], servings=2), country_code=country)
    monkeypatch.setattr(ai_recipe_import, "revise_recipe_with_ai", AsyncMock(return_value=raw))
    monkeypatch.setattr(barcode_lookup, "search_products_external", AsyncMock(return_value=[]))
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    async def rollback(): session.rollback()
    adapter.rollback = rollback
    spend = AsyncMock()
    monkeypatch.setattr("app.services.premium_points.spend_points", spend)
    response = run(edit_recipe_with_ai(recipe.id, AIRecipeEditRequest(prompt="Change pastry"), user, adapter))
    assert response.ingredients[0].product_name == "Filo pastry"
    assert response.ingredients[0].quantity == 200
    assert response.ingredients[0].kcal is None
    assert response.nutrition_total["_incomplete"] is True
    spend.assert_awaited_once_with(adapter, user.id, 1)


def test_missing_macros_cannot_be_logged_as_zero_and_unknown_allergens_are_not_safe():
    from types import SimpleNamespace
    from app.api.v1.food_log import _macros_from_recipe
    from app.services.meal_plan_generator import MealPlanGenerator
    recipe = SimpleNamespace(nutrition_total={"kcal": None, "_incomplete": True}, ingredients=[
        SimpleNamespace(product_id=uuid4(), product=Product(name="Ingredient", nutrition_per_100={"_source": {"allergens_checked": False}}))])
    with pytest.raises(HTTPException) as error:
        _macros_from_recipe(recipe, 1, country_code="GB")
    assert error.value.status_code == 422 and "missing" in error.value.detail
    assert MealPlanGenerator._recipe_has_allergen(recipe, {uuid4()}, {}) is True
    assert MealPlanGenerator._recipe_has_allergen(recipe, set(), {}) is False


def test_duplicate_missing_names_use_one_bounded_lookup(monkeypatch):
    import asyncio
    from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients
    async def timed_out(*args, **kwargs): raise TimeoutError("synthetic timeout")
    search = AsyncMock(side_effect=timed_out)
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    result = run(resolve_recipe_ingredients([dict(product_name="Filo pastry", quantity=20, unit="g")] * 3, [], country="GB", user_id=uuid4()))
    assert len(result) == 3 and all(product is not None for _, product in result)
    assert len({product.id for _, product in result}) == 1
    assert search.await_count == 1


def test_filling_private_product_recalculates_recipe_instead_of_leaving_missing_totals(db, monkeypatch):
    from app.api.v1.products import update_own_product, ProductSubmission
    session, adapter, user, _, _ = db
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value={
        "name": "Recipe", "servings": 2, "instructions": ["Prepare."],
        "ingredients": [{"product_name": "Filo pastry", "quantity": 200, "unit": "g"}],
    }))
    monkeypatch.setattr(barcode_lookup, "search_products_external", AsyncMock(return_value=[]))
    recipe = run(_create_ai_recipe(AIRecipeImportRequest(text="Recipe"), user, adapter, skip_rate_limit=True))
    assert recipe.nutrition_total["kcal"] is None
    product = recipe.ingredients[0].product
    run(update_own_product(product.id, ProductSubmission(name="Filo pastry", unit="g",
        kcal_per_100=300, protein_per_100=7, fat_per_100=10, carbs_per_100=50), adapter, user))
    assert recipe.nutrition_total["kcal"] == 600
    assert recipe.nutrition_total["protein"] == 14
    assert "_incomplete" not in recipe.nutrition_total
    from app.api.v1.food_log import _macros_from_recipe
    assert _macros_from_recipe(recipe, .5)["calories"] == 300


def test_unknown_ingredient_in_pieces_keeps_pieces_on_shopping_list(db, monkeypatch):
    from types import SimpleNamespace
    from app.services.shopping_list_builder import ShoppingListBuilder
    from app.models import Store
    session, adapter, user, _, _ = db
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value={
        "name": "Recipe", "servings": 2, "instructions": ["Prepare."],
        "ingredients": [{"product_name": "Spring roll wrappers", "quantity": 4, "unit": "szt"}],
    }))
    monkeypatch.setattr(barcode_lookup, "search_products_external", AsyncMock(return_value=[]))
    recipe = run(_create_ai_recipe(AIRecipeImportRequest(text="Recipe"), user, adapter, skip_rate_limit=True))
    product = recipe.ingredients[0].product
    assert product.unit == "szt" and product.serving_quantity is None
    aggregated = ShoppingListBuilder._aggregate_ingredients(SimpleNamespace(entries=[SimpleNamespace(recipe=recipe, servings_multiplier=1)]))
    items = run(ShoppingListBuilder(adapter)._resolve_store_details(aggregated, session.scalars(select(Store)).first().id, user.id, include_pantry=False))
    assert len(items) == 1
    assert items[0]["required_quantity"] == 4 and items[0]["unit"] == "szt"
    assert items[0]["estimated_price"] is None
