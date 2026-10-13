"""Preferencje Premium nigdy nie obchodzą limitów, alergii ani widoczności."""

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from app.api.v1.users import (
    UserProfileUpdate,
    get_ingredient_preferences,
    update_ingredient_preferences,
)
from app.schemas.meal_plan import MealPlanGenerateRequest
from app.schemas.user import IngredientPreferencesUpdate, UserCreate
from app.services.exceptions import ServiceError
from app.services.meal_plan_generator import (
    MealPlanGenerator,
    active_ingredient_preferences,
    effective_household_size,
    effective_target_kcal,
)


def _user(**overrides):
    values = dict(
        id=uuid4(), role="user", is_premium=True,
        premium_expires_at=datetime.now(timezone.utc) + timedelta(days=1),
        premium_product_id="premium_monthly", household_size=2,
        daily_kcal_goal=2300, dietary_preferences={}, ingredient_preferences={},
    )
    values.update(overrides)
    return SimpleNamespace(**values)


def _recipe(name, ingredients, meal_type="obiad"):
    return SimpleNamespace(
        id=uuid4(), name=name, meal_type=meal_type, servings=1,
        ingredients=[SimpleNamespace(product_id=identifier) for identifier in ingredients],
    )


@pytest.mark.parametrize("value", [0, 9, 10, 100])
def test_all_household_request_schemas_reject_outside_one_to_eight(value):
    for schema, extra in (
        (UserCreate, {"email": "a@b.pl", "password": "password123"}),
        (UserProfileUpdate, {}),
        (MealPlanGenerateRequest, {"store_id": uuid4()}),
    ):
        with pytest.raises(ValidationError):
            schema(household_size=value, **extra)
    with pytest.raises(ServiceError):
        effective_household_size(_user(), value)


def test_profile_cannot_reset_household_to_database_null():
    with pytest.raises(ValidationError):
        UserProfileUpdate(household_size=None)
    assert UserProfileUpdate().model_dump(exclude_unset=True) == {}


@pytest.mark.parametrize("stored,expected", [(10, 8), (8, 8), (-1, 1), (None, 1)])
def test_legacy_household_values_are_clamped(stored, expected):
    user = _user(household_size=stored)
    assert effective_household_size(user) == expected
    assert user.household_size == stored  # No unnoticed profile mutation.


def test_calorie_goal_order_is_explicit_then_saved_then_2000():
    assert effective_target_kcal(_user(), 1800) == 1800
    assert effective_target_kcal(_user()) == 2300
    assert effective_target_kcal(_user(daily_kcal_goal=6000)) == 6000
    assert effective_target_kcal(_user(daily_kcal_goal=None)) == 2000
    assert effective_target_kcal(_user(daily_kcal_goal=0)) == 2000
    assert effective_target_kcal(_user(daily_kcal_goal=float("nan"))) == 2000
    with pytest.raises(ServiceError):
        effective_target_kcal(_user(), float("inf"))


def test_preference_schema_is_bounded_disjoint_and_deduplicated():
    identifier = uuid4()
    assert IngredientPreferencesUpdate(liked_product_ids=[identifier, identifier]).liked_product_ids == [identifier]
    with pytest.raises(ValidationError):
        IngredientPreferencesUpdate(liked_product_ids=[identifier], disliked_product_ids=[identifier])
    with pytest.raises(ValidationError):
        IngredientPreferencesUpdate(liked_product_ids=[uuid4() for _ in range(51)])


def test_premium_expiry_disables_but_keeps_saved_preferences():
    identifier = uuid4()
    stored = {"liked_product_ids": [str(identifier)], "disliked_product_ids": []}
    user = _user(ingredient_preferences=stored)
    assert active_ingredient_preferences(user) == ({identifier}, set())
    user.premium_expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    assert active_ingredient_preferences(user) == (set(), set())
    assert user.ingredient_preferences == stored


