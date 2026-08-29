"""Konfiguracja aplikacji Smart Meal Planner PL.

Wszystkie ustawienia ładowane są ze zmiennych środowiskowych
z domyślnymi wartościami dla środowiska deweloperskiego.
"""

import logging

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)

# Wartość-wartownik. Jeśli zostanie w konfiguracji na produkcji, aplikacja
# celowo nie wystartuje (patrz _validate_production_secrets poniżej).
_PLACEHOLDER_SECRET = "CHANGE-ME-to-a-long-random-secret-in-production"


class Settings(BaseSettings):
    """Główna klasa konfiguracji aplikacji."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )

    # ── Baza danych ──────────────────────────────────────────────
    # WAŻNE: nie ma tu domyślnego connection stringa z prawdziwymi
    # poświadczeniami — musi być ustawiony przez zmienną środowiskową
    # DATABASE_URL (np. w panelu Render → Environment). Poprzednia wersja
    # tego pliku miała pełne hasło do bazy Neon zapisane wprost w kodzie
    # źródłowym — to był wyciek poświadczeń. Jeśli jeszcze tego nie
    # zrobiono, KONIECZNIE zresetuj hasło użytkownika bazy w panelu Neon.
    DATABASE_URL: str = (
        "postgresql+asyncpg://user:password@localhost:5432/smart_meal_planner"
    )

    # ── Redis / Celery ───────────────────────────────────────────
    REDIS_URL: str = "redis://localhost:6379/0"

    # ── Środowisko ───────────────────────────────────────────────
    # "production" (domyślnie) wymusza ustawienie prawdziwych sekretów.
    # Do pracy lokalnej ustaw ENVIRONMENT=development.
    ENVIRONMENT: str = "production"

    # ── JWT / Bezpieczeństwo ─────────────────────────────────────
    SECRET_KEY: str = _PLACEHOLDER_SECRET
    ALGORITHM: str = "HS256"
    # 30 dni — token o krótkim czasie życia (poprzednio 60 minut) był
    # główną przyczyną częstego, niechcianego wylogowywania użytkowników
    # z aplikacji mobilnej.
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30

    # ── Logowanie przez Google ───────────────────────────────────
    # Client ID typu "Web application" z Google Cloud Console — musi być
    # identyczny z tym używanym we frontendzie Flutter jako serverClientId
    # (lib/config/api_config.dart), bo to on jest odbiorcą (aud) w tokenie
    # id_token wystawianym przez Google.
    GOOGLE_WEB_CLIENT_ID: str = (
        "780793039743-6ap1jq18i31hqt04pf7gj8i4jip67uts.apps.googleusercontent.com"
    )

    # ── Dodawanie przepisów przez AI (funkcja Premium) ─────────────
    # Klucz API z aistudio.google.com (Google Gemini) — WYMAGANY, żeby
    # funkcja "dodaj przepis przez AI" w ogóle działała. Bez ustawienia
    # tej zmiennej środowiskowej na Render, endpoint /recipes/ai-import
    # zwróci czytelny błąd zamiast wywalać się niejasnym wyjątkiem.
    GEMINI_API_KEY: str = ""

    # ── Google Play Billing (subskrypcje) ───────────────────────────
    # Nazwa pakietu aplikacji w Google Play — np. "com.meal_planner_polska_v1".
    GOOGLE_PLAY_PACKAGE_NAME: str = ""
    # Pełna zawartość klucza JSON konta serwisowego Google Cloud (patrz
    # przewodnik konfiguracji płatności) — WYMAGANE, żeby backend mógł
    # zweryfikować zakup subskrypcji u Google. Bez tego endpoint
    # weryfikacji zakupu zwróci czytelny błąd zamiast się wywalić.
    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: str = ""

    # ── Apple App Store Server API (subskrypcje + punkty na iOS) ────
    # Bundle Identifier aplikacji na iOS — np. "com.meal-planner-polska-v1".
    APPLE_BUNDLE_ID: str = ""
    # Issuer ID i Key ID z App Store Connect (Users and Access ->
    # Integrations -> App Store Connect API) — WYMAGANE do podpisywania
    # zapytań do Apple. Bez tego endpoint weryfikacji zakupu na iOS
    # zwróci czytelny błąd zamiast się wywalić.
    APPLE_ISSUER_ID: str = ""
    APPLE_KEY_ID: str = ""
    # Pełna zawartość pliku klucza prywatnego .p8 pobranego z App Store
    # Connect przy tworzeniu klucza API — WAŻNE: ten plik da się pobrać
    # TYLKO RAZ, od razu po utworzeniu klucza, więc zachowaj go
    # bezpiecznie od razu przy generowaniu.
    APPLE_PRIVATE_KEY: str = ""

    # ── Wysyłka e-maili (weryfikacja konta) ─────────────────────────
    # Klucz API z resend.com — WYMAGANY, żeby wysyłka kodu weryfikacyjnego
    # przy rejestracji w ogóle działała. Bez tego rejestracja i tak
    # zadziała (konto się utworzy), ale użytkownik nie dostanie maila i
    # utknie na ekranie weryfikacji — patrz endpoint /auth/resend-code.
    RESEND_API_KEY: str = ""
    # Adres nadawcy z własnej, zweryfikowanej domeny Resend.
    RESEND_FROM_EMAIL: str = "Meal Planner Polska <powiadomienia@mealplannerpolska.pl>"

    # ── Aplikacja ────────────────────────────────────────────────
    APP_NAME: str = "Meal Planner Polska"
    # UWAGA: cała aplikacja Flutter (lib/config/api_config.dart) zakłada
    # prefiks "/api/v1" (podobnie jak docker-compose.yml). Poprzednia
    # wartość domyślna "/api" powodowała, że KAŻDE zapytanie z aplikacji
    # kończyło się błędem 404 — czyli aplikacja w praktyce nie działała
    # wcale, niezależnie od logowania. Jeśli w panelu Render jest ustawiona
    # zmienna środowiskowa API_V1_PREFIX na "/api", koniecznie ją usuń
    # albo zmień na "/api/v1", bo nadpisuje tę wartość domyślną.
    API_V1_PREFIX: str = "/api/v1"

    # ── CORS ─────────────────────────────────────────────────────
    # Lista dozwolonych źródeł rozdzielona przecinkami, np.
    #   CORS_ORIGINS=https://mojaaplikacja.pl,https://www.mojaaplikacja.pl
    # Aplikacja mobilna nie wysyła nagłówka Origin, więc CORS jej nie
    # dotyczy — to ustawienie ma znaczenie tylko dla wersji webowej.
    CORS_ORIGINS: str = "*"

    # ── Limity zapytań (ochrona przed łamaniem haseł) ─────────────
    # Maksymalna liczba nieudanych prób logowania z jednego adresu IP
    # w oknie czasowym RATE_LIMIT_WINDOW_SECONDS.
    RATE_LIMIT_LOGIN_ATTEMPTS: int = 10
    # Maksymalna liczba zakładanych kont z jednego adresu IP w tym samym oknie.
    RATE_LIMIT_SIGNUP_ATTEMPTS: int = 3

    # UWAGA (funkcja: powiadomienie o aktualizacji): numer wersji
    # (versionCode/buildNumber z pubspec.yaml, część po "+") najnowszej
    # opublikowanej aplikacji — AKTUALIZUJ RĘCZNIE przy każdym wydaniu
    # nowego builda do Play Console/App Store. Aplikacja porównuje SWÓJ
    # własny numer z tą wartością przy starcie i pokazuje delikatne
    # przypomnienie, jeśli jest starsza — nie blokuje korzystania,
    # tylko informuje.
    LATEST_APP_VERSION_CODE: int = 69
    RATE_LIMIT_WINDOW_SECONDS: int = 600

    @property
    def cors_origin_list(self) -> list[str]:
        """CORS_ORIGINS w postaci listy."""
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() not in ("development", "dev", "local", "test")

    @model_validator(mode="after")
    def _validate_production_secrets(self) -> "Settings":
        """Nie pozwala wystartować produkcji z sekretami z kodu źródłowego.

        Wcześniej `SECRET_KEY` miał działającą wartość domyślną — jeśli
        zmienna środowiskowa nie została ustawiona w panelu Render,
        aplikacja startowała normalnie, podpisując tokeny sesji sekretem
        znanym każdemu, kto widział kod. Każdy mógł wtedy wygenerować
        sobie token dowolnego użytkownika. Teraz taki start jest blokowany.
        """
        if not self.is_production:
            if self.SECRET_KEY == _PLACEHOLDER_SECRET:
                logger.warning(
                    "ENVIRONMENT=%s — używam domyślnego SECRET_KEY. "
                    "Na produkcji ustaw prawdziwy sekret.",
                    self.ENVIRONMENT,
                )
            return self

        problems: list[str] = []

        if self.SECRET_KEY == _PLACEHOLDER_SECRET:
            problems.append(
                "SECRET_KEY nie został ustawiony (wciąż ma wartość domyślną z kodu). "
                "Wygeneruj go poleceniem: openssl rand -hex 32"
            )
        elif len(self.SECRET_KEY) < 32:
            problems.append(
                f"SECRET_KEY jest za krótki ({len(self.SECRET_KEY)} znaków, minimum 32). "
                "Wygeneruj go poleceniem: openssl rand -hex 32"
            )

        if "localhost" in self.DATABASE_URL or "user:password" in self.DATABASE_URL:
            problems.append(
                "DATABASE_URL nie został ustawiony (wskazuje na lokalną bazę). "
                "Wklej connection string z panelu Neon."
            )

        if problems:
            raise RuntimeError(
                "Nie można uruchomić aplikacji w trybie produkcyjnym — "
                "brakuje wymaganej konfiguracji:\n  - "
                + "\n  - ".join(problems)
                + "\n\nUstaw te zmienne w panelu Render (Environment → Environment "
                "Variables). Do pracy lokalnej ustaw ENVIRONMENT=development."
            )

        return self


settings = Settings()
