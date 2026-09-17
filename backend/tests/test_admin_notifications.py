"""Powiadomienia administratorów o nowych elementach moderacji."""

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from app.services.admin_notifications import notify_admins_pending_review


@pytest.mark.asyncio
async def test_pending_review_notifies_and_pushes_to_every_admin() -> None:
    admin_ids = [uuid4(), uuid4()]
    result = MagicMock()
    result.scalars.return_value.all.return_value = admin_ids

    db = AsyncMock()
    db.execute.return_value = result
    push = AsyncMock()

    with (
        patch("app.services.push.is_push_enabled", return_value=True),
        patch("app.services.push.push_for_notification", push),
    ):
        count = await notify_admins_pending_review(
            db,
            notification_type="product_pending_approval",
            message="Produkt wymaga sprawdzenia",
        )

    assert count == 2
    assert db.add.call_count == 2
    db.commit.assert_awaited_once()
    assert push.await_count == 2


@pytest.mark.asyncio
async def test_pending_review_without_admins_is_a_noop() -> None:
    result = MagicMock()
    result.scalars.return_value.all.return_value = []
    db = AsyncMock()
    db.execute.return_value = result

    count = await notify_admins_pending_review(
        db,
        notification_type="content_report_pending",
        message="Nowe zgłoszenie",
    )

    assert count == 0
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
