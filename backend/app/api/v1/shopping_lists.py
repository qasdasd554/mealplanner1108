"""Endpointy list zakupów — przeglądanie, oznaczanie, zamienniki."""

from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import (
    MealPlan,
    ShoppingList,
    ShoppingListItem,
    StoreDepartment,
    StoreProduct,
    User,
)
from app.schemas.shopping_list import ShoppingListItemResponse, ShoppingListResponse
from app.services import ProductSubstitutionService

router = APIRouter()


class SubstituteRequest(BaseModel):
    """Schemat żądania zamiany produktu na liście zakupów."""

    model_config = ConfigDict(from_attributes=True)

    substitute_product_id: UUID


class ShoppingListSummary(BaseModel):
    """Podsumowanie listy zakupów — łączna cena, postęp zakupów."""

    model_config = ConfigDict(from_attributes=True)

    total_items: int
    checked_items: int
    unchecked_items: int
    total_estimated_price: float
    checked_price: float
    remaining_price: float
    completion_percentage: float


async def _get_shopping_list_or_404(
    list_id: UUID,
    current_user: User,
    db: AsyncSession,
) -> ShoppingList:
    """Pobiera listę zakupów z weryfikacją właściciela.

    Raises:
        NotFoundException: jeśli lista nie istnieje lub nie należy do użytkownika.
    """
    result = await db.execute(
        select(ShoppingList)
        .join(MealPlan, ShoppingList.meal_plan_id == MealPlan.id)
        .options(
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(
            ShoppingList.meal_plan_id == list_id,
            MealPlan.user_id == current_user.id,
        )
    )
    shopping_list = result.scalar_one_or_none()
    if shopping_list is None:
        raise NotFoundException(
            detail=f"Lista zakupów o ID {list_id} nie została znaleziona"
        )
    return shopping_list


@router.get(
    "/{list_id}",
    response_model=ShoppingListResponse,
    summary="Pobierz listę zakupów pogrupowaną po działach",
)
async def get_shopping_list(
    list_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingList:
    """Zwraca listę zakupów z pozycjami pogrupowanymi po działach sklepu."""
    return await _get_shopping_list_or_404(list_id, current_user, db)


@router.put(
    "/{list_id}/items/{item_id}/check",
    response_model=ShoppingListItemResponse,
    summary="Zaznacz/odznacz pozycję na liście",
)
async def toggle_item_checked(
    list_id: UUID,
    item_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListItem:
    """Przełącza status oznaczenia pozycji na liście zakupów (kupione/niekupione)."""
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    result = await db.execute(
        select(ShoppingListItem)
        .options(
            selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingListItem.department),
            selectinload(ShoppingListItem.substituted_for_product),
        )
        .where(
            ShoppingListItem.id == item_id,
            ShoppingListItem.shopping_list_id == shopping_list.id,
        )
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(
            detail=f"Pozycja o ID {item_id} nie została znaleziona na liście"
        )

    item.is_checked = not item.is_checked
    db.add(item)
    await db.commit()
    
    # Przeładuj obiekt z relacjami
    result = await db.execute(
        select(ShoppingListItem)
        .options(
            selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingListItem.department),
            selectinload(ShoppingListItem.substituted_for_product),
        )
        .execution_options(populate_existing=True)
        .where(ShoppingListItem.id == item_id)
    )
    return result.scalar_one()


@router.put(
    "/{list_id}/items/{item_id}/substitute",
    response_model=ShoppingListItemResponse,
    summary="Zamień produkt na liście zakupów",
)
async def substitute_item(
    list_id: UUID,
    item_id: UUID,
    payload: SubstituteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListItem:
    """Zamienia produkt na liście zakupów na wskazany zamiennik.

    Aktualizuje produkt, cenę jednostkową oraz dział sklepu
    na podstawie danych zamiennika.
    """
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    # Znajdź pozycję
    result = await db.execute(
        select(ShoppingListItem)
        .options(selectinload(ShoppingListItem.store_product))
        .where(
            ShoppingListItem.id == item_id,
            ShoppingListItem.shopping_list_id == shopping_list.id,
        )
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(
            detail=f"Pozycja o ID {item_id} nie została znaleziona na liście"
        )

    substitution_service = ProductSubstitutionService(db)
    updated_item = await substitution_service.substitute_shopping_list_item(
        item=item,
        substitute_product_id=payload.substitute_product_id,
        store_id=shopping_list.store_id,
    )

    await db.commit()
    
    # Przeładuj obiekt z relacjami
    result = await db.execute(
        select(ShoppingListItem)
        .options(
            selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingListItem.department),
            selectinload(ShoppingListItem.substituted_for_product),
        )
        .execution_options(populate_existing=True)
        .where(ShoppingListItem.id == item_id)
    )
    return result.scalar_one()


@router.get(
    "/{list_id}/summary",
    response_model=ShoppingListSummary,
    summary="Podsumowanie listy zakupów",
)
async def get_shopping_list_summary(
    list_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListSummary:
    """Zwraca podsumowanie listy zakupów: łączną cenę, postęp zakupów, itp."""
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    items = shopping_list.items or []
    total_items = len(items)
    checked_items = sum(1 for i in items if i.is_checked)
    unchecked_items = total_items - checked_items

    total_price = sum(float(i.estimated_price or 0) for i in items)
    checked_price = sum(float(i.estimated_price or 0) for i in items if i.is_checked)
    remaining_price = total_price - checked_price

    completion = (checked_items / total_items * 100) if total_items > 0 else 0.0

    return ShoppingListSummary(
        total_items=total_items,
        checked_items=checked_items,
        unchecked_items=unchecked_items,
        total_estimated_price=round(total_price, 2),
        checked_price=round(checked_price, 2),
        remaining_price=round(remaining_price, 2),
        completion_percentage=round(completion, 1),
    )
