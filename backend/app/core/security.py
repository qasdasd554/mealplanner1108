"""Narzędzia bezpieczeństwa — JWT i haszowanie haseł."""

from datetime import datetime, timedelta, timezone

from jose import jwt
import bcrypt

from app.core.config import settings


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """Tworzy token JWT z podanymi danymi i czasem wygaśnięcia.

    Args:
        data: Dane do zakodowania w tokenie (np. ``{"sub": user_id}``).
        expires_delta: Opcjonalny czas życia tokena. Domyślnie
            ``ACCESS_TOKEN_EXPIRE_MINUTES`` z konfiguracji.

    Returns:
        Zakodowany token JWT jako string.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(data: dict) -> str:
    """Tworzy długowieczny token służący wyłącznie do odnowienia sesji."""
    to_encode = data.copy()
    to_encode.update({
        "exp": datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        "type": "refresh",
    })
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Weryfikuje hasło w postaci jawnej względem hasha bcrypt.

    Args:
        plain_password: Hasło podane przez użytkownika.
        hashed_password: Hash zapisany w bazie danych.

    Returns:
        ``True`` jeśli hasło jest poprawne.
    """
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8")
        )
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Generuje hash bcrypt dla podanego hasła.

    Args:
        password: Hasło w postaci jawnej.

    Returns:
        Hash bcrypt jako string.
    """
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")
