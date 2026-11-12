"""Endpointy promocji sklepowych.

Wcześniej ten router w ogóle nie istniał — mimo że model `Promotion` i
generator danych demonstracyjnych (`promo_scraper.py`) były już w kodzie,
nic nie wystawiało tych danych na zewnątrz. Aplikacja nie miała jak
zapytać "czy jest promocja na produkt X w sklepie Y".
"""

import asyncio
import hashlib
import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_admin, get_current_user, get_db
from app.core.market_clock import market_today
from app.core.markets import account_country, requested_market, MARKET_CURRENCIES, MarketCode
from app.models.promotion import Promotion
from app.models.store import Store
from app.models.product import Product, StoreProduct
from app.models.user import User
from app.models.promotion_scan_job import PromotionScanJob
from app.schemas.promotion import PromotionResponse
from app.services.retailer_promotion_queue import (
    RETAILER_LEAFLETS,
    apply_retailer_promotion_price,
    restore_retailer_promotion_price,
    scan_retailer_leaflet,
)

SCAN_RESULT_REUSE = timedelta(minutes=10)
router = APIRouter()
logger = logging.getLogger(__name__)


def _require_scan_store(store_name: str, country: str) -> None:
    from app.services.promo_ai_scanner import _AGGREGATOR_SLUGS

    supported = store_name in _AGGREGATOR_SLUGS if country == "PL" else (country, store_name) in RETAILER_LEAFLETS
    if not supported:
        message = {
            "DE": "Für diesen Supermarkt ist kein Prospekt verfügbar.",
            "GB": "Leaflet scanning is unavailable for this shop.",
            "PL": "Ten sklep nie ma skonfigurowanego skanera gazetek.",
        }
        raise HTTPException(422, message[country])


def _scan_job_response(job: PromotionScanJob) -> dict:
    return {"id": str(job.id), "store_name": job.store_name, "country_code": job.country_code,
            "status": job.status, "result": job.result, "error": job.error}


