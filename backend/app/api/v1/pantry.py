"""Endpointy spiżarni — produkty, które użytkownik ma faktycznie w domu."""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import PantryItem, Product, User
from app.schemas.product import ProductResponse

router = APIRouter()


class PantryItemResponse(BaseModel):
    """Pojedynczy produkt w spiżarni, z pełnymi danymi produktu (nazwa,
    jednostka domyślna itd.) — żeby frontend nie musiał robić osobnego
    zapytania o każdy produkt."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product: ProductResponse
    quantity: float | None = None
    unit: str | None = None


class AddPantryItemsRequest(BaseModel):
    """Żądanie dodania jednego lub wielu produktów do spiżarni naraz —
    np. po odhaczeniu pozycji na liście zakupów jako kupionych."""

    product_ids: list[uuid.UUID]


class UpdatePantryItemQuantityRequest(BaseModel):
    """Żądanie ustawienia/zmiany ilości JUŻ istniejącego produktu w
    spiżarni — osobny, mały endpoint (nie część dodawania), bo to
    typowy przepływ: najpierw dodajesz produkt jednym dotknięciem,
    potem, jeśli chcesz, doprecyzowujesz ile go dokładnie masz."""

    quantity: float | None = None
    unit: str | None = None


@router.get("/", response_model=list[PantryItemResponse], summary="Twoja spiżarnia")
async def get_pantry(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PantryItem]:
    """Zwraca wszystkie produkty aktualnie zapisane w spiżarni
    użytkownika, posortowane od najnowiej dodanych."""
    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.user_id == current_user.id)
        .order_by(PantryItem.added_at.desc())
    )
    return list(result.scalars().all())


@router.post(
    "/",
    response_model=list[PantryItemResponse],
    status_code=201,
    summary="Dodaj produkty do spiżarni",
)
async def add_pantry_items(
    payload: AddPantryItemsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PantryItem]:
    """Dodaje jeden lub wiele produktów do spiżarni. Jeśli dany produkt
    JUŻ jest w spiżarni tego użytkownika (unikalność user_id+product_id
    w bazie), po prostu nie dubluje wpisu — cicho pomija, bez błędu,
    żeby dało się bezpiecznie wysłać całą listę zakupów naraz bez
    martwienia się, czy coś już tam jest."""
    if not payload.product_ids:
        raise HTTPException(status_code=400, detail="Podaj przynajmniej jeden produkt")

    # Sprawdź, które z podanych produktów faktycznie istnieją w katalogu.
    existing_products = await db.execute(
        select(Product.id).where(Product.id.in_(payload.product_ids))
    )
    valid_ids = set(existing_products.scalars().all())

    # Sprawdź, co JUŻ jest w spiżarni tego użytkownika, żeby nie
    # naruszyć unikalności (user_id, product_id) przy próbie dodania
    # czegoś, co już tam jest.
    already_have = await db.execute(
        select(PantryItem.product_id).where(
            PantryItem.user_id == current_user.id,
            PantryItem.product_id.in_(valid_ids),
        )
    )
    already_have_ids = set(already_have.scalars().all())

    to_add = valid_ids - already_have_ids
    for product_id in to_add:
        db.add(PantryItem(user_id=current_user.id, product_id=product_id))
    await db.commit()

    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.user_id == current_user.id)
        .order_by(PantryItem.added_at.desc())
    )
    return list(result.scalars().all())


@router.patch(
    "/{item_id}",
    response_model=PantryItemResponse,
    summary="Ustaw ilość produktu w spiżarni",
)
async def update_pantry_item_quantity(
    item_id: uuid.UUID,
    payload: UpdatePantryItemQuantityRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PantryItem:
    """Ustawia/zmienia ilość (i opcjonalnie jednostkę) już istniejącej
    pozycji w spiżarni. Ilość jest CELOWO opcjonalna i informacyjna —
    dopasowywanie przepisów sprawdza tylko OBECNOŚĆ produktu, nie ilość
    (patrz komentarz przy modelu PantryItem)."""
    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.id == item_id, PantryItem.user_id == current_user.id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(detail="Nie znaleziono tego produktu w Twojej spiżarni.")

    item.quantity = payload.quantity
    if payload.unit is not None:
        item.unit = payload.unit
    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204, summary="Usuń produkt ze spiżarni")
async def delete_pantry_item(
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(PantryItem).where(PantryItem.id == item_id, PantryItem.user_id == current_user.id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(detail="Nie znaleziono tego produktu w Twojej spiżarni.")

    await db.delete(item)
    await db.commit()
