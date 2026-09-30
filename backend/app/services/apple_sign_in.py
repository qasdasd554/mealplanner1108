"""Weryfikacja tokenu tożsamości "Sign in with Apple" (natywny SDK
`sign_in_with_apple` we Flutterze, flow bez przeglądarki — analogicznie
do logowania Google w app/api/v1/auth.py).

Apple wysyła JWT (JWS) podpisany kluczem RS256, którego publiczne klucze
trzeba pobrać z https://appleid.apple.com/auth/keys (JWKS, format
identyczny jak większość dostawców OIDC). W przeciwieństwie do logowania
Google (gdzie mamy gotową bibliotekę `google-auth`), tu weryfikujemy
token przez PyJWT i kryptograficzny klucz RSA pobrany z JWKS Apple.

Ważne dla przepływu natywnego (nie webowego): przy logowaniu z aplikacji
mobilnej `aud` (audience) w tokenie to Bundle ID aplikacji, NIE
identyfikator usługi (Services ID) używany przy logowaniu przez stronę
internetową. Stąd porównanie z `settings.APPLE_BUNDLE_ID`.
"""

from __future__ import annotations

import logging
import time

import httpx
import jwt
from jwt import PyJWTError
from jwt.algorithms import RSAAlgorithm

from app.core.config import settings

logger = logging.getLogger(__name__)

_APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
_APPLE_ISSUER = "https://appleid.apple.com"

# Klucze Apple zmieniają się rzadko — cache w pamięci procesu z krótkim
# czasem ważności, żeby NIE odpytywać Apple przy każdym pojedynczym
# logowaniu (to samo podejście co google-auth stosuje wewnętrznie dla
# kluczy Google).
_keys_cache: dict | None = None
_keys_cache_fetched_at: float = 0.0
_KEYS_CACHE_TTL_SECONDS = 3600


class AppleSignInError(Exception):
    """Token Apple jest nieprawidłowy, wygasły albo wystawiony dla innej aplikacji."""


async def _get_apple_public_keys() -> list[dict]:
    global _keys_cache, _keys_cache_fetched_at

    now = time.monotonic()
    if _keys_cache is not None and (now - _keys_cache_fetched_at) < _KEYS_CACHE_TTL_SECONDS:
        return _keys_cache["keys"]

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(_APPLE_KEYS_URL)
        response.raise_for_status()
        _keys_cache = response.json()
        _keys_cache_fetched_at = now
        return _keys_cache["keys"]


async def verify_apple_identity_token(identity_token: str) -> dict:
    """Weryfikuje podpis, wystawcę, odbiorcę i czas ważności tokenu.

    Zwraca zdekodowany payload (zawiera co najmniej `sub`, opcjonalnie
    `email` i `is_private_email`).

    Raises:
        AppleSignInError: jeśli weryfikacja się nie powiedzie z
            JAKIEGOKOLWIEK powodu (podpis, wystawca, odbiorca, czas
            ważności, brak pasującego klucza, błąd sieci przy pobieraniu
            kluczy Apple).
    """
    try:
        unverified_header = jwt.get_unverified_header(identity_token)
    except PyJWTError as exc:
        raise AppleSignInError("Nieprawidłowy token Apple (zły nagłówek).") from exc

    kid = unverified_header.get("kid")
    if kid is None:
        raise AppleSignInError("Token Apple nie zawiera identyfikatora klucza.")

    try:
        apple_keys = await _get_apple_public_keys()
    except httpx.HTTPError as exc:
        raise AppleSignInError(
            "Nie można teraz pobrać kluczy publicznych Apple. Spróbuj ponownie."
        ) from exc

    matching_key = next((k for k in apple_keys if k.get("kid") == kid), None)
    if matching_key is None:
        raise AppleSignInError("Token Apple podpisany nieznanym kluczem.")

    try:
        public_key = RSAAlgorithm.from_jwk(matching_key)
        payload = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=settings.APPLE_BUNDLE_ID,
            issuer=_APPLE_ISSUER,
        )
    except (PyJWTError, ValueError, TypeError) as exc:
        raise AppleSignInError(
            "Token Apple jest nieprawidłowy, wygasł albo dotyczy innej aplikacji."
        ) from exc

    return payload
