from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
import json
import re
import uuid

from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.core.config import settings
from app.core.rate_limit import (
    enforce_google_auth_rate_limit,
    enforce_login_rate_limit,
    enforce_signup_rate_limit,
    login_limiter,
)
from app.core.security import create_access_token, get_password_hash, verify_password
from app.db.session import get_db
from app.models import User
from app.schemas.user import UserCreate, UserResponse
from app.api.deps import get_current_user

router = APIRouter()

async def get_parsed_body(request: Request):
    try:
        body = await request.json()
        if isinstance(body, str):
            body = json.loads(body)
        return body
    except Exception:
        raise HTTPException(status_code=400, detail="Nieprawidłowe dane żądania (oczekiwano JSON)")


# Prosty, sprawdzony wzorzec formatu e-maila — celowo nie RFC 5322 w pełnej
# okazałości (to notorycznie odrzuca poprawne adresy), tylko rozsądne
# "wygląda jak e-mail". `email-validator` (potrzebny do EmailStr z Pydantic)
# nie jest zależnością tego projektu, więc zamiast dorzucać nowy pakiet,
# wystarczy prosty regex — usuwa najbardziej oczywiste śmieciowe wartości.
_EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

MIN_PASSWORD_LENGTH = 8


def _validate_credentials(email: str, password: str) -> None:
    """Wspólna walidacja e-maila i hasła dla rejestracji.

    UWAGA (naprawa bezpieczeństwa): wcześniej rejestracja sprawdzała tylko,
    że oba pola są niepuste — hasło "a" albo e-mail "x" przechodziły bez
    problemu. Limiter logowania trochę chroni przed łamaniem takich haseł
    siłowo, ale to za mało — jednoznakowe hasło jest łamane praktycznie
    natychmiast, jeśli ktoś w ogóle je odgadnie.
    """
    if not _EMAIL_PATTERN.match(email):
        raise HTTPException(status_code=400, detail="Nieprawidłowy format adresu e-mail")
    if len(password) < MIN_PASSWORD_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Hasło musi mieć co najmniej {MIN_PASSWORD_LENGTH} znaków",
        )

