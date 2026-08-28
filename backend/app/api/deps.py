"""Zależności wstrzykiwane do endpointów API (dependency injection)."""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_db
from app.models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

# UWAGA (nowe — śledzenie aktywności): jak często NAJWYŻEJ zapisujemy
# nową wartość last_active_at do bazy. Bez tego progu KAŻDE pojedyncze
# zapytanie API (a jest ich dużo — każde odświeżenie ekranu, każdy
# scroll listy) wywoływałoby dodatkowy zapis do bazy, co jest
# niepotrzebnym obciążeniem — "aktywny w ostatnich 5 minutach" to
# w zupełności wystarczająca precyzja do celu, jakim jest orientacyjne
# monitorowanie zaangażowania użytkowników, nie rozliczanie co do sekundy.
_ACTIVITY_UPDATE_THROTTLE = timedelta(minutes=5)


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Dekoduje token JWT i zwraca bieżącego użytkownika.

    Raises:
        HTTPException 401: jeśli token jest nieprawidłowy lub użytkownik nie istnieje.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Nie udało się zweryfikować poświadczeń",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
        user_id = UUID(user_id_str)
    except (JWTError, ValueError):
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception

    # Aktualizacja "ostatnio aktywny" — przepustowana (patrz komentarz
    # przy _ACTIVITY_UPDATE_THROTTLE powyżej), żeby nie zapisywać do bazy
    # przy każdym pojedynczym zapytaniu.
    now = datetime.now(timezone.utc)
    if user.last_active_at is None or (now - user.last_active_at) > _ACTIVITY_UPDATE_THROTTLE:
        user.last_active_at = now
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return user


async def get_current_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """Jak get_current_user, ale odrzuca (403), jeśli konto nie ma roli
    "admin". Nadanie roli admina nie jest możliwe przez żaden endpoint —
    ustawia się to bezpośrednio w bazie danych."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ta operacja wymaga uprawnień administratora",
        )
    return current_user


async def get_current_premium(
    current_user: User = Depends(get_current_user),
) -> User:
    """Jak get_current_user, ale odrzuca (403), jeśli konto nie ma
    aktywnego statusu premium (uwzględnia datę wygaśnięcia subskrypcji)."""
    from app.core.premium import is_premium_active

    if not is_premium_active(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ta funkcja wymaga aktywnej subskrypcji Premium",
        )
    return current_user
