"""Recipe visibility must hold across indirect meal-plan access."""

from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.api.v1 import meal_plans
from app.core.exceptions import NotFoundException


def result(value):
    mocked = MagicMock()
    mocked.scalar_one_or_none.return_value = value
    mocked.scalar_one.return_value = value
    return mocked


@pytest.mark.asyncio
async def test_swap_does_not_disclose_or_mutate_strangers_private_recipe():
    user = SimpleNamespace(id=uuid4(), role="user")
    today = datetime.now(meal_plans.WARSAW).date()
    plan = SimpleNamespace(id=uuid4(), status="active", start_date=today, end_date=today + timedelta(days=6), duration_days=7, shopping_list=None)
    entry = SimpleNamespace(id=uuid4(), recipe_id=uuid4())
    original = entry.recipe_id
    secret = SimpleNamespace(id=uuid4(), created_by_user_id=uuid4(), visibility="private", is_active=True)
    db = AsyncMock()
    db.add = MagicMock()
    db.get.return_value = secret
    db.execute.side_effect = [result(plan), result(entry), result(None)]
    with pytest.raises(NotFoundException):
        await meal_plans.swap_recipe_in_plan(plan.id, entry.id, meal_plans.RecipeSwap(recipe_id=secret.id), user, db)
    assert entry.recipe_id == original
    db.flush.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("visibility", ["pending", "rejected"])
async def test_friends_cannot_read_unmoderated_recipes(visibility):
    from app.api.v1.recipes import get_recipe
    db = AsyncMock()
    recipe = SimpleNamespace(id=uuid4(), created_by_user_id=uuid4(), visibility=visibility)
    db.execute.return_value = result(recipe)
    with pytest.raises(NotFoundException):
        await get_recipe(recipe.id, SimpleNamespace(id=uuid4(), role="user"), db)
