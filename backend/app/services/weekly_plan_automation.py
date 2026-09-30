"""Generowanie cotygodniowego planu Premium w tle."""

from __future__ import annotations

import logging
from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.premium import is_premium_active
from app.models import Notification, User, WeeklyPlanAutomation
from app.services.meal_plan_generator import MealPlanGenerator
from app.services.push import push_for_notification
from app.services.shopping_list_quota import calendar_week_start

logger = logging.getLogger(__name__)
WARSAW = ZoneInfo("Europe/Warsaw")


def automation_is_due(
    automation: WeeklyPlanAutomation, now_local: datetime
) -> bool:
    if not automation.enabled:
        return False
    week = calendar_week_start(now_local.date())
    scheduled_date = week + timedelta(days=automation.weekday)
    scheduled_at = datetime.combine(
        scheduled_date,
        time(hour=automation.hour),
        tzinfo=WARSAW,
    )
    if now_local < scheduled_at:
        return False
    if automation.last_attempt_week_start != week:
        return True
    # Po błędzie ponawiamy najwcześniej po 6 h, zamiast próbować co 10 min.
    if automation.last_error and automation.last_attempt_at:
        attempted = automation.last_attempt_at
        if attempted.tzinfo is None:
            attempted = attempted.replace(tzinfo=timezone.utc)
        return now_local.astimezone(timezone.utc) - attempted >= timedelta(hours=6)
    return False


async def generate_for_user(
    db: AsyncSession,
    automation: WeeklyPlanAutomation,
    user: User,
    *,
    now_local: datetime | None = None,
) -> bool:
    """Wykonuje jedną automatyzację. Zwraca True po utworzeniu planu."""
    now_local = now_local or datetime.now(WARSAW)
    now_utc = datetime.now(timezone.utc)
    user_id = user.id
    automation.last_attempt_week_start = calendar_week_start(now_local.date())
    automation.last_attempt_at = now_utc
    automation.last_error = None
    db.add(automation)
    await db.commit()

    if not is_premium_active(user):
        automation.enabled = False
        automation.last_error = "Premium wygasło — automatyzacja została wyłączona."
        message = automation.last_error
        notification_type = "weekly_plan_failed"
    elif user.preferred_store_id is None:
        automation.last_error = "Wybierz ulubiony sklep w profilu."
        message = "Nie utworzyliśmy planu. Wybierz ulubiony sklep w profilu i spróbuj ponownie."
        notification_type = "weekly_plan_failed"
    else:
        try:
            plan = await MealPlanGenerator(db).generate(
                user_id=user_id,
                store_id=user.preferred_store_id,
                duration_days=7,
                meals_per_day=3,
                preferences=user.dietary_preferences or {},
                household_size=user.household_size,
                target_kcal=user.daily_kcal_goal,
                create_shopping_list=automation.create_shopping_list,
                start_date=calendar_week_start(now_local.date())
                + timedelta(days=7),
            )
            automation.last_success_at = now_utc
            automation.last_plan_id = plan.id
            automation.last_error = None
            message = (
                "Plan na kolejny tydzień jest gotowy. Otwórz aplikację, "
                "aby go sprawdzić."
            )
            notification_type = "weekly_plan_ready"
        except Exception:
            await db.rollback()
            result = await db.execute(
                select(WeeklyPlanAutomation).where(
                    WeeklyPlanAutomation.user_id == user_id
                )
            )
            automation = result.scalar_one()
            logger.exception(
                "Automatyczny plan użytkownika %s nie powiódł się", user_id
            )
            automation.last_error = "Nie udało się utworzyć planu. Spróbujemy ponownie później."
            message = automation.last_error
            notification_type = "weekly_plan_failed"

    notification = Notification(
        user_id=user_id,
        notification_type=notification_type,
        message=message,
    )
    db.add_all([automation, notification])
    await db.commit()
    await db.refresh(notification)
    await push_for_notification(db, notification)
    return notification_type == "weekly_plan_ready"


async def process_due_weekly_plans(db: AsyncSession) -> int:
    now_local = datetime.now(WARSAW)
    result = await db.execute(
        select(WeeklyPlanAutomation, User)
        .join(User, User.id == WeeklyPlanAutomation.user_id)
        .where(WeeklyPlanAutomation.enabled.is_(True))
    )
    completed = 0
    for automation, user in result.all():
        if automation_is_due(automation, now_local):
            completed += int(
                await generate_for_user(db, automation, user, now_local=now_local)
            )
    return completed
