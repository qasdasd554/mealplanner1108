from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from zoneinfo import ZoneInfo

from app.services.weekly_plan_automation import automation_is_due


WARSAW = ZoneInfo("Europe/Warsaw")


def _automation(**overrides):
    values = {
        "enabled": True,
        "weekday": 6,
        "hour": 18,
        "last_attempt_week_start": None,
        "last_attempt_at": None,
        "last_error": None,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def test_automation_waits_until_selected_time() -> None:
    sunday_before = datetime(2026, 10, 4, 17, 59, tzinfo=WARSAW)
    assert not automation_is_due(_automation(), sunday_before)
    assert automation_is_due(_automation(), sunday_before.replace(hour=18))


def test_automation_catches_up_after_selected_day() -> None:
    thursday_after = datetime(2026, 10, 1, 9, 0, tzinfo=WARSAW)
    assert automation_is_due(_automation(weekday=2), thursday_after)


def test_success_is_not_repeated_in_same_week() -> None:
    now = datetime(2026, 10, 4, 19, 0, tzinfo=WARSAW)
    assert not automation_is_due(
        _automation(last_attempt_week_start=now.date() - timedelta(days=6)),
        now,
    )


def test_failure_retries_only_after_six_hours() -> None:
    now = datetime(2026, 10, 4, 19, 0, tzinfo=WARSAW)
    week_start = now.date() - timedelta(days=6)
    recent = now.astimezone(timezone.utc) - timedelta(hours=2)
    old = now.astimezone(timezone.utc) - timedelta(hours=7)
    assert not automation_is_due(
        _automation(
            last_attempt_week_start=week_start,
            last_attempt_at=recent,
            last_error="błąd",
        ),
        now,
    )
    assert automation_is_due(
        _automation(
            last_attempt_week_start=week_start,
            last_attempt_at=old,
            last_error="błąd",
        ),
        now,
    )
