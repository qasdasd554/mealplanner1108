"""Cross-screen correctness with real ORM and guarded async boundaries."""
from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import uuid4

import pytest

from app.api.v1 import food_log, wellness
from app.core import market_clock
from app.models import FoodLogEntry, MealPlan, PantryItem, Product, Recipe, ShoppingList, ShoppingListItem, StoreProduct, User
from app.models.wellness import WaterLog
from app.schemas.food_log import FoodLogEntryCreate
from app.services.nutrition_calculator import compute_recipe_nutrition_total
from app.services.pantry_shopping_sync import sync_product_in_shopping_lists
from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
from tests.test_runtime_async_boundaries import state


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("include", [False, True])
async def test_pantry_sync_respects_the_saved_include_pantry_choice(state, include):
    session, db, (user_id, product_id, plan_id, _, _) = state
    with db.allowed():
        plan = session.get(MealPlan, plan_id)
        plan.preferences = {"include_pantry": include}
        product = session.get(Product, product_id)
        shopping = ShoppingList(id=uuid4(), meal_plan_id=plan_id, store_id=plan.store_id)
        item = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, required_quantity=100,
            unit="g", is_checked=False, is_from_pantry=False, is_generated=True)
        if session.get(User, user_id).country_code == "GB":
            apply_regional_item_quote(item, product=product, store_id=plan.store_id,
                quantity=Decimal(100), unit="g", offers=[], as_of=regional_pricing_date())
        else:
            offer = StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=product_id,
                                 price=3, is_available=True)
            db.add(offer)
            item.store_product_id = offer.id
        db.add(shopping)
        db.add(item)
        db.add(PantryItem(id=uuid4(), user_id=user_id, product_id=product_id, quantity=50, unit="g"))
    await db.commit()
    session.expunge_all()
    await sync_product_in_shopping_lists(db, user_id, product_id)
    await db.commit()
    from sqlalchemy import select
    rows = (await db.execute(select(ShoppingListItem).where(
        ShoppingListItem.shopping_list_id == shopping.id))).scalars().all()
    assert sum(row.required_quantity for row in rows) == 100
    assert sum(row.required_quantity for row in rows if row.is_from_pantry) == (50 if include else 0)


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("instant", [datetime(2026, 10, 27, 23, 30, tzinfo=timezone.utc),
                                      datetime(2026, 6, 30, 23, 30, tzinfo=timezone.utc)])
