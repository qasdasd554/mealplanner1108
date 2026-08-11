"""Endpointy zarządzania profilem użytkownika."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import Allergen, User, UserAllergen
from app.schemas.user import UserResponse

router = APIRouter()


class UserProfileUpdate(BaseModel):
    """Schemat aktualizacji profilu użytkownika."""

    model_config = ConfigDict(from_attributes=True)

    display_name: str | None = None
    preferred_store_id: UUID | None = None
    dietary_preferences: dict | None = None
    household_size: int | None = None


class AllergenIdsUpdate(BaseModel):
    """Lista identyfikatorów alergenów do przypisania użytkownikowi."""

    model_config = ConfigDict(from_attributes=True)

    allergen_ids: list[str]


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Pobierz profil bieżącego użytkownika",
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> User:
    """Zwraca profil zalogowanego użytkownika."""
    return current_user


@router.put(
    "/me",
    response_model=UserResponse,
    summary="Zaktualizuj profil użytkownika",
)
async def update_me(
    payload: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Aktualizuje pola profilu bieżącego użytkownika.

    Pomija pola o wartości ``None`` — aktualizowane są tylko jawnie przekazane wartości.
    """
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.put(
    "/me/allergens",
    response_model=UserResponse,
    summary="Zaktualizuj alergeny użytkownika",
)
async def update_my_allergens(
    payload: AllergenIdsUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Zastępuje listę alergenów użytkownika nowym zestawem.

    Operacja jest atomowa: usuwa wszystkie istniejące powiązania
    i tworzy nowe na podstawie przekazanej listy ``allergen_ids``.
    Akceptuje zarówno UUID jak i nazwy alergenów (np. 'gluten', 'laktoza').
    """
    # Usuń istniejące powiązania
    await db.execute(
        delete(UserAllergen).where(UserAllergen.user_id == current_user.id)
    )

    if payload.allergen_ids:
        # Sprawdź czy to UUIDs czy nazwy
        resolved_ids = []
        names_to_lookup = []
        for aid in payload.allergen_ids:
            try:
                resolved_ids.append(UUID(aid))
            except (ValueError, AttributeError):
                names_to_lookup.append(aid)

        # Wyszukaj alergeny po nazwie
        if names_to_lookup:
            result = await db.execute(
                select(Allergen).where(Allergen.name.in_(names_to_lookup))
            )
            found = result.scalars().all()
            resolved_ids.extend([a.id for a in found])

        # Zweryfikuj istnienie alergenów po UUID
        if resolved_ids:
            result = await db.execute(
                select(Allergen).where(Allergen.id.in_(resolved_ids))
            )
            existing_allergens = result.scalars().all()
            existing_ids = {a.id for a in existing_allergens}

            for allergen_id in resolved_ids:
                if allergen_id in existing_ids:
                    db.add(UserAllergen(user_id=current_user.id, allergen_id=allergen_id))

    await db.commit()

    # Odśwież użytkownika z relacjami
    result = await db.execute(
        select(User)
        .options(selectinload(User.allergens))
        .where(User.id == current_user.id)
    )
    user = result.scalar_one()
    return user

