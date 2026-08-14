"""Ograniczanie liczby prób logowania (ochrona przed atakiem siłowym).

Endpointy uwierzytelniania nie miały wcześniej żadnego limitu — można było
w nieskończoność odpytywać `/auth/login` kolejnymi hasłami.

Implementacja celowo nie wprowadza dodatkowej zależności ani Redisa:
licznik trzymany jest w pamięci procesu. Ograniczenia takiego podejścia:

* przy wielu instancjach aplikacji każda ma własny licznik,
* restart procesu zeruje liczniki.

Dla obecnego wdrożenia (pojedyncza instancja na Render) jest to wystarczające
i nieporównanie lepsze niż brak jakiegokolwiek limitu. Jeśli aplikacja
urośnie do wielu instancji, ten sam interfejs można oprzeć o Redis
(REDIS_URL jest już w konfiguracji).
"""

from __future__ import annotations

import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from app.core.config import settings


class SlidingWindowRateLimiter:
    """Licznik zdarzeń w przesuwnym oknie czasowym, bezpieczny wątkowo."""

    def __init__(self, max_events: int, window_seconds: int) -> None:
        self.max_events = max_events
        self.window_seconds = window_seconds
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def _prune(self, key: str, now: float) -> deque[float]:
        events = self._events[key]
        cutoff = now - self.window_seconds
        while events and events[0] < cutoff:
            events.popleft()
        return events

    def seconds_until_allowed(self, key: str) -> int:
        """0 jeśli akcja jest dozwolona, inaczej liczba sekund do odblokowania."""
        now = time.monotonic()
        with self._lock:
            events = self._prune(key, now)
            if len(events) < self.max_events:
                return 0
            return max(1, int(self.window_seconds - (now - events[0])) + 1)

    def register_failure(self, key: str) -> None:
        """Zapisuje nieudaną próbę."""
        now = time.monotonic()
        with self._lock:
            self._prune(key, now)
            self._events[key].append(now)

    def reset(self, key: str) -> None:
        """Czyści licznik — wywoływane po udanym logowaniu."""
        with self._lock:
            self._events.pop(key, None)

    def cleanup(self, max_keys: int = 10_000) -> None:
        """Zabezpieczenie przed rozrostem pamięci przy ataku z wielu adresów."""
        with self._lock:
            if len(self._events) <= max_keys:
                return
            now = time.monotonic()
            cutoff = now - self.window_seconds
            stale = [
                k for k, v in self._events.items() if not v or v[-1] < cutoff
            ]
            for k in stale:
                self._events.pop(k, None)


login_limiter = SlidingWindowRateLimiter(
    max_events=settings.RATE_LIMIT_LOGIN_ATTEMPTS,
    window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
)

# Zakładanie kont: limit liczony od KAŻDEJ próby (nie tylko nieudanej),
# żeby ograniczyć masowe tworzenie kont z jednego adresu.
signup_limiter = SlidingWindowRateLimiter(
    max_events=settings.RATE_LIMIT_SIGNUP_ATTEMPTS,
    window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
)

# Logowanie przez Google: bez limitu każdy mógłby bombardować endpoint
# tokenami, wymuszając kosztowną weryfikację po stronie Google przy każdej
# próbie — limit po IP, jak przy zwykłym logowaniu.
google_auth_limiter = SlidingWindowRateLimiter(max_events=10, window_seconds=300)

# Ręczne wywołanie scrapera cen: NAJBARDZIEJ newralgiczny endpoint w całej
# aplikacji z punktu widzenia nadużyć — bez limitu zalogowany użytkownik
# mógłby w pętli wysyłać żądania, które wykonują PRAWDZIWE zapytania HTTP
# do stron Biedronki/Lidla/Dino (ryzyko zbanowania adresu IP serwera przez
# te strony) i przy okazji obciążają bazę danych. Limit liczony PO
# UŻYTKOWNIKU (nie po IP), bo to endpoint wymagający zalogowania.
scraper_run_limiter = SlidingWindowRateLimiter(max_events=1, window_seconds=300)

# Generowanie planu posiłków: kosztowna operacja (przeszukuje cały katalog
# przepisów, liczy scoring, buduje listę zakupów) — limit chroni przed
# zalogowanym użytkownikiem zasypującym serwer żądaniami generowania.
meal_plan_generation_limiter = SlidingWindowRateLimiter(max_events=15, window_seconds=3600)

# Dodawanie komentarzy: ochrona przed spamem (w tym spamem zdjęciami,
# które trafiają bezpośrednio do bazy danych).
comment_creation_limiter = SlidingWindowRateLimiter(max_events=30, window_seconds=3600)


def client_key(request: Request, suffix: str = "") -> str:
    """Klucz licznika na podstawie adresu IP klienta.

    Render (jak każdy PaaS) stoi za proxy, więc prawdziwy adres klienta jest
    w nagłówku X-Forwarded-For; `request.client.host` zwróciłby adres proxy,
    czyli wspólny dla wszystkich użytkowników.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        ip = forwarded.split(",")[0].strip()
    else:
        ip = request.client.host if request.client else "unknown"
    return f"{ip}:{suffix}" if suffix else ip


def enforce_signup_rate_limit(request: Request) -> None:
    """Ogranicza liczbę zakładanych kont z jednego adresu IP."""
    key = client_key(request, "signup")
    signup_limiter.cleanup()
    retry_after = signup_limiter.seconds_until_allowed(key)
    if retry_after:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                "Zbyt wiele prób założenia konta. "
                f"Spróbuj ponownie za {retry_after} s."
            ),
            headers={"Retry-After": str(retry_after)},
        )
    signup_limiter.register_failure(key)


def enforce_login_rate_limit(request: Request) -> str:
    """Blokuje kolejne próby po przekroczeniu limitu. Zwraca klucz licznika."""
    key = client_key(request, "login")
    login_limiter.cleanup()
    retry_after = login_limiter.seconds_until_allowed(key)
    if retry_after:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                "Zbyt wiele nieudanych prób logowania. "
                f"Spróbuj ponownie za {retry_after} s."
            ),
            headers={"Retry-After": str(retry_after)},
        )
    return key


def enforce_google_auth_rate_limit(request: Request) -> None:
    """Ogranicza liczbę prób logowania przez Google z jednego adresu IP."""
    key = client_key(request, "google-auth")
    google_auth_limiter.cleanup()
    retry_after = google_auth_limiter.seconds_until_allowed(key)
    if retry_after:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Zbyt wiele prób. Spróbuj ponownie za {retry_after} s.",
            headers={"Retry-After": str(retry_after)},
        )
    google_auth_limiter.register_failure(key)


def enforce_user_rate_limit(limiter: SlidingWindowRateLimiter, user_id, action_name: str) -> None:
    """Ogólna funkcja egzekwująca limit PO UŻYTKOWNIKU (nie po IP) — do
    użycia na endpointach wymagających zalogowania, gdzie liczy się
    nadużycie konta, a nie samego adresu IP (który dla wielu użytkowników
    za tym samym NAT-em i tak byłby wspólny)."""
    key = str(user_id)
    limiter.cleanup()
    retry_after = limiter.seconds_until_allowed(key)
    if retry_after:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"Zbyt wiele prób ({action_name}). "
                f"Spróbuj ponownie za {retry_after} s."
            ),
            headers={"Retry-After": str(retry_after)},
        )
    limiter.register_failure(key)
