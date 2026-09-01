from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
import json
import logging
import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from google.auth.exceptions import GoogleAuthError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.core.config import settings
from app.services.apple_sign_in import AppleSignInError, verify_apple_identity_token
from app.services.email_service import EmailSendError, send_password_reset_email, send_verification_email
from app.core.rate_limit import (
    email_verification_resend_limiter,
    enforce_google_auth_rate_limit,
    enforce_login_rate_limit,
    enforce_password_reset_rate_limit,
    enforce_signup_rate_limit,
    enforce_user_rate_limit,
    login_limiter,
)
from app.core.security import create_access_token, get_password_hash, verify_password
from app.db.session import get_db
from app.models import User
from app.schemas.user import UserCreate, UserResponse
from app.api.deps import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

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
    # Generujemy 6-cyfrowy kod weryfikacyjny (secrets, nie random — losowość
    # kryptograficzna, bo to w końcu mechanizm bezpieczeństwa) i 15-minutowe
    # okno ważności.
    verification_code = "".join(secrets.choice("0123456789") for _ in range(6))
    user.email_verification_code = verification_code
    user.email_verification_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    db.add(user)
    await db.commit()
    await db.refresh(user)

    # UWAGA: wysyłka maila NIE przerywa rejestracji, jeśli się nie powiedzie
    # (np. chwilowa awaria Resend) — konto i tak się tworzy, użytkownik
    # może poprosić o ponowne wysłanie kodu przez /auth/resend-code.
    try:
        await send_verification_email(user.email, verification_code, user.display_name)
    except EmailSendError:
        logger.warning("Nie udało się wysłać maila weryfikacyjnego do %s przy rejestracji.", user.email)

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
        "display_name": current_user.display_name,
        "is_email_verified": current_user.is_email_verified,
    }


@router.post("/verify-email")
async def verify_email(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Potwierdza adres e-mail kodem wysłanym przy rejestracji.

    Celowo NIE ujawnia w komunikacie błędu, czy kod jest zły, czy
    wygasł — jedna, ogólna odpowiedź utrudnia zgadywanie kodu metodą
    prób i błędów (kod ma tylko 6 cyfr, więc bez limitu prób i bez tej
    dwuznaczności dałoby się go złamać siłowo względnie łatwo).
    """
    if current_user.is_email_verified:
        return {"is_email_verified": True}

    body = await get_parsed_body(request)
    code = (body.get("code") or "").strip()

    invalid = HTTPException(status_code=400, detail="Nieprawidłowy albo wygasły kod weryfikacyjny.")

    if not code or not current_user.email_verification_code:
        raise invalid
    if current_user.email_verification_code != code:
        raise invalid
    if (
        current_user.email_verification_code_expires_at is None
        or datetime.now(timezone.utc) > current_user.email_verification_code_expires_at
    ):
        raise invalid

    current_user.is_email_verified = True
    current_user.email_verification_code = None
    current_user.email_verification_code_expires_at = None
    await db.commit()

    return {"is_email_verified": True}


@router.post("/resend-code")
async def resend_verification_code(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generuje i wysyła NOWY kod weryfikacyjny — np. gdy poprzedni
    wygasł, albo mail się zgubił. Limitowane do 3 razy na 10 minut na
    konto (patrz email_verification_resend_limiter)."""
    if current_user.is_email_verified:
        return {"detail": "To konto jest już zweryfikowane."}

    enforce_user_rate_limit(email_verification_resend_limiter, current_user.id, "resend-verification-code")

    verification_code = "".join(secrets.choice("0123456789") for _ in range(6))
    current_user.email_verification_code = verification_code
    current_user.email_verification_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    await db.commit()

    try:
        await send_verification_email(current_user.email, verification_code, current_user.display_name)
    except EmailSendError:
        logger.warning("Nie udało się wysłać ponownego kodu weryfikacyjnego do %s.", current_user.email)
        raise HTTPException(
            status_code=503,
            detail="Nie udało się wysłać e-maila. Spróbuj ponownie za chwilę.",
        )

    return {"detail": "Nowy kod został wysłany."}


@router.post("/forgot-password")
async def forgot_password(request: Request, db: AsyncSession = Depends(get_db)):
    """Wysyła kod resetu hasła na podany adres — JEŚLI konto z tym
    adresem istnieje. Celowo ZAWSZE zwraca tę samą odpowiedź, niezależnie
    od tego, czy konto istnieje — inaczej ten endpoint dałoby się użyć do
    sprawdzania, które adresy e-mail są zarejestrowane w systemie
    (enumeracja użytkowników), po prostu obserwując różnicę w odpowiedzi.
    """
    enforce_password_reset_rate_limit(request)

    body = await get_parsed_body(request)
    email = (body.get("email") or "").strip().lower()

    generic_response = {
        "detail": "Jeśli podany adres e-mail istnieje w naszym systemie, wysłaliśmy na niego kod resetu hasła."
    }

    if not email:
        return generic_response

    result = await db.execute(select(User).where(func.lower(User.email) == email))
    user = result.scalar_one_or_none()
    if user is None:
        return generic_response

    reset_code = "".join(secrets.choice("0123456789") for _ in range(6))
    user.password_reset_code = reset_code
    user.password_reset_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    await db.commit()

    try:
        await send_password_reset_email(user.email, reset_code, user.display_name)
    except EmailSendError:
        logger.warning("Nie udało się wysłać maila resetu hasła do %s.", user.email)
        # UWAGA: mimo błędu wysyłki NADAL zwracamy generyczną odpowiedź —
        # ujawnienie "wysyłka się nie powiodła" akurat TU zdradziłoby, że
        # konto istnieje (bo dla nieistniejącego konta nigdy nie próbujemy
        # nawet wysyłać). Błąd trafia tylko do logów serwera.

    return generic_response


@router.post("/reset-password")
async def reset_password(request: Request, db: AsyncSession = Depends(get_db)):
    """Ustawia nowe hasło na podstawie kodu wysłanego przez /forgot-password."""
    body = await get_parsed_body(request)
    email = (body.get("email") or "").strip().lower()
    code = (body.get("code") or "").strip()
    new_password = body.get("new_password") or ""

    # Ta sama, celowo ogólna odpowiedź błędu niezależnie od TEGO, co
    # dokładnie jest nie tak (konto nie istnieje / zły kod / kod wygasł)
    # — z tych samych powodów co przy weryfikacji e-mail: nie ułatwiamy
    # zgadywania 6-cyfrowego kodu metodą prób i błędów przez rozróżnianie
    # komunikatów, i nie zdradzamy, czy dany e-mail w ogóle istnieje.
    invalid = HTTPException(status_code=400, detail="Nieprawidłowy albo wygasły kod resetu hasła.")

    if not email or not code:
        raise invalid
    if len(new_password) < MIN_PASSWORD_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Nowe hasło musi mieć co najmniej {MIN_PASSWORD_LENGTH} znaków",
        )

    result = await db.execute(select(User).where(func.lower(User.email) == email))
    user = result.scalar_one_or_none()
    if user is None or not user.password_reset_code:
        raise invalid
    if user.password_reset_code != code:
        raise invalid
    if (
        user.password_reset_code_expires_at is None
        or datetime.now(timezone.utc) > user.password_reset_code_expires_at
    ):
        raise invalid

    user.password_hash = get_password_hash(new_password)
    user.password_reset_code = None
    user.password_reset_code_expires_at = None
    await db.commit()

    return {"detail": "Hasło zostało zmienione. Możesz się teraz zalogować."}


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
            # Google już zweryfikował ten adres e-mail (sprawdzone wyżej
            # przez idinfo.get("email_verified")) — nie ma sensu prosić
            # o drugą weryfikację kodem, konto Google potwierdza się samo.
            is_email_verified=True,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return {
        "access_token": create_access_token(data={"sub": str(user.id)}),
        "token_type": "bearer",
    }


