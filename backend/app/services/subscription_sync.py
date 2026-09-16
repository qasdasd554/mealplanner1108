"""Okresowa synchronizacja płatnej subskrypcji z Apple lub Google."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.premium import PAID_SUBSCRIPTION_PRODUCT_IDS
from app.models.user import User

logger = logging.getLogger(__name__)

_ACTIVE_REFRESH_INTERVAL = timedelta(hours=6)
_INACTIVE_REFRESH_INTERVAL = timedelta(minutes=15)


def _refresh_is_due(user: User, now: datetime) -> bool:
    last = user.premium_last_verified_at
    expired = (
        user.premium_expires_at is None
        or user.premium_expires_at <= now
        or not user.is_premium
    )

    if last is None:
        return True

    # Gdy zapisany okres właśnie minął, sprawdź odnowienie natychmiast,
    # nawet jeżeli poprzednia kontrola miała miejsce kilka minut temu.
    if (
        user.premium_expires_at is not None
        and user.premium_expires_at <= now
        and last < user.premium_expires_at
    ):
        return True

    interval = _INACTIVE_REFRESH_INTERVAL if expired else _ACTIVE_REFRESH_INTERVAL
    return now - last >= interval


async def refresh_subscription_if_needed(
    db: AsyncSession,
    user: User,
    *,
    force: bool = False,
) -> bool:
    """Odświeża datę i dostęp, jeśli mamy dane prawdziwego zakupu.

    Błędy komunikacji nie odbierają przedwcześnie dostępu: dotychczasowa
    data pozostaje źródłem prawdy. Jeśli jednak data już minęła, zwykła
    kontrola premium i tak bezpiecznie zablokuje funkcję do czasu udanej
    weryfikacji odnowienia.
    """
    if user.role == "admin":
        return False
    if user.premium_product_id not in PAID_SUBSCRIPTION_PRODUCT_IDS:
        return False
    if not user.premium_purchase_token:
        return False

    stored_platform = user.premium_platform or user.platform
    if stored_platform in {"ios", "android"}:
        platforms = [stored_platform]
    else:
        # Starsze zakupy powstały zanim zapisywaliśmy sklep w bazie. Apple
        # używa zwykle liczbowego transaction ID, a token Google jest
        # alfanumeryczny. Heurystyka ustala tylko kolejność — w razie
        # niepowodzenia zawsze sprawdzamy także drugi sklep.
        platforms = (
            ["ios", "android"]
            if user.premium_purchase_token.isdigit()
            else ["android", "ios"]
        )

    now = datetime.now(timezone.utc)
    if not force and not _refresh_is_due(user, now):
        return False

    result: dict | None = None
    verified_platform: str | None = None
    errors: list[str] = []
    for platform in platforms:
        try:
            if platform == "ios":
                from app.services.apple_app_store import (
                    PurchaseVerificationError,
                    verify_apple_subscription,
                )

                result = await verify_apple_subscription(
                    user.premium_purchase_token,
                    user.premium_product_id,
                )
            else:
                from app.services.google_play_billing import (
                    PurchaseVerificationError,
                    verify_subscription_purchase,
                )

                result = await verify_subscription_purchase(
                    user.premium_purchase_token,
                    user.premium_product_id,
                )
        except PurchaseVerificationError as exc:
            errors.append(f"{platform}: {exc}")
            continue

        verified_platform = platform
        break

    if result is None or verified_platform is None:
        # PurchaseVerificationError obejmuje również chwilowy błąd sklepu.
        # Nie wolno z tego powodu skracać już opłaconego okresu.
        logger.warning(
            "Nie udało się odświeżyć subskrypcji użytkownika %s: %s",
            user.id,
            "; ".join(errors),
        )
        return False

    expiry_time = result.get("expiry_time")
    if expiry_time is None:
        logger.warning(
            "Sklep nie zwrócił daty subskrypcji użytkownika %s", user.id
        )
        return False

    user.is_premium = bool(result.get("is_active"))
    user.premium_expires_at = expiry_time
    user.premium_product_id = result.get("product_id") or user.premium_product_id
    user.premium_purchase_token = (
        result.get("purchase_token") or user.premium_purchase_token
    )
    user.premium_platform = verified_platform
    user.premium_last_verified_at = now
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return True
