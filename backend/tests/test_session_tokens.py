"""Regresje rozdzielenia tokenu dostępu od tokenu odświeżającego."""

from jose import jwt

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token


def _decode(token: str) -> dict:
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])


def test_access_token_has_access_type() -> None:
    assert _decode(create_access_token({"sub": "user-id"}))["type"] == "access"


def test_refresh_token_has_refresh_type() -> None:
    assert _decode(create_refresh_token({"sub": "user-id"}))["type"] == "refresh"
