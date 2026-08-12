"""Endpointy promocji sklepowych.

Wcześniej ten router w ogóle nie istniał — mimo że model `Promotion` i
generator danych demonstracyjnych (`promo_scraper.py`) były już w kodzie,
nic nie wystawiało tych danych na zewnątrz. Aplikacja nie miała jak
zapytać "czy jest promocja na produkt X w sklepie Y".
"""

from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models.promotion import Promotion
from app.models.user import User
from app.schemas.promotion import PromotionResponse

router = APIRouter()


@router.get("/", response_model=List[PromotionResponse])
async def list_promotions(
    store_name: Optional[str] = Query(
        None, description="Filtruj po nazwie sklepu, np. 'Biedronka'"
    ),
    search: Optional[str] = Query(
        None, description="Szukaj po nazwie produktu (dopasowanie częściowe)"
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Zwraca aktywne promocje ważne dziś, opcjonalnie filtrowane po
    sklepie i/lub nazwie produktu."""
    today = date.today()
    query = select(Promotion).where(
        Promotion.is_active.is_(True),
        Promotion.valid_from <= today,
        Promotion.valid_until >= today,
    )
    if store_name:
        query = query.where(Promotion.store_name.ilike(f"%{store_name}%"))
    if search:
        query = query.where(Promotion.product_name.ilike(f"%{search}%"))
    query = query.order_by(Promotion.store_name, Promotion.product_name)

    result = await db.execute(query)
    return result.scalars().all()


@router.get("/check", response_model=List[PromotionResponse])
async def check_promotion(
    product_name: str = Query(..., description="Nazwa produktu do sprawdzenia"),
    store_name: Optional[str] = Query(None, description="Ogranicz do konkretnego sklepu"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Sprawdza, czy dany produkt ma dziś aktywną promocję (w podanym
    sklepie albo we wszystkich). Zwraca listę pasujących promocji — pustą,
    jeśli żadnej nie znaleziono."""
    today = date.today()
    query = select(Promotion).where(
        Promotion.is_active.is_(True),
        Promotion.valid_from <= today,
        Promotion.valid_until >= today,
        Promotion.product_name.ilike(f"%{product_name}%"),
    )
    if store_name:
        query = query.where(Promotion.store_name.ilike(f"%{store_name}%"))

    result = await db.execute(query)
    return result.scalars().all()
