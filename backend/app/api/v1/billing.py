"""Endpointy weryfikacji zakupów (subskrypcja Premium + pakiety punktów)
— obsługuje OBIE platformy: Google Play Billing (Android) i App Store
Server API (iOS), rozróżniane polem `platform` w żądaniu."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.core.language import account_text
from app.models.processed_apple_purchase import ProcessedApplePurchase
from app.models.points_purchase import PointsPurchase
from app.models.user import User

router = APIRouter()

# Jedyne dwa poprawne identyfikatory subskrypcji — patrz przewodnik
# konfiguracji Google Play Billing / App Store Connect. Celowo trzymane
# tu jako stała, żeby nie akceptować dowolnego stringa jako "product_id"
# bez sensu.
_VALID_PRODUCT_IDS = {"premium_weekly_v2", "premium_monthly", "premium_yearly"}


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
    premium_status: str | None = None
    premium_auto_renew_enabled: bool | None = None


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
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nieznany identyfikator subskrypcji.", "Unknown subscription product."))

    from app.core.premium import is_premium_active

    already_had_premium = is_premium_active(current_user)

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
            detail=account_text(current_user,
                "Ten zakup nie jest aktywną subskrypcją (może być wygasła albo anulowana).",
                "This purchase is not an active subscription (it may have expired or been cancelled)."),
        )

    current_user.is_premium = True
    current_user.premium_expires_at = result["expiry_time"]
    current_user.premium_product_id = result["product_id"] or payload.product_id
    current_user.premium_purchase_token = result.get("purchase_token") or payload.purchase_token
    current_user.premium_platform = payload.platform
    current_user.premium_last_verified_at = datetime.now(timezone.utc)
    current_user.premium_status = result.get("subscription_status")
    current_user.premium_auto_renew_enabled = result.get("auto_renew_enabled")

    await db.commit()
    await db.refresh(current_user)

    if not already_had_premium:
        await _notify(
            db,
            current_user.id,
            "Premium aktywne! Masz teraz dostęp do wszystkich funkcji aplikacji.",
            english_message="Premium is active! You now have access to all app features.",
        )
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
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nieznany pakiet punktów.", "Unknown points package."))

    points_to_add = _POINTS_PACKAGE_AMOUNTS[payload.product_id]

    from app.services.google_play_billing import (
        PurchaseVerificationError,
        consume_purchase,
        verify_consumable_purchase,
    )

    from hashlib import sha256

    token_hash = sha256(f"{payload.platform}:{payload.purchase_token}".encode("utf-8")).hexdigest()
    user_id = current_user.id

    async def receipt():
        result = await db.execute(select(PointsPurchase).where(
            PointsPurchase.token_hash == token_hash))
        return result.scalar_one_or_none()

    def check_owner(record):
        if record.user_id != user_id or record.product_id != payload.product_id:
            raise HTTPException(status_code=409, detail=account_text(current_user,
                "Nie można przypisać tego zakupu do tego konta.",
                "This purchase cannot be assigned to this account."))

    recorded = await receipt()
    if recorded is not None:
        check_owner(recorded)

    if payload.platform == "ios":
        from app.services.apple_app_store import (
            PurchaseVerificationError as AppleVerificationError, verify_apple_consumable,
        )
        try:
            result = await verify_apple_consumable(payload.purchase_token, payload.product_id)
        except AppleVerificationError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
        result = {**result, "is_consumed": False}
        if recorded is None and result["is_purchased"]:
            legacy = await db.execute(select(ProcessedApplePurchase).where(
                ProcessedApplePurchase.transaction_id == payload.purchase_token))
            if legacy.scalar_one_or_none() is not None:
                # Old Apple rows have no owner: never guess or credit again.
                raise HTTPException(status_code=422, detail=account_text(current_user,
                    "Ten zakup został już wcześniej rozliczony.", "This purchase has already been processed."))
    else:
        try:
            result = await verify_consumable_purchase(payload.purchase_token, payload.product_id)
        except PurchaseVerificationError as exc:
            raise HTTPException(status_code=422, detail=str(exc))

    if not result["is_purchased"]:
        store = "Apple" if payload.platform == "ios" else "Google"
        raise HTTPException(status_code=422, detail=account_text(current_user,
            f"Ten zakup nie został potwierdzony przez {store}.", f"This purchase was not confirmed by {store}."))
    if result["is_consumed"] and recorded is None:
        # Ten SAM token już wcześniej doliczył punkty — nie przyznajemy
        # ich drugi raz (np. gdyby aplikacja wywołała ten endpoint
        # dwukrotnie dla tego samego zakupu).
        raise HTTPException(status_code=422, detail=account_text(current_user,
            "Ten zakup został już wcześniej rozliczony.", "This purchase has already been processed."))

    newly_credited = False
    if recorded is None:
        # UNIQUE token digest and an atomic balance increment commit together.
        # A second request cannot credit again even if Google is still offline.
        db.add(PointsPurchase(token_hash=token_hash, platform=payload.platform, user_id=user_id,
                                   product_id=payload.product_id, points=points_to_add))
        if payload.platform == "ios":
            # Preserve duplicate protection for older deployments, too.
            db.add(ProcessedApplePurchase(transaction_id=payload.purchase_token))
        try:
            await db.flush()
            await db.execute(update(User).where(User.id == user_id).values(
                premium_points=User.premium_points + points_to_add
            ).execution_options(synchronize_session=False))
            await db.commit()
            newly_credited = True
        except IntegrityError:
            await db.rollback()
            recorded = await receipt()
            if recorded is None:
                raise
            # Rollback expires ORM attributes. Refresh before using account copy.
            await db.refresh(current_user)
            check_owner(recorded)

    await db.refresh(current_user)
    if newly_credited and payload.platform == "android":
        await _notify(
            db, user_id,
            f"Doładowano {points_to_add} punktów premium. Masz ich teraz {current_user.premium_points}.",
            english_message=f"Added {points_to_add} Premium points. Your balance is now {current_user.premium_points}.",
        )

    try:
        if payload.platform == "android" and not result["is_consumed"]:
            await consume_purchase(payload.purchase_token, payload.product_id)
    except PurchaseVerificationError:
        # Punkty już przyznane (commit powyżej) — niepowodzenie samego
        # potwierdzenia u Google nie powinno cofać punktów, które
        # użytkownik już faktycznie kupił i opłacił. Zaloguj i idź dalej.
        import logging

        logging.getLogger(__name__).warning(
            "Nie udało się skonsumować zakupu punktów (punkty już zapisane; można ponowić)",
        )

    await db.refresh(current_user)
    return VerifyPointsPurchaseResponse(premium_points=current_user.premium_points)

async def _notify(db, user_id, message: str, ntype: str = "billing", *, english_message: str | None = None) -> None:
    """Tworzy powiadomienie i (jeśli włączony) wysyła push.

    Wydzielone, bo billing przyznaje premium i punkty w kilku miejscach,
    a powtarzanie tego bloku prosiłoby się o pominięcie w którymś z nich.
    Każdy błąd jest połykany: powiadomienie to dodatek, nie może cofnąć
    ani zablokować zakupu, za który użytkownik już zapłacił.
    """
    try:
        from app.models.notification import Notification
        from app.services.notification_language import recipient_text

        if english_message is not None:
            message = await recipient_text(db, user_id, message, english_message)
        n = Notification(user_id=user_id, notification_type=ntype, message=message)
        db.add(n)
        await db.commit()

        from app.services.push import is_push_enabled, push_for_notification

        if is_push_enabled():
            await push_for_notification(db, n)
    except Exception:
        import logging

        logging.getLogger(__name__).warning("Nie udało się wysłać powiadomienia o zakupie.")