@router.post("/apple")
async def apple_login(request: Request, db: AsyncSession = Depends(get_db)):
    """Loguje/rejestruje użytkownika na podstawie tokenu tożsamości
    wystawionego przez "Sign in with Apple" (pakiet `sign_in_with_apple`
    we Flutterze, natywny flow — patrz app/services/apple_sign_in.py).

    Wymagane przez Apple Guideline 4.8: aplikacja oferująca logowanie
    przez zewnętrzną usługę (tu: Google) musi też oferować Sign in with
    Apple jako równorzędną opcję.
    """
    enforce_google_auth_rate_limit(request)  # ten sam limiter co Google — chroni oba endpointy logowania społecznościowego.

    body = await get_parsed_body(request)
    identity_token = body.get("identity_token")
    if not identity_token:
        raise HTTPException(status_code=400, detail="Wymagany jest identity_token z Apple")

    # Apple przesyła imię i nazwisko TYLKO przy pierwszej autoryzacji
    # (kolejne logowania tego samego użytkownika ich nie zawierają) —
    # aplikacja musi je zapisać lokalnie po pierwszym logowaniu i wysłać
    # tutaj, żeby konto miało jakąkolwiek nazwę wyświetlaną.
    full_name = (body.get("full_name") or "").strip()

    try:
        claims = await verify_apple_identity_token(identity_token)
    except AppleSignInError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

    apple_user_id = claims.get("sub")
    if not apple_user_id:
        raise HTTPException(status_code=400, detail="Token Apple nie zawiera identyfikatora użytkownika")

    email = claims.get("email")
    if email:
        email = email.strip().lower()

    # 1. Dopasuj po apple_user_id — to jedyne pole gwarantowane przy
    #    KAŻDYM logowaniu (patrz komentarz w modelu User).
    result = await db.execute(select(User).where(User.apple_user_id == apple_user_id))
    user = result.scalar_one_or_none()

    if not user and email:
        # 2. Konto mogło już istnieć (np. założone e-mailem/hasłem albo
        #    przez Google) z tym samym adresem — połącz zamiast tworzyć
        #    duplikat. Bezpieczne, bo Apple gwarantuje, że e-mail w
        #    tokenie jest zweryfikowany.
        result = await db.execute(select(User).where(func.lower(User.email) == email))
        user = result.scalar_one_or_none()
        if user is not None:
            user.apple_user_id = apple_user_id

    if not user:
        # Apple czasem w ogóle nie udostępnia e-maila (rzadkie, ale
        # dopuszczalne) — wtedy generujemy nieużywany, wewnętrzny adres
        # zastępczy, żeby kolumna email (NOT NULL, UNIQUE) miała czym się
        # wypełnić. Taki adres nigdy nie posłuży do logowania e-mail/hasło.
        effective_email = email or f"apple_{apple_user_id}@privaterelay.local"
        user = User(
            email=effective_email,
            password_hash=get_password_hash(uuid.uuid4().hex),
            display_name=full_name or "Użytkownik Apple",
            apple_user_id=apple_user_id,
            is_email_verified=True,
        )
        db.add(user)

    await db.commit()
    await db.refresh(user)

    return {
        "access_token": create_access_token(data={"sub": str(user.id)}),
        "token_type": "bearer",
    }
