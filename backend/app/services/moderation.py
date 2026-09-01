"""Pomocnicze funkcje moderacji, współdzielone przez recipes.py i
recipe_comments.py — jedno miejsce, żeby filtrowanie zablokowanych
autorów działało identycznie wszędzie, zamiast kopiować to samo
zapytanie w kilku endpointach."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import BlockedUser


async def get_blocked_user_ids(db: AsyncSession, user_id: uuid.UUID) -> set[uuid.UUID]:
    """Zwraca zbiór ID użytkowników, których `user_id` zablokował —
    do wykluczenia z list przepisów/komentarzy widocznych temu
    użytkownikowi."""
    result = await db.execute(
        select(BlockedUser.blocked_user_id).where(BlockedUser.user_id == user_id)
    )
    return set(result.scalars().all())
