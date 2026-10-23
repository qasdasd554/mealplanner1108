"""Endpointy sklepów i ich asortymentu."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.core.markets import account_country, requested_market, MarketCode
from app.db.session import get_db
from app.models import Product, Store, StoreDepartment, StoreProduct, User
from app.schemas.product import ProductResponse, StoreProductResponse
from app.schemas.store import StoreDepartmentResponse, StoreResponse
from app.services.regional_shopping import regional_pricing_date
from app.services.regional_store_catalogue import list_reviewed_store_products


# UWAGA (naprawa bezpieczeństwa): endpointy w tym pliku były CAŁKOWICIE
# otwarte — bez tokenu każdy mógł pobrać pełny katalog produktów, sklepów
# i cen (a więc też zeskrobać całą bazę jednym skryptem). To dane, na
# których opiera się aplikacja, i nie ma powodu udostępniać ich anonimowo.
# Router chroniony JEDNĄ zależnością na poziomie całego routera, zamiast
# dopisywania Depends do każdej funkcji z osobna — trudniej o pominięcie
# przy dodawaniu kolejnego endpointu w przyszłości.
router = APIRouter(dependencies=[Depends(get_current_user)])
@router.get(
    "/",
    response_model=list[StoreResponse],
    summary="Lista wszystkich sklepów",
)
async def list_stores(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    market: MarketCode | None = None,
) -> list[Store]:
    """Zwraca listę wszystkich dostępnych sieci handlowych."""
    result = await db.execute(
        select(Store)
        .where(Store.country_code == requested_market(current_user, market))
        .order_by(Store.name)
    )
    return list(result.scalars().all())


@router.get(
    "/{store_id}",
    response_model=StoreResponse,
    summary="Szczegóły sklepu z działami",
)
async def get_store(
    store_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    market: MarketCode | None = None,
) -> Store:
    """Zwraca szczegóły sklepu wraz z listą działów."""
    result = await db.execute(
        select(Store)
        .options(selectinload(Store.departments))
        .where(Store.id == store_id, Store.country_code == requested_market(current_user, market))
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
    current_user: User = Depends(get_current_user),
    market: MarketCode | None = None,
) -> list[StoreDepartment]:
    """Zwraca listę działów (np. nabiał, pieczywo) danego sklepu."""
    # Weryfikuj istnienie sklepu
    store_result = await db.execute(select(Store).where(
        Store.id == store_id, Store.country_code == requested_market(current_user, market)
    ))
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
    current_user: User = Depends(get_current_user),
    market: MarketCode | None = None,
) -> list[StoreProduct | StoreProductResponse]:
    """Zwraca produkty dostępne w danym sklepie z paginacją i filtrami.

    Obsługuje wyszukiwanie pełnotekstowe po nazwie produktu
    oraz filtrowanie po dziale sklepu. Odpowiedź zawiera cenę i
    dostępność produktu w tym konkretnym sklepie.
    """
    # Weryfikuj istnienie sklepu
    country = requested_market(current_user, market)
    store_result = await db.execute(select(Store).where(
        Store.id == store_id, Store.country_code == country
    ))
    if store_result.scalar_one_or_none() is None:
        raise NotFoundException(detail=f"Sklep o ID {store_id} nie został znaleziony")

    if country == "GB":
        return await list_reviewed_store_products(
            db, store_id, skip=skip, limit=limit, search=search,
            department_id=department_id, as_of=regional_pricing_date(),
        )

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
