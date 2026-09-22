"""Tygodniowy limit tworzenia planów dla kont standardowych."""

from __future__ import annotations

from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.premium import is_premium_active
from app.models.meal_plan_creation import MealPlanCreation
from app.models.user import User
from app.services.shopping_list_quota import calendar_week_start


async def can_create_meal_plan(db: AsyncSession, *, user: User) -> bool:
    """Sprawdza limit, blokując dany tydzień do końca transakcji."""
    if is_premium_active(user):
        return True
    week = calendar_week_start()
    await db.execute(
        text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
        {"key": f"meal-plan:{user.id}:{week.isoformat()}"},
    )
    result = await db.execute(
        select(func.count(MealPlanCreation.id)).where(
            MealPlanCreation.user_id == user.id,
            MealPlanCreation.week_start == week,
        )
    )
    return (result.scalar_one() or 0) < 1


async def ensure_can_create_meal_plan(db: AsyncSession, *, user: User) -> None:
    if not await can_create_meal_plan(db, user=user):
        raise HTTPException(
            status_code=403,
            detail=(
                "Konto standardowe może wygenerować jeden plan posiłków "
                "w tygodniu (poniedziałek–niedziela). Usunięcie planu "
                "nie odnawia limitu. Premium pozwala tworzyć plany bez limitu."
            ),
        )


async def record_meal_plan_creation(
    db: AsyncSession, *, user: User, meal_plan_id: UUID,
) -> None:
    """Rejestruje plan w tej samej transakcji co sam plan i lista zakupów."""
    await ensure_can_create_meal_plan(db, user=user)
    db.add(MealPlanCreation(
        user_id=user.id,
        meal_plan_id=meal_plan_id,
        week_start=calendar_week_start(),
    ))
    await db.flush()