@pytest.mark.asyncio
async def test_expired_account_cannot_save_preferences_or_call_database():
    db = AsyncMock()
    user = _user(premium_expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
    with pytest.raises(HTTPException) as exc:
        await update_ingredient_preferences(IngredientPreferencesUpdate(), user, db)
    assert exc.value.status_code == 403
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_save_rejects_unknown_or_unapproved_product_ids_without_mutating():
    db = AsyncMock()
    result = MagicMock()
    result.all.return_value = []
    db.execute.return_value = result
    user = _user()
    with pytest.raises(HTTPException) as exc:
        await update_ingredient_preferences(IngredientPreferencesUpdate(liked_product_ids=[uuid4()]), user, db)
    assert exc.value.status_code == 400
    assert "review_status" in str(db.execute.call_args.args[0])
    assert user.ingredient_preferences == {}
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_preference_names_are_loaded_in_one_query_and_removed_ids_hidden():
    liked, removed, disliked = uuid4(), uuid4(), uuid4()
    user = _user(ingredient_preferences={
        "liked_product_ids": [str(liked), str(removed)],
        "disliked_product_ids": [str(disliked)],
    })
    db = AsyncMock()
    result = MagicMock()
    result.all.return_value = [(liked, "Ciecierzyca"), (disliked, "Brokuł")]
    db.execute.return_value = result
    response = await get_ingredient_preferences(user, db)
    assert response.liked_product_ids == [liked]
    assert response.liked_products[0].name == "Ciecierzyca"
    assert response.disliked_products[0].name == "Brokuł"
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_save_serializes_canonical_ids_and_returns_names():
    identifier = uuid4()
    user = _user()
    db = AsyncMock()
    db.add = MagicMock()
    result = MagicMock()
    result.all.return_value = [(identifier, "Ryż")]
    db.execute.return_value = result
    response = await update_ingredient_preferences(IngredientPreferencesUpdate(liked_product_ids=[identifier]), user, db)
    assert user.ingredient_preferences == {"liked_product_ids": [str(identifier)], "disliked_product_ids": []}
    assert response.liked_products[0].name == "Ryż"
    db.commit.assert_awaited_once()


def test_preferences_affect_at_least_one_recipe_each_day_not_the_whole_day():
    liked, disliked = uuid4(), uuid4()
    ordinary = _recipe("Danie zwykłe", [disliked])
    preferred = _recipe("Danie ulubione", [liked])
    generator = MealPlanGenerator(AsyncMock())
    warnings = []
    selected = [(day, "obiad", ordinary) for day in range(1, 8)]
    selected += [(day, "kolacja", ordinary) for day in range(1, 8)]
    # Isolated selection tests should not depend on nutrition mock fields.
    with patch.object(generator, "_score_candidate", return_value=0.8):
        result = generator._apply_ingredient_preferences(selected, [ordinary, preferred], {liked}, {disliked}, warnings)
    for day in range(1, 8):
        recipes = [recipe for entry_day, _slot, recipe in result if entry_day == day]
        assert preferred in recipes
        assert ordinary in recipes
    assert warnings == []


def test_liked_recipe_with_disliked_ingredient_is_never_preference_match():
    liked, disliked, neutral = uuid4(), uuid4(), uuid4()
    conflicting = _recipe("Konflikt", [liked, disliked])
    safe = _recipe("Bez konfliktu", [neutral])
    generator = MealPlanGenerator(AsyncMock())
    warnings = []
    with patch.object(generator, "_score_candidate", return_value=0.8):
        result = generator._apply_ingredient_preferences([(1, "obiad", conflicting)], [conflicting, safe], {liked}, {disliked}, warnings)
    assert result[0][2] is safe
    assert len(warnings) == 1
    assert "lubianymi" in warnings[0]


def test_full_greedy_algorithm_and_calorie_topup_keep_daily_preference():
    liked, disliked = uuid4(), uuid4()
    ordinary = _recipe("Gulasz zwykły", [disliked])
    preferred = _recipe("Pieczone warzywa ulubione", [liked])
    supper = _recipe("Kanapki zwykłe", [disliked], "kolacja")
    generator = MealPlanGenerator(AsyncMock())
    warnings = []
    with (
        patch.object(generator, "_score_candidate", side_effect=lambda candidate, *args, **kwargs: 0.1 if candidate is preferred else 0.8),
        patch.object(generator, "_sum_per_person_nutrition", side_effect=lambda recipes: {"kcal": len(recipes) * 1000}),
    ):
        result = generator._greedy_select(
            [ordinary, preferred, supper],
            [(day, slot) for day in range(1, 8) for slot in ("obiad", "kolacja")],
            None, uuid4(), target_kcal=2000,
            liked_ingredient_ids={liked}, disliked_ingredient_ids={disliked},
            preference_warnings=warnings,
        )
    for day in range(1, 8):
        day_recipes = [recipe for entry_day, _slot, recipe in result if day == entry_day]
        assert preferred in day_recipes
        assert len({recipe.id for recipe in day_recipes}) == len(day_recipes)
    assert warnings == []


def test_no_safe_recipe_reports_warning_without_inventing_or_bypassing_filters():
    disliked = uuid4()
    recipe = _recipe("Jedyny dostępny", [disliked])
    warnings = []
    result = MealPlanGenerator(AsyncMock())._apply_ingredient_preferences(
        [(1, "obiad", recipe), (2, "obiad", recipe)], [recipe], set(), {disliked}, warnings,
    )
    assert [entry[2] for entry in result] == [recipe, recipe]
    assert len(warnings) == 2
    assert all("dietą, alergiami" in warning for warning in warnings)


def test_preferences_do_not_introduce_duplicate_recipe_families_in_one_day():
    liked, neutral = uuid4(), uuid4()
    selected_dinner = _recipe("Zupa marchewkowa", [neutral], "obiad")
    selected_supper = _recipe("Zupa marchewkowa z pestkami", [neutral], "kolacja")
    preferred = _recipe("Zupa marchewkowa", [liked], "kolacja")
    generator = MealPlanGenerator(AsyncMock())
    # All variants have the same family; the candidate is blocked by existing dinner.
    warnings = []
    result = generator._apply_ingredient_preferences(
        [(1, "obiad", selected_dinner), (1, "kolacja", selected_supper)],
        [selected_dinner, selected_supper, preferred], {liked}, set(), warnings,
    )
    assert preferred not in [entry[2] for entry in result]
    assert warnings


@pytest.mark.asyncio
async def test_allergy_filter_runs_before_favorite_recipe_selection():
    allergen, liked, neutral = uuid4(), uuid4(), uuid4()
    unsafe = _recipe("Ulubione z alergenem", [liked])
    safe = _recipe("Bez alergenu", [neutral])
    recipes_result = MagicMock()
    recipes_result.scalars.return_value.unique.return_value.all.return_value = [unsafe, safe]
    available_result = MagicMock()
    available_result.all.return_value = [(liked,), (neutral,)]
    allergens_result = MagicMock()
    allergens_result.all.return_value = [(liked, allergen)]
    db = AsyncMock()
    db.execute.side_effect = [recipes_result, available_result, allergens_result]
    generator = MealPlanGenerator(db)
    eligible = await generator._filter_eligible_recipes({allergen}, uuid4(), "Wegańska", uuid4())
    assert eligible == [safe]
    assert "recipe_tags" in str(db.execute.call_args_list[0].args[0])
    assert "visibility" in str(db.execute.call_args_list[0].args[0])
    warnings = []
    result = generator._apply_ingredient_preferences([(1, "obiad", safe)], eligible, {liked}, set(), warnings)
    assert result[0][2] is safe
    assert warnings  # Allergy takes precedence over the liked ingredient.


@pytest.mark.asyncio
@pytest.mark.parametrize("diet", ["Nieznana dieta", {"diet": "Keto"}])
async def test_unknown_or_malformed_diet_is_not_silently_ignored(diet):
    db = AsyncMock()
    with pytest.raises(ServiceError):
        await MealPlanGenerator(db)._filter_eligible_recipes(set(), uuid4(), diet, uuid4())
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("diet", ["Bez ograniczeń", "bez ograniczen", "brak", "WEGAŃSKA", "weganska", "wegańskie", "vegan", "high_protein", "gluten_free"])
async def test_supported_ui_and_legacy_diet_labels_remain_accepted(diet):
    db = AsyncMock()
    recipes = MagicMock()
    recipes.scalars.return_value.unique.return_value.all.return_value = []
    available = MagicMock()
    available.all.return_value = []
    db.execute.side_effect = [recipes, available]
    assert await MealPlanGenerator(db)._filter_eligible_recipes(set(), uuid4(), diet, uuid4()) == []


@pytest.mark.asyncio
async def test_generate_uses_saved_goal_caps_profile_and_persists_visible_warnings():
    user = _user(household_size=10, daily_kcal_goal=2450)
    recipe = _recipe("Obiad", [uuid4()])
    plan = SimpleNamespace(id=uuid4(), preferences=None)
    db = AsyncMock()
    loaded = MagicMock()
    loaded.scalar_one.return_value = plan
    db.execute.return_value = loaded
    generator = MealPlanGenerator(db)
    with (
        patch.object(generator, "_load_user_profile", AsyncMock(return_value=(user, set()))),
        patch.object(generator, "_filter_eligible_recipes", AsyncMock(return_value=[recipe])),
        patch.object(generator, "_load_pantry_product_ids", AsyncMock(return_value=set())),
        patch.object(generator, "_greedy_select", return_value=[(1, "obiad", recipe)]) as select_mock,
        patch.object(generator, "_persist_plan", AsyncMock(return_value=plan)),
        patch("app.services.meal_plan_quota.record_meal_plan_creation", AsyncMock()),
    ):
        response = await generator.generate(
            user.id, uuid4(), 1, 1, create_shopping_list=False,
            preferences={"liked_product_ids": [str(uuid4())]},
        )
    assert select_mock.call_args.kwargs["target_kcal"] == 2450
    assert select_mock.call_args.kwargs["liked_ingredient_ids"] == set()
    assert response.preferences["household_size"] == 8
    assert response.preferences["target_kcal"] == 2450
    assert response.preference_warnings == []