@router.post("/ai-scan/jobs", status_code=202)
async def create_promotion_scan_job(
    store_name: str = Query(..., min_length=1, max_length=80),
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    country = requested_market(current_user, market)
    _require_scan_store(store_name, country)
    store = await db.scalar(select(Store.id).where(
        Store.name == store_name, Store.country_code == country, Store.currency_code == MARKET_CURRENCIES[country],
    ))
    if store is None:
        raise HTTPException(404, "Nie znaleziono sklepu.")
    # Jeden aktywny skan na sklep, także przy ponowieniu POST po utracie sieci.
    lock_key = int.from_bytes(hashlib.sha256(f"promotion-scan:{country}:{store_name}".encode()).digest()[:8], "big", signed=True)
    await db.execute(select(func.pg_advisory_xact_lock(lock_key)))
    job = await db.scalar(
        select(PromotionScanJob).where(
            PromotionScanJob.store_name == store_name,
            PromotionScanJob.country_code == country,
            PromotionScanJob.status.in_(["queued", "processing"]),
        ).order_by(PromotionScanJob.created_at).limit(1)
    )
    if job is None:
        recent = await db.scalar(select(PromotionScanJob).where(
            PromotionScanJob.store_name == store_name,
            PromotionScanJob.country_code == country,
            PromotionScanJob.status == "completed",
            PromotionScanJob.finished_at >= datetime.now(timezone.utc) - SCAN_RESULT_REUSE,
        ).order_by(PromotionScanJob.finished_at.desc()).limit(1))
        if recent is not None:
            response = {**_scan_job_response(recent), "reused": True}
            await db.commit()
            return response
        job = PromotionScanJob(user_id=current_user.id, store_name=store_name, country_code=country, status="queued", attempts=0)
        db.add(job)
    await db.commit()
    await db.refresh(job)
    return _scan_job_response(job)


@router.get("/ai-scan/jobs/active")
async def active_promotion_scan_jobs(
    current_user: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    result = await db.execute(select(PromotionScanJob).where(
        PromotionScanJob.country_code == requested_market(current_user, market),
        PromotionScanJob.status.in_(["queued", "processing"])
    ).order_by(PromotionScanJob.created_at).limit(10))
    return [_scan_job_response(job) for job in result.scalars()]


@router.get("/ai-scan/jobs/{job_id}")
async def get_promotion_scan_job(
    job_id: UUID, current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    job = await db.get(PromotionScanJob, job_id)
    if job is None or job.country_code != requested_market(current_user, market):
        raise HTTPException(404, "Nie znaleziono zadania skanowania.")
    return _scan_job_response(job)


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
    country = account_country(current_user)
    today = date.today() if country == "PL" else market_today(country)
    query = select(Promotion).where(
        Promotion.country_code == country,
        Promotion.review_status == "approved",
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
    country = account_country(current_user)
    today = date.today() if country == "PL" else market_today(country)
    query = select(Promotion).where(
        Promotion.country_code == country,
        Promotion.review_status == "approved",
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
    # UWAGA (naprawa poważnej luki bezpieczeństwa): ten endpoint wysyła
    # PRAWDZIWE zapytania HTTP do stron sklepów (Biedronka, Lidl, Dino)
    # i aktualizuje ceny WIDOCZNE DLA WSZYSTKICH użytkowników — to
    # kosztowna, potencjalnie ryzykowna operacja (może doprowadzić do
    # zablokowania adresu IP serwera przez te strony przy nadużyciu), a
    # mimo to wymagał tylko zwykłego zalogowania (get_current_user), nie
    # uprawnień administratora. Limit "1 wywołanie na 5 minut na
    # użytkownika" chronił przed nadużyciem przez JEDNEGO użytkownika,
    # ale nie przed setkami różnych kont wywołującymi to niezależnie.
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Uruchamia scraper cen natychmiast i czeka na wynik — do ręcznego
    testowania, żeby nie czekać do 12 godzin na kolejny automatyczny cykl.

    Limit: 1 wywołanie na 5 minut na użytkownika. Bez tego limitu
    zalogowany użytkownik mógłby w pętli wysyłać żądania, które robią
    PRAWDZIWE zapytania HTTP do stron Biedronki/Lidla/Dino — ryzyko
    zbanowania adresu IP serwera przez te strony, oprócz zwykłego
    obciążenia bazy danych.
    """
    from app.core.rate_limit import enforce_user_rate_limit, scraper_run_limiter

    enforce_user_rate_limit(scraper_run_limiter, current_user.id, "uruchomienie scrapera cen")

    from app.services.promo_scraper import scrape_and_update_prices

    summary = await scrape_and_update_prices(db)
    total_updated = sum(s.get("prices_updated", 0) for s in summary.values())
    return {"total_updated": total_updated, "summary": summary}


@router.post(
    "/ai-scan",
    summary="Skanuj internet w poszukiwaniu promocji przez AI (admin)",
)
async def trigger_ai_scan(
    store_name: str = Query(
        ...,
        description="Nazwa sklepu: Biedronka, Lidl, Dino albo Carrefour",
    ),
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    """Szuka aktualnej gazetki promocyjnej danego sklepu w internecie
    (przez niezależny serwis agregujący gazetki, nie bezpośrednio stronę
    sklepu — ta zwykle blokuje automatyczne zapytania) i rozpoznaje z niej
    promocje przez AI.

    Wynik trafia do kolejki OCZEKUJĄCEJ na akceptację — NIC nie
    aktualizuje realnych cen automatycznie. Admin przegląda i akceptuje
    (PUT /promotions/{id}/approve) albo odrzuca (PUT /promotions/{id}/reject)
    każdą znalezioną promocję osobno.

    Tylko administrator — to kosztowna operacja (pobiera duży plik PDF,
    wywołuje AI), więc celowo nie jest dostępna dla zwykłych użytkowników
    ani nawet kont Premium.
    """
    country = requested_market(current_user, market)
    _require_scan_store(store_name, country)
    return await _scan_and_queue_promotions(store_name, db, country=country)


async def _scan_and_queue_promotions(store_name: str, db: AsyncSession, *, country: str = "PL") -> dict:
    if country != "PL":
        _require_scan_store(store_name, country)
        result = await scan_retailer_leaflet(store_name, db, country=country)
        if result["queued_for_review"]:
            try:
                await asyncio.wait_for(
                    _notify_admins_pending_promotions(db, store_name, result["queued_for_review"], country=country),
                    timeout=15,
                )
            except Exception:
                logger.warning("Promocje %s zapisano, ale powiadomienie administratorów nie dotarło.", store_name)
        return result

    from app.services.promo_ai_scanner import PromoAIScanError, find_promotions_for_store

    store_result = await db.execute(select(Store).where(
        Store.name == store_name, Store.country_code == "PL", Store.currency_code == "PLN",
    ))
    store = store_result.scalar_one_or_none()
    if store is None:
        raise HTTPException(status_code=404, detail=f"Sklep '{store_name}' nie istnieje w bazie")

    products_result = await db.execute(
        select(Product.name).join(StoreProduct, StoreProduct.product_id == Product.id)
        .where(StoreProduct.store_id == store.id, Product.review_status == "approved")
        .distinct().order_by(Product.name).limit(2000)
    )
    available_products = list(products_result.scalars().all())
    # Nie trzymaj połączenia Neon przez kilka minut pobierania PDF i pracy AI.
    await db.commit()

    try:
        found = await find_promotions_for_store(store_name, available_products)
    except PromoAIScanError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    created = 0
    skipped_duplicates = 0
    seen_names = set()
    for item in found:
        # Dopasuj do prawdziwego produktu w katalogu, żeby znać jego
        # AKTUALNĄ cenę regularną (nie ufamy ślepo cenie odczytanej z PDF-a
        # przez AI, jeśli mamy własne, bardziej wiarygodne dane).
        product_result = await db.execute(
            select(Product).join(StoreProduct, StoreProduct.product_id == Product.id)
            .where(
                StoreProduct.store_id == store.id,
                Product.name.ilike(item["product_name"]),
                Product.review_status == "approved",
            )
            .order_by(Product.created_by_user_id.is_not(None), Product.created_at)
            .limit(1)
        )
        product = product_result.scalar_one_or_none()
        if product is None:
            continue
        normalized_name = product.name.strip().lower()
        if normalized_name in seen_names:
            skipped_duplicates += 1
            continue
        seen_names.add(normalized_name)

        # UWAGA (nowe): promo_description teraz zawiera WARUNEK promocji
        # (np. "Kup 2, zapłać za 1"), jeśli AI go znalazło — użytkownik
        # MUSI wiedzieć, że cena dotyczy zakupu przy spełnieniu warunku,
        # nie pojedynczej sztuki bez zobowiązań. Bez tego pole zostawało
        # generycznym "Znalezione przez AI...", co ukrywało ewentualne
        # ograniczenia przed użytkownikiem.
        condition = item.get("condition")
        if condition:
            description = f"{condition} — znalezione przez AI w gazetce {store_name}"
        else:
            description = f"Znalezione przez AI w gazetce {store_name}"

        # UWAGA (nowe): rozróżniamy PRZYCZYNĘ warunku, jeśli to możliwe —
        # karta lojalnościowa to inny rodzaj ograniczenia niż "kup 2,
        # trzeci gratis" (jedno wymaga posiadania konkretnej karty,
        # drugie kupna kilku sztuk), a model ma już PRZYGOTOWANE osobne
        # pole `requires_loyalty_card`, wcześniej nigdy nieustawiane.
        condition_lower = (condition or "").lower()
        requires_loyalty_card = any(
            kw in condition_lower for kw in ("kart", "lojalnościow", "zarejestrowan")
        )
        if requires_loyalty_card:
            promo_type = "loyalty_card"
        elif condition:
            promo_type = "multipack"
        else:
            promo_type = "price_cut"

        # UWAGA (nowe): używamy PRAWDZIWEJ daty ważności z gazetki, jeśli
        # AI ją znalazło i wygląda na sensowną (nie w przeszłości, nie
        # absurdalnie odległa — np. AI nie pomyliło formatu daty) —
        # wcześniej ZAWSZE używaliśmy sztywnych "+14 dni od dziś",
        # niezależnie od tego, co faktycznie było wydrukowane na
        # plakacie, więc promocja mogła zniknąć za wcześnie albo zbyt
        # późno względem rzeczywistości.
        extracted_valid_until = item.get("valid_until")
        if extracted_valid_until is not None and extracted_valid_until < date.today():
            continue
        if (
            extracted_valid_until
            and date.today() <= extracted_valid_until <= date.today() + timedelta(days=90)
        ):
            valid_until = extracted_valid_until
        else:
            valid_until = date.today() + timedelta(days=14)

        # UWAGA (naprawa): wcześniej KAŻDE uruchomienie skanu tworzyło
        # nową promocję dla znalezionego produktu, nawet jeśli identyczna
        # (ten sam produkt w tym samym sklepie, wciąż ważna) już istniała
        # w kolejce oczekujących ALBO była już zaakceptowana przez admina
        # wcześniej. Efekt: powtórne skanowanie tej samej, wciąż aktualnej
        # gazetki zaśmiecało kolejkę duplikatami do przejrzenia od nowa.
        # Odrzucone promocje CELOWO pomijamy w tym sprawdzeniu — jeśli
        # admin coś odrzucił, a AI przy kolejnym skanie znajdzie to
        # ponownie (może z innymi warunkami), warto dać mu szansę
        # spojrzeć jeszcze raz.
        # UWAGA (naprawa błędu): wcześniejsze porównanie było DOKŁADNE
        # (rozróżniało wielkość liter i białe znaki) — AI przy kolejnym
        # skanowaniu tej samej gazetki może wyodrębnić nazwę produktu
        # albo sklepu w lekko innej formie niż poprzednio (np. spacja na
        # końcu, inna wielkość liter), co całkowicie omijało sprawdzenie
        # duplikatu, mimo że to faktycznie ten sam produkt w tym samym
        # sklepie. Porównujemy teraz bez rozróżniania wielkości liter i
        # po przycięciu białych znaków z obu stron.
        existing_result = await db.execute(
            select(Promotion.id).where(
                Promotion.country_code == "PL",
                func.lower(func.trim(Promotion.product_name)) == product.name.strip().lower(),
                func.lower(func.trim(Promotion.store_name)) == store_name.strip().lower(),
                Promotion.review_status.in_(["pending", "approved"]),
                Promotion.valid_until >= date.today(),
            )
        )
        if existing_result.scalars().first() is not None:
            skipped_duplicates += 1
            continue

        db.add(
            Promotion(
                product_name=product.name,
                store_name=store_name,
                regular_price=item["regular_price"],
                promo_price=item["promo_price"],
                # UWAGA (naprawa): wcześniej ZAWSZE "price_cut", niezależnie
                # od tego, czy AI znalazło warunek (np. "2+1" albo karta
                # lojalnościowa). To ważne, bo promo_type decyduje PÓŹNIEJ
                # (patrz approve_promotion), czy zaakceptowanie promocji
                # może bezpiecznie nadpisać CENĘ BAZOWĄ produktu w
                # katalogu — dla promocji warunkowej NIE WOLNO tego robić,
                # bo promo_price to nie jest cena za pojedynczą sztukę
                # bez zobowiązań.
                promo_type=promo_type,
                requires_loyalty_card=requires_loyalty_card,
                promo_description=description,
                source="ai_scan",
                valid_from=date.today(),
                valid_until=valid_until,
                is_active=True,
                review_status="pending",
            )
        )
        created += 1
    await db.commit()

    if created > 0:
        try:
            await asyncio.wait_for(_notify_admins_pending_promotions(db, store_name, created), timeout=15)
        except Exception:
            logger.warning("Promocje zapisano, ale powiadomienie administratorów nie dotarło.")

    return {
        "store_name": store_name,
        "found": len(found),
        "queued_for_review": created,
        "skipped_duplicates": skipped_duplicates,
    }


async def _notify_admins_pending_promotions(
    db: AsyncSession, store_name: str, count: int, *, country: str = "PL",
) -> None:
    """Powiadamia wszystkich administratorów o nowych promocjach
    czekających na akceptację."""
    from app.services.admin_notifications import notify_admins_pending_review

    message = f"AI znalazło {count} nowych promocji w gazetce {store_name} — czekają na akceptację."
    english = f"AI found {count} new promotions in the {store_name} leaflet — approval required."
    if country != "PL":
        message = f"W gazetce {store_name} znaleziono {count} promocji. Czekają na akceptację."
        english = f"{count} offers from the {store_name} leaflet are awaiting approval."
    await notify_admins_pending_review(
        db,
        notification_type="promotion_pending_approval",
        message=message,
        english_message=english,
    )


@router.get(
    "/pending",
    response_model=List[PromotionResponse],
    summary="Promocje czekające na akceptację (admin)",
)
async def list_pending_promotions(
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    """Zwraca wszystkie promocje znalezione przez AI, które jeszcze nie
    zostały zaakceptowane ani odrzucone."""
    country = requested_market(current_user, market)
    query = select(Promotion).where(Promotion.country_code == country, Promotion.review_status == "pending")
    if country != "PL":
        query = query.where(Promotion.valid_until >= market_today(country))
    result = await db.execute(query.order_by(Promotion.created_at.desc()))
    return result.scalars().all()


@router.put(
    "/{promotion_id}/approve",
    response_model=PromotionResponse,
    summary="Zaakceptuj promocję znalezioną przez AI (admin)",
)
async def approve_promotion(
    promotion_id: UUID,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    """Akceptuje promocję — od tego momentu WPŁYWA na cenę widoczną
    w aplikacji (aktualizuje StoreProduct.price dla dopasowanego produktu
    w danym sklepie, jeśli taki wiersz istnieje).

    UWAGA (naprawa poważnego błędu): promo_price przy promocjach
    WARUNKOWYCH (promo_type="multipack", np. "kup 2, zapłać za 1") to
    NIE jest cena za pojedynczą sztukę — to efektywna cena PRZY SPEŁNIENIU
    warunku. Nadpisanie nią StoreProduct.price (czyli "ile kosztuje 1
    sztuka tego produktu" używane w KAŻDYM innym miejscu aplikacji: listy
    zakupów, budżety planów, porównania cen) zaniżałoby realny koszt dla
    każdego, kto nie kupuje wymaganej liczby sztuk. Dla takich promocji
    zatwierdzamy samą promocję (widoczną z opisem warunku), ale NIE
    ruszamy ceny bazowej w katalogu.
    """
    country = requested_market(current_user, market)
    promotion = await db.get(Promotion, promotion_id, with_for_update=True)
    if promotion is None or promotion.country_code != country:
        raise HTTPException(status_code=404, detail="Nie znaleziono promocji")

    if country != "PL":
        today = market_today(country)
        if not promotion.valid_from <= today <= promotion.valid_until or not promotion.is_active:
            message = "Dieses Angebot ist nicht mehr gültig." if country == "DE" else "This offer is no longer valid."
            raise HTTPException(409, message)
        if promotion.review_status == "pending":
            await apply_retailer_promotion_price(db, promotion)
            promotion.review_status = "approved"
        await db.commit()
        await db.refresh(promotion)
        return promotion

    promotion.review_status = "approved"

    if promotion.promo_type == "price_cut":
        store_result = await db.execute(select(Store).where(
            Store.name == promotion.store_name, Store.country_code == "PL", Store.currency_code == "PLN",
        ))
        store = store_result.scalar_one_or_none()
        if store:
            sp_result = await db.execute(
                select(StoreProduct).join(Product, Product.id == StoreProduct.product_id)
                .where(StoreProduct.store_id == store.id,
                       Product.name == promotion.product_name)
                .order_by(Product.created_by_user_id.is_not(None), Product.created_at)
                .limit(1)
            )
            store_product = sp_result.scalar_one_or_none()
            if store_product:
                store_product.price = promotion.promo_price
                store_product.last_verified = date.today()
                # Znacznik potrzebny, żeby po wygaśnięciu promocji dało się
                # cofnąć cenę do regularnej — patrz
                # app/services/promotion_expiry.py.
                promotion.price_applied = True

    await db.commit()
    await db.refresh(promotion)
    return promotion


@router.put(
    "/{promotion_id}/reject",
    response_model=PromotionResponse,
    summary="Odrzuć promocję znalezioną przez AI (admin)",
)
async def reject_promotion(
    promotion_id: UUID,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
):
    country = requested_market(current_user, market)
    promotion = await db.get(Promotion, promotion_id, with_for_update=True)
    if promotion is None or promotion.country_code != country:
        raise HTTPException(status_code=404, detail="Nie znaleziono promocji")

    if country != "PL" and promotion.price_applied:
        await restore_retailer_promotion_price(db, promotion)
        promotion.price_applied = False
    promotion.review_status = "rejected"
    promotion.is_active = False
    await db.commit()
    await db.refresh(promotion)
    return promotion
