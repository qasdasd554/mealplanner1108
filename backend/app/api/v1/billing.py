"""Endpointy weryfikacji zakupów (subskrypcja Premium + pakiety punktów)
— obsługuje OBIE platformy: Google Play Billing (Android) i App Store
Server API (iOS), rozróżniane polem `platform` w żądaniu."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models.processed_apple_purchase import ProcessedApplePurchase
from app.models.user import User

router = APIRouter()

# Jedyne dwa poprawne identyfikatory subskrypcji — patrz przewodnik
# konfiguracji Google Play Billing / App Store Connect. Celowo trzymane
# tu jako stała, żeby nie akceptować dowolnego stringa jako "product_id"
# bez sensu.
_VALID_PRODUCT_IDS = {"premium_weekly", "premium_monthly", "premium_yearly"}


class VerifyPurchaseRequest(BaseModel):
    purchase_token: str = Field(..., min_length=1, max_length=1000)
    product_id: str = Field(..., max_length=100)
    # UWAGA (rozszerzenie iOS): domyślnie "android" dla wstecznej
    # kompatybilności — istniejący frontend Android jeszcze nie wysyła
    # tego pola jawnie. Dla iOS aplikacja MUSI wysłać "ios", i wtedy
    # `purchase_token` to w rzeczywistości ID transakcji StoreKit
    # (purchaseDetails.purchaseID), nie token w rozumieniu Google.
    platform: str = Field(default="android", pattern="^(android|ios)$")


class VerifyPurchaseResponse(BaseModel):
    is_premium: bool
    premium_expires_at: datetime | None
    premium_product_id: str | None


@router.post("/verify-purchase", response_model=VerifyPurchaseResponse)
async def verify_purchase(
    payload: VerifyPurchaseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Weryfikuje zakup subskrypcji Premium u Google/Apple i, jeśli
    prawdziwy i aktywny, nadaje użytkownikowi dostęp premium.

    WYWOŁYWANE PRZEZ APLIKACJĘ zaraz po tym, jak sklep zgłosi udany
    zakup (PurchaseDetails w strumieniu in_app_purchase) — to jedyny
    wiarygodny sposób nadania dostępu: nigdy nie ufamy samemu faktowi,
    że aplikacja "twierdzi", że zakup się udał, bez potwierdzenia u
    właściwego sklepu.
    """
    if payload.product_id not in _VALID_PRODUCT_IDS:
        raise HTTPException(status_code=400, detail="Nieznany identyfikator subskrypcji.")

    if payload.platform == "ios":
        from app.services.apple_app_store import PurchaseVerificationError, verify_apple_subscription

        try:
            result = await verify_apple_subscription(payload.purchase_token, payload.product_id)
        except PurchaseVerificationError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
    else:
        from app.services.google_play_billing import PurchaseVerificationError, verify_subscription_purchase

        try:
            result = await verify_subscription_purchase(payload.purchase_token, payload.product_id)
        except PurchaseVerificationError as exc:
            raise HTTPException(status_code=422, detail=str(exc))

    if not result["is_active"]:
        raise HTTPException(
            status_code=422,
            detail="Ten zakup nie jest aktywną subskrypcją (może być wygasła albo anulowana).",
        )

    current_user.is_premium = True
    current_user.premium_expires_at = result["expiry_time"]
    current_user.premium_product_id = result["product_id"] or payload.product_id
    current_user.premium_purchase_token = payload.purchase_token

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.post("/restore", response_model=VerifyPurchaseResponse)
async def restore_purchase(
    payload: VerifyPurchaseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Przywraca subskrypcję na nowym urządzeniu / po ponownej instalacji
    — identyczna logika co verify-purchase, osobny endpoint głównie dla
    czytelności po stronie aplikacji (przycisk "Przywróć zakupy")."""
    return await verify_purchase(payload, current_user, db)


# ══════════════════════════════════════════════════════════════════
# PUNKTY PREMIUM — zakup jednorazowy/KONSUMOWALNY (nie subskrypcja).
# 2 punkty = jedno zapytanie do AI. Pakiety: 10 pkt/10zł, 20 pkt/17zł,
# 50 pkt/40zł — ceny konfigurowane w Google Play Console / App Store
# Connect przy tworzeniu produktów, tutaj tylko mapujemy identyfikator
# produktu na liczbę PRZYZNAWANYCH punktów (musi zgadzać się z tym, co
# faktycznie skonfigurowano w konsoli danego sklepu).
# ══════════════════════════════════════════════════════════════════
_POINTS_PACKAGE_AMOUNTS = {
    "points_10": 10,
    "points_20": 20,
    "points_50": 50,
}


class VerifyPointsPurchaseResponse(BaseModel):
    premium_points: int


@router.post("/verify-points-purchase", response_model=VerifyPointsPurchaseResponse)
async def verify_points_purchase(
    payload: VerifyPurchaseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Weryfikuje zakup pakietu punktów u Google/Apple i, jeśli
    prawdziwy i jeszcze nierozliczony, dolicza punkty do konta.

    UWAGA (różnica między sklepami): Google ma wbudowany mechanizm
    "konsumowania" zakupu (patrz google_play_billing.py) — Apple NIE MA
    takiej koncepcji dla zakupów jednorazowych, więc dla iOS idempotencję
    (żeby nie przyznać punktów dwa razy za TĘ SAMĄ transakcję) zapewnia
    tabela ProcessedApplePurchase, sprawdzana/zapisywana tutaj."""
    if payload.product_id not in _POINTS_PACKAGE_AMOUNTS:
        raise HTTPException(status_code=400, detail="Nieznany pakiet punktów.")

    points_to_add = _POINTS_PACKAGE_AMOUNTS[payload.product_id]

    if payload.platform == "ios":
        from app.services.apple_app_store import PurchaseVerificationError, verify_apple_consumable

        try:
            result = await verify_apple_consumable(payload.purchase_token, payload.product_id)
        except PurchaseVerificationError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
        if not result["is_purchased"]:
            raise HTTPException(status_code=422, detail="Ten zakup nie został potwierdzony przez Apple.")

        # Sprawdzenie idempotencji — Apple nie ma "consumptionState", więc
        # to MY musimy pamiętać, które transakcje już rozliczyliśmy.
        existing = await db.execute(
            select(ProcessedApplePurchase).where(
                ProcessedApplePurchase.transaction_id == payload.purchase_token
            )
        )
        if existing.scalar_one_or_none() is not None:
            raise HTTPException(status_code=422, detail="Ten zakup został już wcześniej rozliczony.")

        current_user.premium_points += points_to_add
        db.add(ProcessedApplePurchase(transaction_id=payload.purchase_token))
        await db.commit()
        await db.refresh(current_user)
        return VerifyPointsPurchaseResponse(premium_points=current_user.premium_points)

    from app.services.google_play_billing import (
        PurchaseVerificationError,
        consume_purchase,
        verify_consumable_purchase,
    )

    try:
        result = await verify_consumable_purchase(payload.purchase_token, payload.product_id)
    except PurchaseVerificationError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    if not result["is_purchased"]:
        raise HTTPException(status_code=422, detail="Ten zakup nie został potwierdzony przez Google.")
    if result["is_consumed"]:
        # Ten SAM token już wcześniej doliczył punkty — nie przyznajemy
        # ich drugi raz (np. gdyby aplikacja wywołała ten endpoint
        # dwukrotnie dla tego samego zakupu).
        raise HTTPException(status_code=422, detail="Ten zakup został już wcześniej rozliczony.")

    current_user.premium_points += points_to_add
    await db.commit()

    try:
        await consume_purchase(payload.purchase_token, payload.product_id)
    except PurchaseVerificationError:
        # Punkty już przyznane (commit powyżej) — niepowodzenie samego
        # potwierdzenia u Google nie powinno cofać punktów, które
        # użytkownik już faktycznie kupił i opłacił. Zaloguj i idź dalej.
        import logging

        logging.getLogger(__name__).warning(
            "Nie udało się skonsumować zakupu %s dla usera %s (punkty już przyznane)",
            payload.purchase_token,
            current_user.id,
        )

    await db.refresh(current_user)
    return VerifyPointsPurchaseResponse(premium_points=current_user.premium_points)
