"""Regresje błędów prywatności i idempotencji wykrytych w audycie."""

from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.api.v1.shopping_lists import ShareShoppingListRequest, share_shopping_list
from app.api.v1.recipes import get_recipe
from app.api.v1.users import block_user


def _result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
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
        _result(SimpleNamespace(id=recipient_id, display_name="Ola", email="ola@example.com")),
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
async def test_admin_can_review_a_pending_recipe_without_being_the_author_or_friend() -> None:
    recipe = SimpleNamespace(
        id=uuid4(),
        created_by_user_id=uuid4(),
        visibility="pending",
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
