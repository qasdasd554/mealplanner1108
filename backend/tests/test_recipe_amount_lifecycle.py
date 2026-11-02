"""PL/GB persisted recipe -> list -> reprice regressions with synthetic prices."""
from contextlib import asynccontextmanager
from decimal import Decimal
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import delete, select

from app.models import Product, Recipe, RegionalProductOffer, ShoppingListItem, Store, StoreProduct, User
from app.schemas.recipe import AIRecipeImportRequest, RecipeIngredientCreate, RecipeResponse
from app.schemas.shopping_list import ShoppingListResponse
from app.services.product_measures import build_measure_options
from app.services.shopping_list_builder import ShoppingListBuilder
from tests.test_regional_shopping import db, run, make_plan, loaded, UK_STORES
from tests.uk_regional_fixtures import reviewed_offer


def prepare(db, country):
    session, adapter, user, product, _ = db
    if country == "PL":
        user = User(id=uuid4(), email="pl-amounts@example.test", password_hash="fixture",
            role="admin", country_code="PL", is_premium=True)
        session.add(user)
    product.name = "Cynamon" if country == "PL" else "Cinnamon"
    product.unit, product.default_quantity, product.serving_quantity = "g", Decimal(20), 20
    product.measure_options = build_measure_options(product.name, "g", 20, 20)
    product.nutrition_per_100 = dict(kcal=247, protein=4, fat=1.2, carbs=80.6, fiber=53.1)
    session.execute(delete(RegionalProductOffer))
    shop = session.get(Store, UK_STORES[0].id)
    shop.country_code, shop.currency_code = country, "PLN" if country == "PL" else "GBP"
    if country == "PL":
        session.add(StoreProduct(id=uuid4(), store_id=shop.id, product_id=product.id,
            price=Decimal("3.49"), is_available=True))
    else:
        reviewed_offer(session, product, shop, quantity="20", price="3.49")
    session.commit()
    return session, adapter, user, product, shop


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("multiplier,price", [(1, "3.49"), (3, "6.98")])
def test_saved_recipe_and_basket_use_the_same_recovered_amount(db, country, multiplier, price):
    session, adapter, user, product, _ = prepare(db, country)
    plan = make_plan(session, user, product, quantity="3", unit="szt", include_pantry=False)
    recipe = plan.entries[0].recipe
    recipe.instructions = ["Wymieszaj cynamon (3 łyżeczki)." if country == "PL" else "Stir in 3 tsp cinnamon."]
    recipe.nutrition_total = dict(kcal=741)
    plan.entries[0].servings_multiplier = multiplier
    session.commit()
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    response = ShoppingListResponse.model_validate(loaded(session, shopping.id))
    lines = [row for group in response.items_by_department.values() for row in group]
    assert len(lines) == 1
    assert (lines[0].required_quantity, lines[0].unit) == (pytest.approx(7.8 * multiplier), "g")
    assert Decimal(str(lines[0].estimated_price)) == Decimal(price)
    assert response.total_estimated_price == float(price)
    recipe = session.get(Recipe, recipe.id)
    assert recipe.ingredients[0].quantity == Decimal("7.800")
    assert RecipeResponse.model_validate(recipe).ingredients[0].kcal == 19
    assert recipe.nutrition_total["kcal"] == 19.3


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_unknown_count_remains_visible_and_unpriced_instead_of_100g(db, country):
    session, adapter, user, product, _ = prepare(db, country)
    plan = make_plan(session, user, product, quantity="3", unit="szt", include_pantry=False)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    response = ShoppingListResponse.model_validate(loaded(session, shopping.id))
    lines = [row for group in response.items_by_department.values() for row in group]
    assert len(lines) == 1
    assert (lines[0].required_quantity, lines[0].unit) == (3, "szt")
    assert lines[0].estimated_price is None
    assert response.has_unpriced_items and response.total_estimated_price is None


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_ai_import_uses_explicit_amount_before_nutrition_and_shopping(db, monkeypatch, country):
    from app.api.v1.recipes import _create_ai_recipe
    from app.services import ai_recipe_import
    session, adapter, user, product, _ = prepare(db, country)
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value=dict(
        name="Cinnamon rolls", servings=4,
        ingredients=[dict(product_name=product.name, quantity=3, unit="szt")],
        instructions=["Stir in 3 tsp cinnamon."],
    )))
    recipe = run(_create_ai_recipe(AIRecipeImportRequest(text="Cinnamon rolls"), user, adapter, skip_rate_limit=True))
    assert (recipe.ingredients[0].quantity, recipe.ingredients[0].unit) == (Decimal("7.800"), "g")
    assert recipe.nutrition_total["kcal"] == 19.3


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_manual_api_rejects_unsupported_piece_but_accepts_a_real_measure(db, country):
    from app.api.v1.recipes import _validate_recipe_ingredient_products
    _, adapter, user, product, _ = prepare(db, country)
    with pytest.raises(HTTPException) as caught:
        run(_validate_recipe_ingredient_products(adapter,
            [RecipeIngredientCreate(product_id=product.id, quantity=3, unit="szt")], user.id, country_code=country))
    assert caught.value.status_code == 422
    assert ("grams" if country == "GB" else "gramy") in str(caught.value.detail)
    assert product.id in run(_validate_recipe_ingredient_products(adapter,
        [RecipeIngredientCreate(product_id=product.id, quantity=3, unit="lyzeczka")], user.id, country_code=country))


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("bought", [False, True])
def test_startup_repairs_existing_recipes_and_only_unbought_lists(db, monkeypatch, country, bought):
    from app import main
    from app.db import session as db_session
    session, adapter, user, product, _ = prepare(db, country)
    plan = make_plan(session, user, product, quantity="300", unit="g", include_pantry=False)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    shopping = loaded(session, shopping.id)
    assert shopping.items[0].estimated_price == Decimal("52.35")
    shopping.items[0].is_checked = bought
    recipe = session.get(Recipe, plan.entries[0].recipe_id)
    recipe.ingredients[0].quantity, recipe.ingredients[0].unit = Decimal(3), "szt"
    recipe.instructions = ["Dodaj cynamon (3 łyżeczki)." if country == "PL" else "Stir in 3 tsp cinnamon."]
    recipe.nutrition_total = dict(kcal=741)
    manual = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, custom_name="Paper towels",
        required_quantity=2, unit="szt", is_generated=False, estimated_price=None, is_checked=False)
    session.add(manual)
    session.commit()

    @asynccontextmanager
    async def local_session():
        yield adapter
    monkeypatch.setattr(db_session, "async_session_factory", local_session)
    run(main._backfill_missing_nutrition_totals())
    assert session.get(Recipe, recipe.id).ingredients[0].unit == "g"
    shopping = loaded(session, shopping.id)
    line = next(row for row in shopping.items if row.is_generated)
    assert line.is_checked == bought
    assert line.required_quantity == (Decimal(300) if bought else Decimal("7.800"))
    assert line.estimated_price == (Decimal("52.35") if bought else Decimal("3.49"))
    assert session.get(ShoppingListItem, manual.id).required_quantity == 2
    ids = {row.id for row in shopping.items}
    run(main._backfill_missing_nutrition_totals())
    assert {row.id for row in loaded(session, shopping.id).items} == ids
