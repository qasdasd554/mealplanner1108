"""Endpointy produktów i zamienników."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import Product, ProductSubstitute, StoreProduct
from app.schemas.product import ProductResponse, StoreProductResponse, SubstituteResponse
from app.services import ProductSubstitutionService

router = APIRouter()


@router.get(
    "/",
    response_model=list[ProductResponse],
    summary="Lista produktów",
)
async def list_products(
    skip: int = Query(0, ge=0, description="Liczba rekordów do pominięcia"),
    limit: int = Query(50, ge=1, le=200, description="Maksymalna liczba wyników"),
    search: str | None = Query(None, description="Szukaj po nazwie produktu"),
    db: AsyncSession = Depends(get_db),
) -> list[Product]:
    """Zwraca listę wszystkich produktów z opcjonalnym wyszukiwaniem."""
    query = select(Product)

    if search:
        query = query.where(Product.name.ilike(f"%{search}%"))

    query = query.order_by(Product.name).offset(skip).limit(limit)

    result = await db.execute(query)
    return list(result.scalars().all())


@router.get(
    "/{product_id}",
    response_model=ProductResponse,
    summary="Szczegóły produktu",
)
async def get_product(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> Product:
    """Zwraca szczegóły produktu wraz z dostępnością w sklepach."""
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.store_products))
        .where(Product.id == product_id)
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise NotFoundException(
            detail=f"Produkt o ID {product_id} nie został znaleziony"
        )
    return product


@router.get(
    "/{product_id}/substitutes",
    response_model=list[SubstituteResponse],
    summary="Zamienniki produktu",
)
async def get_product_substitutes(
    product_id: UUID,
    store_id: UUID | None = Query(
        None, description="ID sklepu do filtrowania dostępnych zamienników"
    ),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Zwraca listę zamienników dla danego produktu.

    Opcjonalnie filtruje zamienniki po dostępności w wybranym sklepie.
    """
    # Sprawdź czy produkt istnieje
    product_result = await db.execute(
        select(Product).where(Product.id == product_id)
    )
    if product_result.scalar_one_or_none() is None:
        raise NotFoundException(
            detail=f"Produkt o ID {product_id} nie został znaleziony"
        )

    if store_id is None:
        result = await db.execute(
            select(Product)
            .join(ProductSubstitute, ProductSubstitute.substitute_product_id == Product.id)
            .where(ProductSubstitute.original_product_id == product_id)
        )
        return [
            {
                "id": p.id,
                "name": p.name,
                "brand": p.brand,
                "price": None,
                "similarity_score": None,
            }
            for p in result.scalars().all()
        ]

    substitution_service = ProductSubstitutionService(db)
    results = await substitution_service.find_substitutes(
        product_id=product_id, store_id=store_id, limit=10
    )
    if not results:
        # Brak predefiniowanych zamienników (tabela product_substitutes) —
        # użyj wyszukiwania po podobieństwie wartości odżywczych w tym samym
        # dziale sklepu, tak jak robi to automatyczna obsługa wycofania produktu.
        results = await substitution_service.auto_find_similar(
            product_id=product_id, store_id=store_id, limit=10
        )
    response_list = []
    for r in results:
        prod = r["product"]
        store_prod = r.get("store_product")
        kcal = None
        if prod.nutrition_per_100 and "kcal" in prod.nutrition_per_100:
            try:
                kcal = int(prod.nutrition_per_100["kcal"])
            except:
                pass
        response_list.append({
            "id": prod.id,
            "name": prod.name,
            "brand": prod.brand,
            "price": store_prod.price if store_prod else None,
            "kcal": kcal,
            "similarity_score": r.get("similarity_score")
        })
    return response_list