@router.post("/register")
async def register(request: Request, db: AsyncSession = Depends(get_db)):
    # Ogranicza masowe zakładanie kont z jednego adresu IP.
    enforce_signup_rate_limit(request)

    body = await get_parsed_body(request)
    email = body.get("email")
    password = body.get("password")
    display_name = (body.get("display_name") or "").strip()

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email i hasło są wymagane")
    _validate_credentials(email, password)
    # UWAGA (naprawa): wcześniej display_name nie miał ŻADNEJ walidacji —
    # nazwa dłuższa niż limit kolumny w bazie (200 znaków) powodowała
    # nieobsłużony błąd bazy danych (surowy 500, bez czytelnego
    # komunikatu) zamiast czytelnej odpowiedzi 400. Sprawdzamy to PRZED
    # dotarciem do bazy.
    if len(display_name) > 200:
        raise HTTPException(status_code=400, detail="Nazwa użytkownika jest za długa (maks. 200 znaków)")

    # UWAGA (naprawa poważnego błędu): adresy e-mail były porównywane z
    # rozróżnianiem wielkości liter — "User@Example.com" i
    # "user@example.com" tworzyły DWA OSOBNE konta, a logowanie inną
    # wielkością liter niż przy rejestracji kończyło się mylącym
    # "nieprawidłowe hasło" (mimo poprawnego hasła). Normalizujemy do
    # małych liter PRZED zapisem — wszystkie NOWE konta są odtąd spójne.
    email = email.strip().lower()

    result = await db.execute(select(User).where(func.lower(User.email) == email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Ten adres e-mail jest już zarejestrowany")

    user = User(
        email=email,
        password_hash=get_password_hash(password),
        display_name=display_name
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return {
        "access_token": create_access_token(data={"sub": str(user.id)}),
        "token_type": "bearer",
    }

@router.post("/login")
async def login(request: Request, db: AsyncSession = Depends(get_db)):
    # Ochrona przed łamaniem haseł metodą siłową — bez tego można było
    # odpytywać ten endpoint kolejnymi hasłami bez żadnego ograniczenia.
    rate_key = enforce_login_rate_limit(request)

    body = await get_parsed_body(request)
    email = body.get("email")
    password = body.get("password")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email i hasło są wymagane")

    # UWAGA (naprawa): dopasowanie bez rozróżniania wielkości liter — patrz
    # komentarz przy /register. Działa poprawnie też dla KONT ZAŁOŻONYCH
    # PRZED tą naprawą (niezależnie od tego, jaką wielkością liter zostały
    # zapisane), bo porównujemy obie strony po sprowadzeniu do małych liter,
    # a nie zakładamy z góry, że dane w bazie już są znormalizowane.
    email = email.strip().lower()

    result = await db.execute(select(User).where(func.lower(User.email) == email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(password, user.password_hash):
        # Licznik zwiększamy WYŁĄCZNIE przy nieudanej próbie, żeby normalnie
        # korzystający użytkownik nigdy nie trafił na limit.
        login_limiter.register_failure(rate_key)
        raise HTTPException(status_code=401, detail="Nieprawidłowy e-mail lub hasło")

    login_limiter.reset(rate_key)
    return {
        "access_token": create_access_token(data={"sub": str(user.id)}),
        "token_type": "bearer",
    }

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": str(current_user.id),
        "email": current_user.email,
        "display_name": current_user.display_name
    }

@router.post("/google")
async def google_login(request: Request, db: AsyncSession = Depends(get_db)):
    """Loguje/rejestruje użytkownika na podstawie id_token wystawionego przez
    Google (natywny SDK google_sign_in we Flutterze). Token jest weryfikowany
    offline (podpis, wygaśnięcie, audience) — nie wywołujemy żadnego
    dodatkowego zapytania do Google, więc to podejście nie zależy od
    redirect_uri i nie powoduje błędu "invalid_request"."""
    enforce_google_auth_rate_limit(request)

    body = await get_parsed_body(request)
    token = body.get("id_token")

    if not token:
        raise HTTPException(status_code=400, detail="Wymagany jest token id_token z Google")

    try:
        idinfo = google_id_token.verify_oauth2_token(
            token, google_requests.Request(), settings.GOOGLE_WEB_CLIENT_ID
        )
    except ValueError:
        # Token nieprawidłowy, wygasły albo wystawiony dla innego client_id.
        raise HTTPException(status_code=401, detail="Nieprawidłowy lub wygasły token Google")
    except GoogleAuthError:
        # Nie udało się pobrać kluczy publicznych Google (np. chwilowy problem
        # sieciowy po stronie serwera). To NIE jest wina użytkownika — zwracamy
        # 503, żeby aplikacja mogła poprosić o ponowną próbę, zamiast rzucać 500.
        raise HTTPException(
            status_code=503,
            detail="Nie można teraz zweryfikować logowania Google. Spróbuj ponownie za chwilę.",
        )

    email = idinfo.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Konto Google nie udostępniło adresu e-mail")
    if idinfo.get("email_verified") is False:
        raise HTTPException(status_code=400, detail="Adres e-mail konta Google nie jest zweryfikowany")

    # UWAGA (naprawa): ta sama normalizacja co przy /register i /login —
    # bez niej konto założone hasłem jako "User@Example.com" i późniejsze
    # logowanie Google tym samym adresem (Google zwykle, ale nie zawsze,
    # zwraca małe litery) mogłoby stworzyć DRUGIE, osobne konto zamiast
    # zalogować na to samo.
    email = email.strip().lower()

    result = await db.execute(select(User).where(func.lower(User.email) == email))
    user = result.scalar_one_or_none()

    if not user:
        # UWAGA (naprawa): przycinamy do limitu kolumny (200 znaków) na
        # wszelki wypadek — to dane z zewnętrznego źródła (token Google),
        # którym nie warto bezkrytycznie ufać, że zawsze zmieszczą się
        # w ograniczeniu bazy (patrz ta sama naprawa przy /register).
        google_name = (idinfo.get("name") or email.split("@")[0])[:200]
        user = User(
            email=email,
            # Hasło losowe i zahaszowane — konto założone przez Google nie
            # ma hasła, którym dałoby się zalogować metodą e-mail/hasło.
            password_hash=get_password_hash(uuid.uuid4().hex),
            display_name=google_name,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return {
        "access_token": create_access_token(data={"sub": str(user.id)}),
        "token_type": "bearer",
    }
