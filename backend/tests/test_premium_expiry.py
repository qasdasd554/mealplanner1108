from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.core.premium import is_premium_active
from app.models.user import User
from app.services import apple_app_store
from app.services.subscription_sync import refresh_subscription_if_needed


def _user(**overrides) -> User:
    values = {
        "id": uuid4(),
        "email": "expiry-test@example.com",
        "password_hash": "test",
        "role": "user",
        "is_premium": True,
        "premium_product_id": "premium_monthly",
        "premium_expires_at": datetime.now(timezone.utc) + timedelta(days=2),
        "premium_purchase_token": "transaction-1",
        "premium_platform": "ios",
        "premium_last_verified_at": None,
    }
    values.update(overrides)
    return User(**values)


def test_paid_premium_expires_even_when_flag_stays_true() -> None:
    user = _user(
        premium_expires_at=datetime.now(timezone.utc) - timedelta(seconds=1)
    )
    assert is_premium_active(user) is False


def test_paid_product_without_expiry_is_not_lifetime() -> None:
    assert is_premium_active(_user(premium_expires_at=None)) is False


def test_manual_premium_without_expiry_can_remain_lifetime() -> None:
    user = _user(premium_product_id="manual", premium_expires_at=None)
    assert is_premium_active(user) is True


@pytest.mark.asyncio
async def test_apple_uses_latest_renewal_and_grace_expiry(monkeypatch) -> None:
    now = datetime.now(timezone.utc)
    renewed = now + timedelta(days=30)
    grace = renewed + timedelta(days=3)
    mapping = {
        "transaction-jws": {
            "productId": "premium_monthly",
            "expiresDate": int(renewed.timestamp() * 1000),
            "originalTransactionId": "original-1",
        },
        "renewal-jws": {
            "gracePeriodExpiresDate": int(grace.timestamp() * 1000),
        },
    }
    monkeypatch.setattr(
        apple_app_store,
        "_fetch_subscription_status",
        AsyncMock(
            return_value={
                "bundleId": "test",
                "data": [
                    {
                        "lastTransactions": [
                            {
                                "status": 4,
                                "originalTransactionId": "original-1",
                                "signedTransactionInfo": "transaction-jws",
                                "signedRenewalInfo": "renewal-jws",
                            }
                        ]
                    }
                ],
            }
        ),
    )
    monkeypatch.setattr(
        apple_app_store.jose_jwt,
        "get_unverified_claims",
        lambda value: mapping[value],
    )

    result = await apple_app_store.verify_apple_subscription(
        "old-transaction", "premium_monthly"
    )

    assert result["is_active"] is True
    assert int(result["expiry_time"].timestamp() * 1000) == int(
        grace.timestamp() * 1000
    )
    assert result["purchase_token"] == "original-1"


@pytest.mark.asyncio
async def test_sync_updates_renewed_period(monkeypatch) -> None:
    expiry = datetime.now(timezone.utc) + timedelta(days=30)
    verify = AsyncMock(
        return_value={
            "is_active": True,
            "expiry_time": expiry,
            "product_id": "premium_monthly",
            "purchase_token": "original-1",
        }
    )
    monkeypatch.setattr(
        "app.services.apple_app_store.verify_apple_subscription", verify
    )
    class FakeDb:
        def __init__(self) -> None:
            self.commit = AsyncMock()
            self.refresh = AsyncMock()
            self.added = []

        def add(self, value) -> None:
            self.added.append(value)

    db = FakeDb()
    user = _user(
        premium_expires_at=datetime.now(timezone.utc) - timedelta(minutes=1)
    )

    changed = await refresh_subscription_if_needed(db, user)

    assert changed is True
    assert user.is_premium is True
    assert user.premium_expires_at == expiry
    assert user.premium_purchase_token == "original-1"
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_sync_recognizes_store_for_legacy_purchase(monkeypatch) -> None:
    expiry = datetime.now(timezone.utc) + timedelta(days=30)
    verify = AsyncMock(
        return_value={
            "is_active": True,
            "expiry_time": expiry,
            "product_id": "premium_monthly",
            "purchase_token": "1234567890",
        }
    )
    monkeypatch.setattr(
        "app.services.apple_app_store.verify_apple_subscription", verify
    )

    class FakeDb:
        def __init__(self) -> None:
            self.commit = AsyncMock()
            self.refresh = AsyncMock()

        def add(self, _value) -> None:
            pass

    user = _user(
        premium_purchase_token="1234567890",
        premium_platform=None,
        platform=None,
        premium_expires_at=datetime.now(timezone.utc) - timedelta(minutes=1),
    )

    changed = await refresh_subscription_if_needed(FakeDb(), user)

    assert changed is True
    assert user.premium_platform == "ios"
    verify.assert_awaited_once()
