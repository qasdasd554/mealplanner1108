"""Zależności wstrzykiwane do endpointów API (dependency injection)."""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from fastapi import Request
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


async def get_current_user_allow_unverified(
    request: Request,
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Dekoduje token JWT i zwraca bieżącego użytkownika BEZ wymogu
    potwierdzonego adresu e-mail.

    Używać WYŁĄCZNIE tam, gdzie niezweryfikowane konto musi mieć dostęp
    z samej natury operacji: potwierdzanie kodu, ponowne wysłanie kodu
    i odczyt własnego profilu (aplikacja musi móc sprawdzić, czy e-mail
    jest już potwierdzony). Wszystko inne używa `get_current_user`.

    Raises:
        HTTPException 401: jeśli token jest nieprawidłowy lub użytkownik nie istnieje.
        HTTPException 403: jeśli konto jest zablokowane przez administratora.
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

    # Blokada konta sprawdzana TUTAJ, a nie w poszczególnych endpointach —
    # to wspólny punkt wejścia dla każdego zabezpieczonego endpointu, więc
    # jedno sprawdzenie odcina zbanowane konto od CAŁEGO API naraz
    # (również dla tokenów wydanych przed banem, które inaczej działałyby
    # aż do wygaśnięcia).
    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=user.ban_reason or "To konto zostało zablokowane przez administratora.",
        )

    # Aktualizacja "ostatnio aktywny" — przepustowana (patrz komentarz
    # przy _ACTIVITY_UPDATE_THROTTLE powyżej), żeby nie zapisywać do bazy
    # przy każdym pojedynczym zapytaniu. Platforma (X-Platform, wysyłana
    # przez ApiClient we Flutterze na KAŻDYM żądaniu) aktualizowana przy
    # okazji tego samego, przepustowanego zapisu — osobny zapis tylko dla
    # jednego pola byłby marnotrawstwem tego samego zasobu, który ten
    # throttling ma oszczędzać.
    now = datetime.now(timezone.utc)
    incoming_platform = request.headers.get("x-platform")
    if incoming_platform not in ("ios", "android"):
        incoming_platform = None

    should_update_activity = (
        user.last_active_at is None or (now - user.last_active_at) > _ACTIVITY_UPDATE_THROTTLE
    )
    platform_changed = incoming_platform is not None and incoming_platform != user.platform

    if should_update_activity or platform_changed:
        user.last_active_at = now
        if incoming_platform is not None:
            user.platform = incoming_platform
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return user


async def get_current_user(
    current_user: User = Depends(get_current_user_allow_unverified),
) -> User:
    """Zwraca bieżącego użytkownika i WYMAGA potwierdzonego adresu e-mail.

    NAPRAWA POWAŻNEJ LUKI: wcześniej `is_email_verified` było ustawiane
    i zwracane, ale nigdzie NIE EGZEKWOWANE po stronie serwera —
    jedynym zabezpieczeniem było przekierowanie w aplikacji po
    rejestracji. Ponieważ /auth/register od razu wydaje ważny token,
    wystarczyło zamknąć aplikację na ekranie weryfikacji i otworzyć
    ponownie (splash kierował na /home, patrząc tylko na to, czy jest
    token), żeby korzystać z konta bez potwierdzenia adresu — w
    nieskończoność. Tym bardziej działało to przy odpytywaniu API
    bezpośrednio, z pominięciem aplikacji.

    Raises:
        HTTPException 403: jeśli adres e-mail nie został potwierdzony.
    """
    if not current_user.is_email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Potwierdź swój adres e-mail, aby korzystać z aplikacji.",
        )
    return current_user


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
