"""Endpointy promocji sklepowych.

Wcześniej ten router w ogóle nie istniał — mimo że model `Promotion` i
generator danych demonstracyjnych (`promo_scraper.py`) były już w kodzie,
nic nie wystawiało tych danych na zewnątrz. Aplikacja nie miała jak
zapytać "czy jest promocja na produkt X w sklepie Y".
"""

from datetime import date, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_admin, get_current_user, get_db
from app.models.promotion import Promotion
from app.models.store import Store
from app.models.product import Product, StoreProduct
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
    store_name: str = Query(..., description="Nazwa sklepu: Biedronka, Lidl albo Dino"),
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
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
    from app.services.promo_ai_scanner import PromoAIScanError, find_promotions_for_store

    store_result = await db.execute(select(Store).where(Store.name == store_name))
    store = store_result.scalar_one_or_none()
    if store is None:
        raise HTTPException(status_code=404, detail=f"Sklep '{store_name}' nie istnieje w bazie")

    products_result = await db.execute(select(Product.name))
    available_products = list(products_result.scalars().all())

    try:
        found = await find_promotions_for_store(store_name, available_products)
    except PromoAIScanError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    created = 0
    skipped_duplicates = 0
    for item in found:
        # Dopasuj do prawdziwego produktu w katalogu, żeby znać jego
        # AKTUALNĄ cenę regularną (nie ufamy ślepo cenie odczytanej z PDF-a
        # przez AI, jeśli mamy własne, bardziej wiarygodne dane).
        product_result = await db.execute(
            select(Product).where(Product.name.ilike(item["product_name"]))
        )
        product = product_result.scalar_one_or_none()
        if product is None:
            continue

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
        existing_result = await db.execute(
            select(Promotion.id).where(
                Promotion.product_name == product.name,
                Promotion.store_name == store_name,
                Promotion.review_status.in_(["pending", "approved"]),
                Promotion.valid_until >= date.today(),
            )
        )
        if existing_result.scalar_one_or_none() is not None:
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
        await _notify_admins_pending_promotions(db, store_name, created)

    return {
        "store_name": store_name,
        "found": len(found),
        "queued_for_review": created,
        "skipped_duplicates": skipped_duplicates,
    }


async def _notify_admins_pending_promotions(db: AsyncSession, store_name: str, count: int) -> None:
    """Powiadamia wszystkich administratorów o nowych promocjach
    czekających na akceptację."""
    from app.models.notification import Notification

    admins_result = await db.execute(select(User.id).where(User.role == "admin"))
    admin_ids = list(admins_result.scalars().all())
    if not admin_ids:
        return

    message = f"AI znalazło {count} nowych promocji w gazetce {store_name} — czekają na akceptację."
    for admin_id in admin_ids:
        db.add(Notification(user_id=admin_id, notification_type="promotion_pending_approval", message=message))
    await db.commit()


@router.get(
    "/pending",
    response_model=List[PromotionResponse],
    summary="Promocje czekające na akceptację (admin)",
)
async def list_pending_promotions(
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Zwraca wszystkie promocje znalezione przez AI, które jeszcze nie
    zostały zaakceptowane ani odrzucone."""
    result = await db.execute(
        select(Promotion)
        .where(Promotion.review_status == "pending")
        .order_by(Promotion.created_at.desc())
    )
    return result.scalars().all()


@router.put(
    "/{promotion_id}/approve",
    response_model=PromotionResponse,
    summary="Zaakceptuj promocję znalezioną przez AI (admin)",
)
async def approve_promotion(
    promotion_id: str,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
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
    promotion = await db.get(Promotion, promotion_id)
    if promotion is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono promocji")

    promotion.review_status = "approved"

    if promotion.promo_type == "price_cut":
        store_result = await db.execute(select(Store).where(Store.name == promotion.store_name))
        store = store_result.scalar_one_or_none()
        product_result = await db.execute(
            select(Product).where(Product.name == promotion.product_name)
        )
        product = product_result.scalar_one_or_none()
        if store and product:
            sp_result = await db.execute(
                select(StoreProduct).where(
                    StoreProduct.store_id == store.id, StoreProduct.product_id == product.id
                )
            )
            store_product = sp_result.scalar_one_or_none()
            if store_product:
                store_product.price = promotion.promo_price
                store_product.last_verified = date.today()

    await db.commit()
    await db.refresh(promotion)
    return promotion


@router.put(
    "/{promotion_id}/reject",
    response_model=PromotionResponse,
    summary="Odrzuć promocję znalezioną przez AI (admin)",
)
async def reject_promotion(
    promotion_id: str,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Odrzuca promocję — NIE wpływa na żadne ceny."""
    promotion = await db.get(Promotion, promotion_id)
    if promotion is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono promocji")

    promotion.review_status = "rejected"
    promotion.is_active = False
    await db.commit()
    await db.refresh(promotion)
    return promotion
