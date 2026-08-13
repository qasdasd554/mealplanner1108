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


@router.get("/scraper-status", summary="Status automatycznej aktualizacji cen")
async def scraper_status(current_user: User = Depends(get_current_user)):
    """Pokazuje, kiedy scraper cen ostatnio się uruchomił i co znalazł —
    bez konieczności grzebania w logach Render.

    `total_updated: 0` (przy braku błędu) najczęściej oznacza, że sklepy
    (zwłaszcza Lidl, który celowo wstawia ceny jako obrazki) nie
    udostępniły w tym przebiegu danych, które dałoby się bezpiecznie
    odczytać — to nie jest błąd tego endpointu, tylko realne ograniczenie
    tych konkretnych stron. `last_run_at: null` oznacza, że scraper jeszcze
    w ogóle się nie uruchomił (np. usługa dopiero wystartowała — pierwszy
    przebieg następuje ok. 10 sekund po starcie backendu).
    """
    from app.services.promo_scraper import get_last_run_status

    return get_last_run_status()


@router.post("/scraper-run", summary="Uruchom aktualizację cen teraz (bez czekania na cykl)")
async def trigger_scraper_run(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Uruchamia scraper cen natychmiast i czeka na wynik — do ręcznego
    testowania, żeby nie czekać do 12 godzin na kolejny automatyczny cykl.

    Zwraca to samo podsumowanie co widoczne potem w `/scraper-status`.
    """
    from app.services.promo_scraper import scrape_and_update_prices

    summary = await scrape_and_update_prices(db)
    total_updated = sum(s.get("prices_updated", 0) for s in summary.values())
    return {"total_updated": total_updated, "summary": summary}
