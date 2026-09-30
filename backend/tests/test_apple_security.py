"""Regresje bezpieczeństwa logowania i zakupów Apple."""

import json
import time
from unittest.mock import AsyncMock

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from app.services import apple_app_store, apple_sign_in


def _apple_identity_token(*, audience: str) -> tuple[str, dict]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_jwk = json.loads(RSAAlgorithm.to_jwk(private_key.public_key()))
    public_jwk.update({"kid": "test-key", "alg": "RS256", "use": "sig"})
    token = jwt.encode(
        {
            "iss": "https://appleid.apple.com",
            "aud": audience,
            "sub": "apple-user-1",
            "exp": int(time.time()) + 300,
        },
        private_key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )
    return token, public_jwk


@pytest.mark.asyncio
async def test_apple_identity_token_signature_audience_and_issuer_are_verified(
    monkeypatch,
) -> None:
    bundle_id = "com.meal-planner-polska-v1"
    monkeypatch.setattr(apple_sign_in.settings, "APPLE_BUNDLE_ID", bundle_id)
    token, public_jwk = _apple_identity_token(audience=bundle_id)
    monkeypatch.setattr(
        apple_sign_in,
        "_get_apple_public_keys",
        AsyncMock(return_value=[public_jwk]),
    )

    payload = await apple_sign_in.verify_apple_identity_token(token)

    assert payload["sub"] == "apple-user-1"


@pytest.mark.asyncio
async def test_apple_identity_token_for_another_app_is_rejected(monkeypatch) -> None:
    monkeypatch.setattr(
        apple_sign_in.settings,
        "APPLE_BUNDLE_ID",
        "com.meal-planner-polska-v1",
    )
    token, public_jwk = _apple_identity_token(audience="com.example.other-app")
    monkeypatch.setattr(
        apple_sign_in,
        "_get_apple_public_keys",
        AsyncMock(return_value=[public_jwk]),
    )

    with pytest.raises(apple_sign_in.AppleSignInError):
        await apple_sign_in.verify_apple_identity_token(token)


@pytest.mark.asyncio
async def test_consumable_transaction_from_another_app_is_rejected(monkeypatch) -> None:
    monkeypatch.setattr(
        apple_app_store.settings,
        "APPLE_BUNDLE_ID",
        "com.meal-planner-polska-v1",
    )
    monkeypatch.setattr(
        apple_app_store,
        "_fetch_transaction_info",
        AsyncMock(
            return_value={
                "bundleId": "com.example.other-app",
                "productId": "points_10",
            }
        ),
    )

    with pytest.raises(apple_app_store.PurchaseVerificationError):
        await apple_app_store.verify_apple_consumable("transaction", "points_10")
