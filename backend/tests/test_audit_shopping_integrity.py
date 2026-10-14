"""Deleting a list preserves a real archive; sharing hides private email."""

import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.api.v1 import shopping_lists
from app.models import MealPlan, MealPlanEntry, ShoppingList
from tests.test_meal_plan_lifecycle import db, make_plan


def test_deleting_archived_plan_list_keeps_meal_history(db):
    user, plan, entry, shopping, *_ = make_plan(db, premium=True, status="archived")
    plan.archived_at = datetime.now(timezone.utc)
    db.session.commit()
    async def delete(row):
        db.session.delete(row)
    db.delete = delete
    plan_id, entry_id, list_id = plan.id, entry.id, shopping.id
    asyncio.run(shopping_lists.delete_shopping_list(plan_id, user, db))
    assert db.session.get(MealPlan, plan_id) is not None
    assert db.session.get(MealPlanEntry, entry_id) is not None
    assert db.session.get(ShoppingList, list_id) is None


@pytest.mark.asyncio
async def test_share_by_public_nickname_does_not_reveal_private_email():
    def result(value):
        mocked = MagicMock()
        mocked.scalar_one_or_none.return_value = value
        return mocked
    recipient = SimpleNamespace(id=uuid4(), display_name="Ola", email="private@example.com")
    matches = MagicMock()
    matches.scalars.return_value.all.return_value = [recipient]
    share = SimpleNamespace(id=uuid4(), meal_plan_id=uuid4(), status="pending", created_at=datetime.now(timezone.utc))
    db = AsyncMock()
    db.execute.side_effect = [result(SimpleNamespace(id=share.meal_plan_id)), matches, result(None), result(share)]
    response = await shopping_lists.share_shopping_list(share.meal_plan_id, shopping_lists.ShareShoppingListRequest(display_name="Ola"), SimpleNamespace(id=uuid4()), db)
    assert response.shared_with_email is None
