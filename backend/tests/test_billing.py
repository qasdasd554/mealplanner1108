from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.api.v1 import billing
from app.models.user import User


class _FakeDb:
    commit = AsyncMock()
    refresh = AsyncMock()


def _user(*, premium: bool) -> User:
    return User(
        id=uuid4(),
        email="premium-test@example.com",
        password_hash="test",
        role="user",
        is_premium=premium,
        premium_expires_at=(
            datetime.now(timezone.utc) + timedelta(days=7) if premium else None
        ),
    )


@pytest.mark.asyncio
async def test_replayed_purchase_does_not_create_activation_notification(monkeypatch):
    expiry = datetime.now(timezone.utc) + timedelta(days=30)
    verify = AsyncMock(
        return_value={
            "is_active": True,
            "expiry_time": expiry,
            "product_id": "premium_monthly",
        }
    )
    notify = AsyncMock()
    monkeypatch.setattr(
        "app.services.google_play_billing.verify_subscription_purchase",
        verify,
    )
    monkeypatch.setattr(billing, "_notify", notify)

    user = _user(premium=True)
    await billing.verify_purchase(
        billing.VerifyPurchaseRequest(
            purchase_token="old-token",
            product_id="premium_monthly",
        ),
        user,
        _FakeDb(),
    )

    notify.assert_not_awaited()


@pytest.mark.asyncio
async def test_new_purchase_creates_one_activation_notification(monkeypatch):
    expiry = datetime.now(timezone.utc) + timedelta(days=30)
    verify = AsyncMock(
        return_value={
            "is_active": True,
            "expiry_time": expiry,
            "product_id": "premium_monthly",
        }
    )
    notify = AsyncMock()
    monkeypatch.setattr(
        "app.services.google_play_billing.verify_subscription_purchase",
        verify,
    )
    monkeypatch.setattr(billing, "_notify", notify)

    user = _user(premium=False)
    await billing.verify_purchase(
        billing.VerifyPurchaseRequest(
            purchase_token="new-token",
            product_id="premium_monthly",
        ),
        user,
        _FakeDb(),
    )

    notify.assert_awaited_once()