async def test_statistics_include_the_accounts_current_day_across_midnight(state, monkeypatch, instant):
    _, db, (user_id, _, _, _, _) = state
    user = await db.get(User, user_id)
    expected_day = market_clock.market_today(user, now=instant)
    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return instant.astimezone(tz) if tz else instant.replace(tzinfo=None)
    class ServerDate(date):
        @classmethod
        def today(cls):
            return instant.date()
    monkeypatch.setattr(market_clock, "datetime", FrozenDatetime)
    monkeypatch.setattr(wellness, "date_type", ServerDate)
    db.add(FoodLogEntry(id=uuid4(), user_id=user_id, date=expected_day, meal_type="obiad",
        custom_name="Current day", calories=360, protein=10, fat=5, carbs=60, servings=1))
    db.add(WaterLog(id=uuid4(), user_id=user_id, date=expected_day, amount_ml=500))
    await db.commit()
    stats = await wellness.get_wellness_statistics(days=7, current_user=user, db=db)
    assert stats.days[-1].date == expected_day
    assert stats.days[-1].calories == 360 and stats.days[-1].water_ml == 500


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("path", ["recipe", "plan"])
@pytest.mark.parametrize("legacy", [None, "zero", "incomplete"])
async def test_diary_recovers_legacy_recipe_totals_like_the_recipe_screen(state, path, legacy):
    session, db, (user_id, _, _, entry_id, recipe_id) = state
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload
    from app.models import MealPlanEntry, RecipeIngredient
    recipe = (await db.execute(select(Recipe).where(Recipe.id == recipe_id).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product)))).scalar_one()
    expected = compute_recipe_nutrition_total(recipe.ingredients)["kcal"] / recipe.servings
    recipe.nutrition_total = (dict.fromkeys(("kcal", "protein", "fat", "carbs"), 0)
        if legacy == "zero" else {"_incomplete": True, "kcal": None} if legacy == "incomplete" else None)
    # The plan path must point at the same recipe as the direct-recipe path.
    (await db.get(MealPlanEntry, entry_id)).recipe_id = recipe_id
    await db.commit()
    session.expunge_all()
    user = await db.get(User, user_id)
    if path == "recipe":
        result = await food_log.create_food_log_entry(FoodLogEntryCreate(
            date=date(2026, 10, 28), meal_type="obiad", recipe_id=recipe_id, servings=1), db, user)
    else:
        result = await food_log.create_from_meal_plan_entry(entry_id,
            entry_date_override=date(2026, 10, 28), servings_override=1, db=db, current_user=user)
    assert result.calories == pytest.approx(expected, abs=.1)
    assert result.calories > 0


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("diet", ["vegetarian", "wegetariańska"])
async def test_generator_respects_saved_diet_aliases_in_both_markets(state, diet):
    session, db, (user_id, product_id, plan_id, _, recipe_id) = state
    from app.models import RecipeTag
    from app.services.meal_plan_generator import MealPlanGenerator
    plan = await db.get(MealPlan, plan_id)
    shop_id = plan.store_id
    db.add(RecipeTag(recipe_id=recipe_id, tag="wegetariańskie"))
    if (await db.get(User, user_id)).country_code == "PL":
        db.add(StoreProduct(id=uuid4(), store_id=shop_id, product_id=product_id, price=3, is_available=True))
    await db.commit()
    user = await db.get(User, user_id)
    rows = await MealPlanGenerator(db)._filter_eligible_recipes(set(), shop_id,
        diet=diet, user_id=user_id, country_code=user.country_code)
    assert [row.id for row in rows] == [recipe_id]


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("evidence", ["contains", "unknown"])
async def test_generator_excludes_declared_allergens_and_explicitly_unknown_allergen_data(state, evidence):
    _, db, (user_id, product_id, plan_id, _, _) = state
    from app.models import Allergen, ProductAllergen
    from app.services.meal_plan_generator import MealPlanGenerator
    product = await db.get(Product, product_id)
    allergy = Allergen(id=uuid4(), name="Synthetic allergen")
    db.add(allergy)
    if evidence == "contains":
        db.add(ProductAllergen(product_id=product_id, allergen_id=allergy.id))
    else:
        product.nutrition_per_100 = {**product.nutrition_per_100,
                                    "_source": {"allergens_checked": False}}
    plan = await db.get(MealPlan, plan_id)
    shop_id = plan.store_id
    user = await db.get(User, user_id)
    if user.country_code == "PL":
        db.add(StoreProduct(id=uuid4(), store_id=shop_id, product_id=product_id, price=3, is_available=True))
    await db.commit()
    rows = await MealPlanGenerator(db)._filter_eligible_recipes({allergy.id}, shop_id,
        user_id=user_id, country_code=user.country_code)
    assert rows == []


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("reason", ["diet", "allergen", "unknown_allergens"])
async def test_manual_plan_swap_keeps_the_plans_diet_and_account_allergens(state, reason):
    session, db, (user_id, product_id, plan_id, entry_id, replacement_id) = state
    from fastapi import HTTPException
    from app.api.v1 import meal_plans
    from app.models import Allergen, ProductAllergen
    from app.models.user import UserAllergen
    from app.models import MealPlanEntry
    plan = await db.get(MealPlan, plan_id)
    if reason == "diet":
        plan.preferences = {**plan.preferences, "diet": "vegetarian"}
    else:
        allergy = Allergen(id=uuid4(), name="Synthetic allergen")
        db.add(allergy)
        db.add(UserAllergen(user_id=user_id, allergen_id=allergy.id))
        if reason == "allergen":
            db.add(ProductAllergen(product_id=product_id, allergen_id=allergy.id))
        else:
            product = await db.get(Product, product_id)
            product.nutrition_per_100 = {**product.nutrition_per_100,
                                        "_source": {"allergens_checked": False}}
    await db.commit()
    session.expunge_all()
    user = await db.get(User, user_id)
    original = (await db.get(MealPlanEntry, entry_id)).recipe_id
    with pytest.raises(HTTPException) as failure:
        await meal_plans.swap_recipe_in_plan(plan_id, entry_id,
            meal_plans.RecipeSwap(recipe_id=replacement_id), user, db)
    assert failure.value.status_code == 409
    assert (await db.get(MealPlanEntry, entry_id)).recipe_id == original


