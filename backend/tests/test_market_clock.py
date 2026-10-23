from datetime import date, datetime, timezone
from types import SimpleNamespace
import asyncio
from unittest.mock import AsyncMock, Mock

import pytest

from app.core.market_clock import market_today, market_timezone
from app.models import MealPlan
from app.services.meal_plan_lifecycle import plan_expires_at, plan_has_expired
from app.services.shopping_list_quota import calendar_week_start
from app.services.weekly_plan_automation import automation_is_due


@pytest.mark.parametrize("instant,pl_day,gb_day", [
    (datetime(2026, 10, 18, 22, 30, tzinfo=timezone.utc), date(2026, 10, 19), date(2026, 10, 18)),
    (datetime(2026, 10, 25, 23, 30, tzinfo=timezone.utc), date(2026, 10, 26), date(2026, 10, 25)),
    (datetime(2026, 3, 29, 22, 30, tzinfo=timezone.utc), date(2026, 3, 30), date(2026, 3, 29)),
])
def test_account_day_and_week_boundaries_use_market_not_server_timezone(instant, pl_day, gb_day):
    for country, expected in (("PL", pl_day), ("GB", gb_day)):
        user = SimpleNamespace(country_code=country)
        assert market_today(user, now=instant) == expected
        assert calendar_week_start(country_code=country, now=instant) == date.fromordinal(expected.toordinal() - expected.weekday())


def test_legacy_or_unknown_country_remains_warsaw():
    assert str(market_timezone(None)) == "Europe/Warsaw"
    assert str(market_timezone(SimpleNamespace(country_code="GB"))) == "Europe/London"
    assert str(market_timezone(SimpleNamespace(country_code="US"))) == "Europe/Warsaw"


@pytest.mark.parametrize("start,gb_expiry,pl_expiry", [
    (date(2026, 10, 19), datetime(2026, 10, 26, tzinfo=timezone.utc), datetime(2026, 10, 25, 23, tzinfo=timezone.utc)),
    (date(2026, 3, 23), datetime(2026, 3, 29, 23, tzinfo=timezone.utc), datetime(2026, 3, 29, 22, tzinfo=timezone.utc)),
])
def test_plan_ends_after_its_last_market_day_including_dst(start, gb_expiry, pl_expiry):
    plan = MealPlan(start_date=start, duration_days=7)
    assert plan_expires_at(plan, country_code="GB") == gb_expiry
    assert plan_expires_at(plan) == pl_expiry
    assert plan_has_expired(plan, country_code="GB", now=pl_expiry) is False
    assert plan_has_expired(plan, country_code="GB", now=gb_expiry) is True


def test_weekly_automation_waits_for_selected_london_hour_not_warsaw_hour():
    schedule = SimpleNamespace(enabled=True, weekday=6, hour=18,
                               last_attempt_week_start=None, last_attempt_at=None, last_error=None)
    now = datetime(2026, 10, 4, 17, 30, tzinfo=market_timezone("GB"))
    assert not automation_is_due(schedule, now)
    assert automation_is_due(schedule, now.replace(hour=18))


@pytest.mark.parametrize("module_name", ["meal_plan_quota", "shopping_list_quota"])
def test_quota_reads_persisted_country(module_name, monkeypatch):
    from importlib import import_module
    module = import_module("app.services." + module_name)
    week = Mock(return_value=date(2026, 10, 12))
    monkeypatch.setattr(module, "calendar_week_start", week)
    db = SimpleNamespace(execute=AsyncMock(side_effect=[None, SimpleNamespace(scalar_one=lambda: 0)]))
    user = SimpleNamespace(id="test", country_code="GB", role="user", is_premium=False,
                           premium_product_id=None, premium_expires_at=None)
    call = getattr(module, "can_create_" + ("meal_plan" if module_name == "meal_plan_quota" else "shopping_list"))
    assert asyncio.run(call(db, user=user))
    week.assert_called_once_with(country_code="GB")
