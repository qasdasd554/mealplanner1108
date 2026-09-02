"""Walidacja nazwy wyświetlanej (pseudonimu) — wspólna dla rejestracji
e-mailem, logowania Google/Apple i zmiany nicku w profilu, żeby zasady
były identyczne we WSZYSTKICH ścieżkach zakładania/edycji konta.

Nick jest widoczny publicznie (autor przepisu, autor komentarza, tablica
wyników konkursu), więc dwie osoby o tym samym nicku uniemożliwiałyby
odróżnienie, kto co napisał — stąd wymóg unikalności.
"""

from __future__ import annotations

import uuid

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User

MAX_DISPLAY_NAME_LENGTH = 200
MIN_DISPLAY_NAME_LENGTH = 2


async def validate_display_name(
    db: AsyncSession,
    display_name: str,
    *,
    exclude_user_id: uuid.UUID | None = None,
) -> str:
    """Sprawdza długość i unikalność nicku. Zwraca oczyszczoną wartość.

    `exclude_user_id` pomija konto o podanym ID przy sprawdzaniu zajętości
    — potrzebne przy EDYCJI własnego profilu, żeby zapisanie tego samego
    nicku bez zmian nie kończyło się błędem "nazwa zajęta" (przez samego
    siebie).

    Raises:
        HTTPException 400: nick za krótki, za długi albo już zajęty.
    """
    display_name = display_name.strip()

    if len(display_name) < MIN_DISPLAY_NAME_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Nazwa użytkownika musi mieć co najmniej {MIN_DISPLAY_NAME_LENGTH} znaki",
        )
    if len(display_name) > MAX_DISPLAY_NAME_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Nazwa użytkownika jest za długa (maks. {MAX_DISPLAY_NAME_LENGTH} znaków)",
        )

    # Porównanie bez rozróżniania wielkości liter — "Kucharz" i "kucharz"
    # to wizualnie ta sama nazwa i pozwolenie na oba byłoby mylące
    # (dokładnie ten sam problem, który wcześniej naprawiono dla e-maili).
    query = select(User).where(func.lower(User.display_name) == display_name.lower())
    if exclude_user_id is not None:
        query = query.where(User.id != exclude_user_id)

    result = await db.execute(query)
    if result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="Ta nazwa użytkownika jest już zajęta")

    return display_name


async def generate_unique_display_name(db: AsyncSession, base_name: str) -> str:
    """Zwraca `base_name`, a jeśli jest zajęty — z doklejonym numerem
    ("Anna", "Anna2", "Anna3"...).

    Używane WYŁĄCZNIE przy logowaniu przez Google/Apple, gdzie nazwa
    przychodzi z zewnątrz i użytkownik nie ma jak jej w tym momencie
    poprawić — odrzucenie logowania błędem "nazwa zajęta" zablokowałoby
    mu założenie konta. Przy zwykłej rejestracji i zmianie nicku
    świadomie tego NIE robimy: tam użytkownik sam wpisuje nazwę i
    powinien dostać jasny komunikat, że jest zajęta.
    """
    base_name = (base_name or "").strip()[:MAX_DISPLAY_NAME_LENGTH] or "Użytkownik"

    result = await db.execute(
        select(User).where(func.lower(User.display_name) == base_name.lower())
    )
    if result.scalar_one_or_none() is None:
        return base_name

    for suffix in range(2, 1000):
        candidate = f"{base_name}{suffix}"
        result = await db.execute(
            select(User).where(func.lower(User.display_name) == candidate.lower())
        )
        if result.scalar_one_or_none() is None:
            return candidate

    # Skrajnie nieprawdopodobne (999 kont o tej samej nazwie bazowej) —
    # UUID gwarantuje zakończenie pętli zamiast zwrócenia duplikatu.
    return f"{base_name}{uuid.uuid4().hex[:6]}"