async def _plan_catalogue(db, user, plan_id, *, limit=1):
    from app.api.v1.recipes import list_recipes
    return await list_recipes(meal_type=None, cuisine=None, difficulty=None, tags=None,
        max_prep_time=None, search=None, favorites_only=False, new_only=False,
        community_only=False, sort_by="name", skip=0, limit=limit,
        current_user=user, db=db, plan_id=plan_id)


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("reason", ["diet", "allergen", "unknown_allergens"])
async def test_plan_picker_filters_before_pagination_and_still_offers_a_valid_dish(state, reason):
    _, db, (user_id, product_id, plan_id, _, _) = state
    from app.models import Allergen, ProductAllergen, RecipeIngredient, RecipeTag
    from app.models.user import UserAllergen
    from tests.test_uk_ons_shopping import food
    from tests.uk_regional_fixtures import reviewed_offer
    from app.models import Store
    from sqlalchemy import select
    plan = await db.get(MealPlan, plan_id)
    if reason == "diet":
        plan.preferences = {**plan.preferences, "diet": "vegetarian"}
    else:
        allergy = Allergen(id=uuid4(), name="Synthetic allergen")
        db.add(allergy)
        db.add(UserAllergen(user_id=user_id, allergen_id=allergy.id))
        if reason == "allergen":
            db.add(ProductAllergen(product_id=product_id, allergen_id=allergy.id))
        else:
            product = await db.get(Product, product_id)
            product.nutrition_per_100 = {**product.nutrition_per_100,
                                        "_source": {"allergens_checked": False}}
    safe_product = food("Ryż biały")
    safe = Recipe(id=uuid4(), name="Z safe dish", meal_type="obiad", servings=2)
    db.add(safe_product)
    db.add(safe)
    await db.flush()
    db.add(RecipeIngredient(id=uuid4(), recipe_id=safe.id, product_id=safe_product.id,
                           quantity=100, unit="g", is_optional=False))
    db.add(RecipeTag(recipe_id=safe.id, tag="wegetariańskie"))
    user = await db.get(User, user_id)
    if user.country_code == "GB":
        with db.allowed():
            reviewed_offer(db.session, safe_product, await db.get(Store, plan.store_id))
    else:
        db.add(StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=safe_product.id,
                            price=3, is_available=True))
    await db.commit()
    rows = await _plan_catalogue(db, user, plan_id)
    assert [row.id for row in rows] == [safe.id]


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_plan_picker_cannot_read_another_accounts_plan_context(state):
    _, db, (_, _, plan_id, _, _) = state
    from app.core.exceptions import NotFoundException
    stranger = User(id=uuid4(), email="stranger@example.invalid", password_hash="test")
    db.add(stranger)
    await db.commit()
    with pytest.raises(NotFoundException):
        await _plan_catalogue(db, stranger, plan_id)


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_http_plan_picker_and_swap_enforce_the_same_diet(state, monkeypatch):
    import httpx
    from fastapi import FastAPI
    from unittest.mock import AsyncMock
    from app.api.deps import get_current_user, get_db
    from app.api.v1 import meal_plans, recipes
    from app.models import MealPlanEntry, RecipeTag
    from app.services import off_on_demand
    _, db, (user_id, _, plan_id, entry_id, replacement_id) = state
    monkeypatch.setattr(off_on_demand, "refresh_public_recipe_evidence", AsyncMock())
    plan = await db.get(MealPlan, plan_id)
    plan.preferences = {**plan.preferences, "diet": "vegetarian"}
    original_id = (await db.get(MealPlanEntry, entry_id)).recipe_id
    db.add(RecipeTag(recipe_id=replacement_id, tag="wegetariańskie"))
    await db.commit()
    async def user_dependency():
        return await db.get(User, user_id)
    async def db_dependency():
        return db
    app = FastAPI()
    app.include_router(recipes.router, prefix="/recipes")
    app.include_router(meal_plans.router, prefix="/plans")
    app.dependency_overrides[get_current_user] = user_dependency
    app.dependency_overrides[get_db] = db_dependency
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        picker = await client.get("/recipes/", params={"plan_id": str(plan_id), "limit": 1})
        assert picker.status_code == 200, picker.text
        assert [row["id"] for row in picker.json()] == [str(replacement_id)]
        path = f"/plans/{plan_id}/entries/{entry_id}/swap"
        rejected = await client.put(path, json={"recipe_id": str(original_id)})
        assert rejected.status_code == 409, rejected.text
        accepted = await client.put(path, json={"recipe_id": str(replacement_id)})
        assert accepted.status_code == 200, accepted.text
        assert accepted.json()["entries"][0]["recipe"]["id"] == str(replacement_id)
