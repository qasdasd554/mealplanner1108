"""A household plan and a dish list must use the same ingredient quantities."""
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.api.v1.shopping_lists import ShoppingListFromRecipesRequest, create_shopping_list_from_recipes
from app.models import Store, User
from app.schemas.shopping_list import ShoppingListResponse
from app.services.meal_plan_generator import MealPlanGenerator
from tests.test_regional_shopping import db, run, make_plan, loaded, UK_STORES, ShoppingListBuilder


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("people", [1, 3, 8])
@pytest.mark.parametrize("recipe_servings", [1, 2, 4, 20, 50])
@pytest.mark.parametrize("from_dish", [False, True])
def test_household_ingredients_and_shopping_amount_agree(db, country, people, recipe_servings, from_dish):
    session, adapter, user, product, _ = db
    if country == "PL":
        user = User(id=uuid4(), email="household@example.test", password_hash="fixture", role="admin", country_code="PL")
        session.add(user)
        for store in session.scalars(select(Store)).all():
            store.country_code, store.currency_code = "PL", "PLN"
    plan = make_plan(session, user, product, quantity=str(100 * recipe_servings), include_pantry=False)
    recipe = plan.entries[0].recipe
    recipe.servings = recipe_servings
    data = MealPlanGenerator._assign_to_slots([(1, "obiad", recipe)], [(1, "obiad")], user, people)
    plan.entries[0].servings_multiplier = Decimal(str(data[0]["servings_multiplier"]))
    session.commit()
    if from_dish:
        shopping = run(create_shopping_list_from_recipes(
            ShoppingListFromRecipesRequest(recipe_ids=[recipe.id], store_id=UK_STORES[0].id, servings=people),
            user, adapter,
        ))
    else:
        shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id, include_pantry=False))
    response = ShoppingListResponse.model_validate(loaded(session, shopping.id))
    rows = [row for group in response.items_by_department.values() for row in group]
    assert len(rows) == 1
    assert rows[0].required_quantity == people * 100
    assert recipe.ingredients[0].quantity == 100 * recipe_servings


@pytest.mark.parametrize("people", [0, 9, -1])
def test_dish_household_request_rejects_invalid_counts(people):
    with pytest.raises(ValueError):
        ShoppingListFromRecipesRequest(recipe_ids=[uuid4()], store_id=uuid4(), servings=people)
