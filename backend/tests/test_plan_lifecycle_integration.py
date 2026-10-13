"""Wpięcie cyklu planu w serwer i trwały cel powiadomienia."""

import asyncio
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app import main
from app.api.v1.notifications import _to_response
from app.services import push


@pytest.mark.asyncio
async def test_startup_prepares_existing_neon_schema_idempotently(monkeypatch):
    statements = []

    class Connection:
        async def run_sync(self, callback):
            pass

        async def execute(self, statement):
            statements.append(str(statement))

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            pass

    import app.db.session as session_module
    monkeypatch.setattr(session_module, "engine", SimpleNamespace(begin=Connection))
    await main._create_tables()
    assert any("ADD COLUMN IF NOT EXISTS ingredient_preferences JSON" in s for s in statements)
    assert any("expiration_reminder_sent_at TIMESTAMPTZ" in s for s in statements)
    assert any("ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ" in s for s in statements)
    assert any("ADD COLUMN IF NOT EXISTS meal_plan_id UUID" in s for s in statements)
    clamp_index = next(i for i, s in enumerate(statements) if "LEAST(8, GREATEST(1" in s)
    check_index = next(i for i, s in enumerate(statements) if "ADD CONSTRAINT ck_users_household_size_1_8" in s)
    assert clamp_index < check_index
    assert "IF NOT EXISTS" in statements[check_index]


@pytest.mark.asyncio
async def test_background_worker_recovers_after_failure(monkeypatch):
    run = AsyncMock(side_effect=[RuntimeError("temporary"), None])
    sleeps = []

    async def sleep(seconds):
        sleeps.append(seconds)
        if len(sleeps) == 2:
            raise asyncio.CancelledError

    monkeypatch.setattr(main, "_run_meal_plan_lifecycle_once", run)
    monkeypatch.setattr(main.asyncio, "sleep", sleep)
    with pytest.raises(asyncio.CancelledError):
        await main._meal_plan_lifecycle_background_loop()
    assert run.await_count == 2
    assert sleeps == [300, 300]


def _notification():
    return SimpleNamespace(
        id=uuid.uuid4(), user_id=uuid.uuid4(), notification_type="meal_plan_expiring",
        meal_plan_id=uuid.uuid4(), recipe_id=None, recipe=None, comment_id=None,
        message="Twój plan kończy się jutro.", is_read=False,
        created_at=datetime.now(timezone.utc),
    )


def test_inapp_notification_retains_plan_target():
    notification = _notification()
    assert _to_response(notification).meal_plan_id == notification.meal_plan_id


@pytest.mark.asyncio
async def test_push_uses_same_plan_target_as_inapp_notification(monkeypatch):
    notification = _notification()
    send = AsyncMock(return_value=1)
    monkeypatch.setattr(push, "is_push_enabled", lambda: True)
    monkeypatch.setattr(push, "send_push_to_user", send)
    await push.push_for_notification(object(), notification)
    send.assert_awaited_once()
    _, user_id, title, message, data = send.await_args.args
    assert user_id == notification.user_id
    assert title == "Twój plan wkrótce się kończy"
    assert message == notification.message
    assert data == {"type": "meal_plan_expiring", "meal_plan_id": str(notification.meal_plan_id)}
