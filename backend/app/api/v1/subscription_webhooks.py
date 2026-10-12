"""Powiadomienia sklepów aktualizujące subskrypcję bez otwierania aplikacji."""

from __future__ import annotations

import base64
import binascii
import hmac
import json
import logging
from datetime import datetime, timezone

import jwt
from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.security import APIKeyQuery
from jwt import PyJWTError
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.premium import PAID_SUBSCRIPTION_PRODUCT_IDS
from app.db.session import get_db
from app.models.user import User

router = APIRouter()
logger = logging.getLogger(__name__)
webhook_secret_scheme = APIKeyQuery(name="token", auto_error=False)


def require_webhook_secret(token: str | None) -> None:
    configured = settings.BILLING_WEBHOOK_SECRET.strip()
    if len(configured) < 32:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Webhook płatności nie jest jeszcze skonfigurowany.",
        )
    if token is None or not hmac.compare_digest(token, configured):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nieprawidłowy token webhooka.",
        )


def _decode_jws_without_trusting_it(value: str) -> dict:
    """Dekoduje identyfikator potrzebny do odpytywania Apple.

    Te dane NIE są źródłem prawdy. Każdy znaleziony zakup jest następnie
    weryfikowany bezpośrednio przez uwierzytelnione App Store Server API.
    """
    if not value or len(value) > 250_000:
        raise ValueError("Nieprawidłowy signedPayload")
    try:
        decoded = jwt.decode(
            value,
            options={"verify_signature": False, "verify_aud": False},
        )
    except PyJWTError as exc:
        raise ValueError("Nieprawidłowy signedPayload") from exc
    if not isinstance(decoded, dict):
        raise ValueError("Nieprawidłowy signedPayload")
    return decoded


async def _find_user(
    db: AsyncSession,
    *,
    platform: str,
    purchase_token: str,
) -> User | None:
    result = await db.execute(
        select(User).where(
            User.premium_purchase_token == purchase_token,
            or_(
                User.premium_platform == platform,
                User.premium_platform.is_(None),
            ),
        ).order_by(User.premium_platform.desc()).limit(1)
    )
    return result.scalar_one_or_none()


async def _save_verified_result(
    db: AsyncSession,
    user: User,
    result: dict,
    *,
    platform: str,
) -> None:
    expiry = result.get("expiry_time")
    if expiry is None:
        raise ValueError("Sklep nie zwrócił daty końca subskrypcji")
    user.is_premium = bool(result.get("is_active"))
    user.premium_expires_at = expiry
    user.premium_product_id = result.get("product_id") or user.premium_product_id
    user.premium_purchase_token = (
        result.get("purchase_token") or user.premium_purchase_token
    )
    user.premium_platform = platform
    user.premium_status = result.get("subscription_status")
    user.premium_auto_renew_enabled = result.get("auto_renew_enabled")
    user.premium_last_verified_at = datetime.now(timezone.utc)
    db.add(user)
    await db.commit()
    await db.refresh(user)


async def process_apple_notification(
    body: dict,
    db: AsyncSession,
    *,
    expected_bundle: str,
) -> bool:
    outer = _decode_jws_without_trusting_it(str(body.get("signedPayload") or ""))
    data = outer.get("data") or {}
    if not isinstance(data, dict):
        return False
    # Powiadomienie testowe Apple nie zawiera transakcji — poprawna
    # odpowiedź 204 potwierdza wtedy samą osiągalność endpointu.
    signed_transaction = data.get("signedTransactionInfo")
    if not signed_transaction:
        return False
    transaction = _decode_jws_without_trusting_it(str(signed_transaction))
    bundle_id = transaction.get("bundleId") or data.get("bundleId")
    if not expected_bundle or bundle_id != expected_bundle:
        return False
    purchase_token = str(
        transaction.get("originalTransactionId")
        or transaction.get("transactionId")
        or ""
    )
    product_id = str(transaction.get("productId") or "")
    if not purchase_token or product_id not in PAID_SUBSCRIPTION_PRODUCT_IDS:
        return False
    user = await _find_user(db, platform="ios", purchase_token=purchase_token)
    if user is None:
        logger.info("Apple: brak użytkownika dla odebranego identyfikatora transakcji")
        return False

    from app.services.apple_app_store import (
        PurchaseVerificationError,
        verify_apple_subscription,
    )

    try:
        result = await verify_apple_subscription(purchase_token, product_id)
    except PurchaseVerificationError as exc:
        raise HTTPException(status_code=503, detail="Apple verification failed") from exc
    await _save_verified_result(db, user, result, platform="ios")
    return True


async def process_google_notification(
    body: dict,
    db: AsyncSession,
    *,
    expected_package: str,
) -> bool:
    message = body.get("message") or {}
    encoded = message.get("data") if isinstance(message, dict) else None
    if not encoded or len(str(encoded)) > 250_000:
        return False
    try:
        decoded = base64.b64decode(str(encoded), validate=True)
        event = json.loads(decoded)
    except (binascii.Error, UnicodeDecodeError, json.JSONDecodeError):
        return False
    if not isinstance(event, dict) or event.get("packageName") != expected_package:
        return False
    notification = event.get("subscriptionNotification")
    if not isinstance(notification, dict):
        # One-time products and test notifications do not modify Premium.
        return False
    purchase_token = str(notification.get("purchaseToken") or "")
    product_id = str(notification.get("subscriptionId") or "")
    if not purchase_token or product_id not in PAID_SUBSCRIPTION_PRODUCT_IDS:
        return False
    user = await _find_user(db, platform="android", purchase_token=purchase_token)
    if user is None:
        logger.info("Google: brak użytkownika dla odebranego tokenu zakupu")
        return False

    from app.services.google_play_billing import (
        PurchaseVerificationError,
        verify_subscription_purchase,
    )

    try:
        result = await verify_subscription_purchase(purchase_token, product_id)
    except PurchaseVerificationError as exc:
        raise HTTPException(status_code=503, detail="Google verification failed") from exc
    await _save_verified_result(db, user, result, platform="android")
    return True


@router.post("/apple", status_code=204)
async def apple_subscription_webhook(
    body: dict,
    token: str | None = Depends(webhook_secret_scheme),
    db: AsyncSession = Depends(get_db),
) -> Response:
    require_webhook_secret(token)
    try:
        await process_apple_notification(
            body,
            db,
            expected_bundle=settings.APPLE_BUNDLE_ID,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return Response(status_code=204)


@router.post("/google", status_code=204)
async def google_subscription_webhook(
    body: dict,
    token: str | None = Depends(webhook_secret_scheme),
    db: AsyncSession = Depends(get_db),
) -> Response:
    require_webhook_secret(token)
    await process_google_notification(
        body,
        db,
        expected_package=settings.GOOGLE_PLAY_PACKAGE_NAME,
    )
    return Response(status_code=204)
