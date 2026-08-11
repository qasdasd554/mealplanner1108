"""Endpointy sklepów i ich asortymentu."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import Product, Store, StoreDepartment, StoreProduct
from app.schemas.product import ProductResponse, StoreProductResponse
from app.schemas.store import StoreDepartmentResponse, StoreResponse

router = APIRouter()


@router.get(
    "/",
    response_model=list[StoreResponse],
    summary="Lista wszystkich sklepów",
)
async def list_stores(
    db: AsyncSession = Depends(get_db),
) -> list[Store]:
    """Zwraca listę wszystkich dostępnych sieci handlowych."""
    result = await db.execute(select(Store).order_by(Store.name))
    return list(result.scalars().all())


@router.get(
    "/{store_id}",
    response_model=StoreResponse,
    summary="Szczegóły sklepu z działami",
)
async def get_store(
    store_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> Store:
    """Zwraca szczegóły sklepu wraz z listą działów."""
    result = await db.execute(
        select(Store)
        .options(selectinload(Store.departments))
        .where(Store.id == store_id)
    )
    store = result.scalar_one_or_none()
    if store is None:
        raise NotFoundException(detail=f"Sklep o ID {store_id} nie został znaleziony")
    return store


@router.get(
    "/{store_id}/departments",
    response_model=list[StoreDepartmentResponse],
    summary="Działy sklepu",
)
async def list_store_departments(
    store_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> list[StoreDepartment]:
    """Zwraca listę działów (np. nabiał, pieczywo) danego sklepu."""
    # Weryfikuj istnienie sklepu
    store_result = await db.execute(select(Store).where(Store.id == store_id))
    if store_result.scalar_one_or_none() is None:
        raise NotFoundException(detail=f"Sklep o ID {store_id} nie został znaleziony")

    result = await db.execute(
        select(StoreDepartment)
        .where(StoreDepartment.store_id == store_id)
        .order_by(StoreDepartment.sort_order, StoreDepartment.name)
    )
    return list(result.scalars().all())


@router.get(
    "/{store_id}/products",
    response_model=list[StoreProductResponse],
    summary="Produkty dostępne w sklepie",
)
async def list_store_products(
    store_id: UUID,
    skip: int = Query(0, ge=0, description="Liczba rekordów do pominięcia"),
    limit: int = Query(50, ge=1, le=200, description="Maksymalna liczba wyników"),
    search: str | None = Query(None, description="Szukaj po nazwie produktu"),
    department_id: UUID | None = Query(None, description="Filtruj po dziale sklepu"),
    db: AsyncSession = Depends(get_db),
) -> list[StoreProduct]:
    """Zwraca produkty dostępne w danym sklepie z paginacją i filtrami.

    Obsługuje wyszukiwanie pełnotekstowe po nazwie produktu
    oraz filtrowanie po dziale sklepu. Odpowiedź zawiera cenę i
    dostępność produktu w tym konkretnym sklepie.
    """
    # Weryfikuj istnienie sklepu
    store_result = await db.execute(select(Store).where(Store.id == store_id))
    if store_result.scalar_one_or_none() is None:
        raise NotFoundException(detail=f"Sklep o ID {store_id} nie został znaleziony")

    query = (
        select(StoreProduct)
        .join(Product, StoreProduct.product_id == Product.id)
        .where(StoreProduct.store_id == store_id)
        .where(StoreProduct.is_available == True)  # noqa: E712
        .options(selectinload(StoreProduct.product))
    )

    if department_id is not None:
        query = query.where(StoreProduct.department_id == department_id)

    if search:
        query = query.where(Product.name.ilike(f"%{search}%"))

    query = query.order_by(Product.name).offset(skip).limit(limit)

    result = await db.execute(query)
    return list(result.scalars().all())
