import base64
import json
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import jwt
import pytest
from fastapi import HTTPException

from app.api.v1 import subscription_webhooks


class _ScalarResult:
    def __init__(self, value):
        self.value = value

    def scalar_one_or_none(self):
        return self.value


class _FakeDb:
    def __init__(self, user):
        self.user = user
        self.commit = AsyncMock()
        self.refresh = AsyncMock()

    async def execute(self, _statement):
        return _ScalarResult(self.user)

    def add(self, _value):
        return None


def _user(platform: str, token: str):
    return SimpleNamespace(
        id=uuid4(),
        role="user",
        is_premium=True,
        premium_platform=platform,
        premium_purchase_token=token,
        premium_product_id="premium_monthly",
        premium_expires_at=datetime.now(timezone.utc) + timedelta(days=1),
        premium_last_verified_at=None,
        premium_status=None,
        premium_auto_renew_enabled=None,
    )


def _pubsub_payload(data: dict) -> dict:
    encoded = base64.b64encode(json.dumps(data).encode()).decode()
    return {"message": {"data": encoded, "messageId": "123"}}


def _unsigned_test_jws(payload: dict) -> str:
    # Podpis jest celowo testowy. Handler używa JWS wyłącznie do znalezienia
    # tokenu, a stan subskrypcji zawsze potwierdza osobnym zapytaniem do Apple.
    return jwt.encode(payload, "test-secret-at-least-32-characters", algorithm="HS256")


def test_webhook_secret_is_required(monkeypatch):
    monkeypatch.setattr(
        subscription_webhooks.settings,
        "BILLING_WEBHOOK_SECRET",
        "correct-secret-at-least-32-characters",
    )
    with pytest.raises(HTTPException) as exc:
        subscription_webhooks.require_webhook_secret("wrong-secret")
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_google_notification_updates_period_without_opening_app(monkeypatch):
    token = "google-purchase-token"
    user = _user("android", token)
    db = _FakeDb(user)
    expiry = datetime.now(timezone.utc) + timedelta(days=31)
    verify = AsyncMock(
        return_value={
            "is_active": True,
            "expiry_time": expiry,
            "product_id": "premium_monthly",
            "purchase_token": token,
            "subscription_status": "SUBSCRIPTION_STATE_ACTIVE",
            "auto_renew_enabled": True,
        }
    )
    monkeypatch.setattr(
        "app.services.google_play_billing.verify_subscription_purchase",
        verify,
    )

    processed = await subscription_webhooks.process_google_notification(
        _pubsub_payload(
            {
                "packageName": "com.meal-planner-polska-v1",
                "subscriptionNotification": {
                    "purchaseToken": token,
                    "subscriptionId": "premium_monthly",
                    "notificationType": 2,
                },
            }
        ),
        db,
        expected_package="com.meal-planner-polska-v1",
    )

    assert processed is True
    assert user.premium_expires_at == expiry
    assert user.premium_status == "SUBSCRIPTION_STATE_ACTIVE"
    assert user.premium_auto_renew_enabled is True
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_apple_notification_updates_period_without_opening_app(monkeypatch):
    original_id = "2000000123456789"
    user = _user("ios", original_id)
    db = _FakeDb(user)
    expiry = datetime.now(timezone.utc) + timedelta(days=31)
    verify = AsyncMock(
        return_value={
            "is_active": True,
            "expiry_time": expiry,
            "product_id": "premium_monthly",
            "purchase_token": original_id,
            "subscription_status": "active",
            "auto_renew_enabled": True,
        }
    )
    monkeypatch.setattr(
        "app.services.apple_app_store.verify_apple_subscription",
        verify,
    )
    transaction = _unsigned_test_jws(
        {
            "originalTransactionId": original_id,
            "productId": "premium_monthly",
            "bundleId": "com.meal-planner-polska-v1",
        }
    )
    outer = _unsigned_test_jws(
        {
            "notificationType": "DID_RENEW",
            "data": {
                "bundleId": "com.meal-planner-polska-v1",
                "signedTransactionInfo": transaction,
            },
        }
    )

    processed = await subscription_webhooks.process_apple_notification(
        {"signedPayload": outer},
        db,
        expected_bundle="com.meal-planner-polska-v1",
    )

    assert processed is True
    assert user.premium_expires_at == expiry
    assert user.premium_status == "active"
    assert user.premium_auto_renew_enabled is True
    db.commit.assert_awaited_once()
