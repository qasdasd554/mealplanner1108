"""Regresje tygodniowego limitu tworzenia planów posiłków."""

import asyncio
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from fastapi import HTTPException

from app.services.meal_plan_quota import (
    can_create_meal_plan, record_meal_plan_creation,
)
from app.services.shopping_list_quota import calendar_week_start


def test_week_runs_from_monday_to_sunday() -> None:
    assert calendar_week_start(date(2026, 9, 21)) == date(2026, 9, 21)
    assert calendar_week_start(date(2026, 9, 27)) == date(2026, 9, 21)
    assert calendar_week_start(date(2026, 9, 28)) == date(2026, 9, 28)


def test_standard_account_can_create_first_plan() -> None:
    user = SimpleNamespace(id=uuid4(), role="user", is_premium=False)
    count_result = SimpleNamespace(scalar_one=lambda: 0)
    db = SimpleNamespace(execute=AsyncMock(side_effect=[None, count_result]))
    assert asyncio.run(can_create_meal_plan(db, user=user)) is True


def test_second_plan_in_same_week_is_rejected_even_if_previous_was_deleted() -> None:
    user = SimpleNamespace(id=uuid4(), role="user", is_premium=False)
    count_result = SimpleNamespace(scalar_one=lambda: 1)
    db = SimpleNamespace(
        execute=AsyncMock(side_effect=[None, count_result]),
        add=MagicMock(), flush=AsyncMock(),
    )
    try:
        asyncio.run(record_meal_plan_creation(db, user=user, meal_plan_id=uuid4()))
    except HTTPException as exc:
        assert exc.status_code == 403
        assert "tygodniu" in exc.detail
    else:
        raise AssertionError("Drugi plan standardowego konta musi być odrzucony")
    db.add.assert_not_called()


def test_premium_plan_creation_has_no_weekly_query() -> None:
    user = SimpleNamespace(id=uuid4(), role="admin")
    db = SimpleNamespace(execute=AsyncMock(), add=MagicMock(), flush=AsyncMock())
    asyncio.run(record_meal_plan_creation(db, user=user, meal_plan_id=uuid4()))
    db.execute.assert_not_called()
    db.add.assert_called_once()
    db.flush.assert_awaited_once()
