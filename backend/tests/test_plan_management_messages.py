import asyncio
from datetime import date, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1 import meal_plans
from app.core.market_clock import market_today


def user(country, *, premium=False):
    return SimpleNamespace(
        id=uuid4(), country_code=country, role="user", is_premium=premium,
        premium_expires_at=None, premium_product_id=None,
    )


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("action,pl,en", [
    ("archive", "Archiwum planów jest dostępne w Premium.", "Plan archives are available with Premium."),
    ("save", "Automatyczny tydzień jest dostępny w Premium.", "Automatic weekly planning is available with Premium."),
    ("run", "Ta funkcja wymaga Premium.", "This feature requires Premium."),
    ("resume", "Wznawianie planów jest dostępne w Premium.", "Resuming plans is available with Premium."),
])
def test_premium_gates_keep_status_and_account_language(country, action, pl, en):
    account = user(country)
    # All gates must reject before any database access.
    if action == "archive":
        operation = meal_plans.list_archived_meal_plans(account, None)
    elif action == "save":
        operation = meal_plans.update_weekly_automation(
            meal_plans.WeeklyAutomationUpdate(enabled=True), account, None)
    elif action == "run":
        operation = meal_plans.run_weekly_automation_now(account, None)
    else:
        operation = meal_plans.resume_meal_plan(uuid4(),
            meal_plans.ResumeMealPlanRequest(start_date=date(2026, 10, 21)), account, None)
    with pytest.raises(HTTPException) as caught:
        asyncio.run(operation)
    assert caught.value.status_code == 403
    assert caught.value.detail == (en if country == "GB" else pl)


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_resume_date_error_is_localised_before_database_access(country):
    account = user(country, premium=True)
    with pytest.raises(HTTPException) as caught:
        asyncio.run(meal_plans.resume_meal_plan(uuid4(),
            meal_plans.ResumeMealPlanRequest(start_date=market_today(account) - timedelta(days=1)),
            account, None))
    assert caught.value.status_code == 422
    assert caught.value.detail == (
        "The start date cannot be before today." if country == "GB"
        else "Data rozpoczęcia nie może być wcześniejsza niż dzisiaj.")
