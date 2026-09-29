"""Regresje błędów prywatności i idempotencji wykrytych w audycie."""

from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.api.v1.shopping_lists import ShareShoppingListRequest, share_shopping_list
from app.api.v1.food_log import FoodLogNutritionUpdate, update_food_log_entry_nutrition
from app.api.v1.recipes import get_recipe, list_all_user_recipes
from app.api.v1.users import block_user


def _result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


def _scalars_result(values):
    result = MagicMock()
    result.scalars.return_value.all.return_value = values
    return result


def _unique_scalars_result(values):
    result = MagicMock()
    result.unique.return_value.scalars.return_value.all.return_value = values
    return result


@pytest.mark.asyncio
async def test_existing_share_does_not_create_duplicate_notification() -> None:
    owner_id = uuid4()
    recipient_id = uuid4()
    plan_id = uuid4()
    existing = SimpleNamespace(
        id=uuid4(),
        meal_plan_id=plan_id,
        status="pending",
        created_at=datetime.now(timezone.utc),
    )
    db = AsyncMock()
    db.execute.side_effect = [
        _result(SimpleNamespace(id=plan_id)),
        _scalars_result(
            [SimpleNamespace(id=recipient_id, display_name="Ola", email="ola@example.com")]
        ),
        _result(None),
        _result(existing),
    ]
    current_user = SimpleNamespace(id=owner_id, display_name="Adam")

    response = await share_shopping_list(
        plan_id,
        ShareShoppingListRequest(display_name="Ola"),
        current_user=current_user,
        db=db,
    )

    assert response.id == existing.id
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_repeated_block_still_revokes_friendship_and_list_shares() -> None:
    current_user = SimpleNamespace(id=uuid4())
    target_id = uuid4()
    db = AsyncMock()
    db.get.return_value = SimpleNamespace(id=target_id)
    db.execute.side_effect = [_result(SimpleNamespace(id=uuid4())), MagicMock(), MagicMock()]

    await block_user(target_id, current_user=current_user, db=db)

    # Odczyt istniejącej blokady + usunięcie znajomości + usunięcie
    # udostępnień list. Wcześniej funkcja kończyła się po pierwszym kroku.
    assert db.execute.await_count == 3
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("visibility", ["private", "pending", "rejected"])
async def test_admin_can_review_non_public_recipe_without_being_author_or_friend(
    visibility: str,
) -> None:
    recipe = SimpleNamespace(
        id=uuid4(),
        created_by_user_id=uuid4(),
        visibility=visibility,
    )
    recipe_result = _result(recipe)
    favorites_result = MagicMock()
    favorites_result.scalars.return_value.all.return_value = []
    db = AsyncMock()
    db.execute.side_effect = [recipe_result, favorites_result]
    admin = SimpleNamespace(id=uuid4(), role="admin")

    response = await get_recipe(recipe.id, current_user=admin, db=db)

    assert response is recipe
    assert response.is_own_recipe is False
    # Zapytanie o znajomość nie powinno być potrzebne administratorowi.
    assert db.execute.await_count == 2


@pytest.mark.asyncio
async def test_admin_recipe_list_applies_requested_page() -> None:
    recipes = [SimpleNamespace(id=uuid4())]
    db = AsyncMock()
    db.execute.return_value = _unique_scalars_result(recipes)
    admin = SimpleNamespace(id=uuid4(), role="admin")

    response = await list_all_user_recipes(
        skip=30,
        limit=31,
        current_user=admin,
        db=db,
    )

    assert response == recipes
    statement = db.execute.await_args.args[0]
    assert statement._offset_clause.value == 30
    assert statement._limit_clause.value == 31


@pytest.mark.asyncio
async def test_food_log_amount_update_persists_servings_and_scaled_nutrition() -> None:
    user_id = uuid4()
    entry = SimpleNamespace(
        id=uuid4(),
        user_id=user_id,
        servings=1.0,
        calories=500.0,
        protein=20.0,
        fat=15.0,
        carbs=60.0,
    )
    db = AsyncMock()
    db.get.return_value = entry
    db.add = MagicMock()
    user = SimpleNamespace(id=user_id)

    await update_food_log_entry_nutrition(
        entry.id,
        FoodLogNutritionUpdate(
            calories=250,
            protein=10,
            fat=7.5,
            carbs=30,
            servings=0.5,
        ),
        db=db,
        current_user=user,
    )

    assert entry.servings == 0.5
    assert entry.calories == 250
    assert entry.protein == 10
    assert entry.fat == 7.5
    assert entry.carbs == 30
    db.commit.assert_awaited_once()
