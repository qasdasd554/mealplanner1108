"""Jedna nowa lista tygodniowo dla kont standardowych, bez limitu dla Premium."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.premium import is_premium_active
from app.models.shopping_list_creation import ShoppingListCreation
from app.models.user import User


def calendar_week_start(day: date | None = None) -> date:
    day = day or datetime.now(ZoneInfo("Europe/Warsaw")).date()
    return day - timedelta(days=day.weekday())


async def can_create_shopping_list(db: AsyncSession, *, user: User) -> bool:
    """Sprawdza limit, trzymając blokadę do końca bieżącej transakcji."""
    if is_premium_active(user):
        return True
    week = calendar_week_start()
    await db.execute(
        text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
        {"key": f"shopping-list:{user.id}:{week.isoformat()}"},
    )
    result = await db.execute(
        select(func.count(ShoppingListCreation.id)).where(
            ShoppingListCreation.user_id == user.id,
            ShoppingListCreation.week_start == week,
        )
    )
    return (result.scalar_one() or 0) < 1


async def record_shopping_list_creation(
    db: AsyncSession, *, user: User, shopping_list_id: UUID,
) -> None:
    """Sprawdza limit i zapisuje zdarzenie w tej samej transakcji co nową listę.

    Blokada transakcyjna chroni przed utworzeniem dwóch list jednocześnie
    (np. podwójne dotknięcie przycisku). Historia nie znika po usunięciu
    listy, więc darmowego limitu nie da się ominąć kasowaniem.
    """
    week = calendar_week_start()
    if not await can_create_shopping_list(db, user=user):
        raise HTTPException(
            status_code=403,
            detail=(
                "Konto standardowe może utworzyć jedną listę zakupów "
                "w tygodniu (poniedziałek–niedziela). Możesz nadal "
                "dodać produkty do istniejącej listy albo skorzystać z Premium."
            ),
        )

    db.add(ShoppingListCreation(
        user_id=user.id,
        shopping_list_id=shopping_list_id,
        week_start=week,
    ))
    await db.flush()
