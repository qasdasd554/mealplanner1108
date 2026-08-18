"""Smart Meal Planner PL — punkt wejścia aplikacji FastAPI."""

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1 import router as v1_router
from app.core.config import settings
from app.core.exceptions import AppException
from app.db.session import Base, get_db

logger = logging.getLogger(__name__)


async def _create_tables() -> None:
    """Tworzy tabele w bazie danych (tylko do celów deweloperskich)."""
    from app.db.session import engine
    from sqlalchemy import text

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        # UWAGA: create_all() tworzy TYLKO brakujące tabele — nie dokłada
        # nowych kolumn do tabel, które już istnieją. Kolumna `instructions`
        # została dodana do modelu Recipe już PO tym, jak tabela `recipes`
        # powstała na produkcji (Neon), więc trzeba ją dołożyć ręcznie.
        # IF NOT EXISTS sprawia, że to bezpieczne do uruchamiania przy
        # każdym starcie, także na świeżo utworzonej bazie.
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS instructions JSON")
        )
        await conn.execute(
            text(
                "ALTER TABLE store_products ADD COLUMN IF NOT EXISTS "
                "store_brand_name VARCHAR(100)"
            )
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS suggested_seasonings JSON")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user'")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT false")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS created_by_user_id UUID")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'private'")
        )
        await conn.execute(
            text("ALTER TABLE promotions ADD COLUMN IF NOT EXISTS review_status VARCHAR(20) NOT NULL DEFAULT 'approved'")
        )
    logger.info("Tabele bazy danych zostały utworzone/zweryfikowane.")


async def _seed_database_if_empty() -> None:
    """Synchronizuje dane początkowe (sklepy, produkty, przepisy).

    UWAGA: nazwa funkcji jest dziś myląca (historyczna) — `seed_database()`
    używa deterministycznych UUID i `session.merge()`, więc jest w pełni
    idempotentna: bezpiecznie AKTUALIZUJE istniejące rekordy (np. dokłada
    nowe przepisy, zdjęcia, instrukcje przygotowania) i niczego nie
    duplikuje. Wcześniej ta funkcja uruchamiała seed tylko wtedy, gdy
    tabela sklepów była pusta — na produkcyjnej bazie, która już miała
    dane, nowe przepisy z `seed.py` nigdy by się tam nie pojawiły.
    """
    try:
        from app.db.seed import seed_database
        from app.db.session import async_session_factory

        async with async_session_factory() as db:
            logger.info("Synchronizuję dane początkowe (seed)...")
            await seed_database(db)
            await db.commit()
            logger.info("Dane początkowe zsynchronizowane.")
    except ImportError:
        logger.debug("Moduł seed_database nie jest dostępny — pomijam seedowanie.")
    except Exception:
        logger.exception("Błąd podczas seedowania bazy danych.")


async def _run_price_scraper_once() -> None:
    """Uruchamia jeden przebieg scrapera cen i loguje wynik.

    Błędy są przechwytywane i logowane, ale nigdy nie przerywają działania
    aplikacji — aktualizacja cen jest funkcją dodatkową, nie krytyczną."""
    try:
        from app.db.session import async_session_factory
        from app.services.promo_scraper import scrape_and_update_prices

        async with async_session_factory() as db:
            await scrape_and_update_prices(db)
    except Exception:
        logger.exception("Scraper cen zakończył się błędem — ceny w bazie bez zmian.")


async def _price_scraper_background_loop() -> None:
    """Uruchamia scraper cen przy starcie, a potem cyklicznie co 12 godzin.

    UWAGA: to nie jest prawdziwy cron ani zewnętrzny scheduler (poprzednia
    wersja tego komentarza obiecywała APScheduler, który nigdy nie został
    dodany) — to zwykła pętla w tym samym procesie FastAPI. Działa tylko
    tak długo, jak długo żyje proces. Na darmowym planie Render usługa
    usypia po ~15 minutach bezczynności, więc pętla też wtedy przestaje
    działać — wznawia się (i od razu robi jeden przebieg) przy najbliższym
    obudzeniu usługi przez żądanie HTTP.
    """
    # Odczekaj chwilę po starcie, żeby nie kolidować z tworzeniem tabel/seedem.
    await asyncio.sleep(10)
    while True:
        await _run_price_scraper_once()
        await asyncio.sleep(12 * 60 * 60)  # 12 godzin


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Zarządza cyklem życia aplikacji — startup i shutdown."""
    logger.info("Uruchamianie Smart Meal Planner PL API...")
    await _create_tables()
    await _seed_database_if_empty()
    scraper_task = asyncio.create_task(_price_scraper_background_loop())
    logger.info("Aplikacja gotowa do obsługi żądań.")
    yield
    logger.info("Zamykanie Smart Meal Planner PL API...")
    scraper_task.cancel()


app = FastAPI(
    title="Smart Meal Planner PL API",
    description="API do planowania posiłków z integracją z polskimi sieciami handlowymi",
    version="1.0.0",
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------

# CORS
#
# Wcześniej było tu `allow_origins=["*"]` razem z `allow_credentials=True`.
# To niebezpieczna (i formalnie niepoprawna) kombinacja: pozwala dowolnej
# stronie w internecie wysyłać uwierzytelnione żądania do API w imieniu
# zalogowanego użytkownika wersji webowej.
#
# Aplikacja uwierzytelnia się nagłówkiem `Authorization: Bearer <token>`,
# a nie ciasteczkami, więc `allow_credentials` nie jest w ogóle potrzebne —
# wyłączenie go usuwa podatność bez utraty funkcjonalności.
#
# Aplikacja mobilna nie wysyła nagłówka Origin, więc CORS jej nie dotyczy.
# Dla wersji webowej ustaw konkretne domeny zmienną CORS_ORIGINS.
_cors_origins = settings.cors_origin_list
if settings.is_production and _cors_origins == ["*"]:
    logger.warning(
        "CORS_ORIGINS nie jest ustawione — API przyjmuje żądania z dowolnej "
        "domeny. Jeśli udostępniasz wersję webową, ustaw konkretne domeny."
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------


@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """Obsługuje wyjątki aplikacyjne i zwraca ustandaryzowaną odpowiedź JSON."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "error_code": exc.error_code,
        },
    )


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

app.include_router(v1_router, prefix=settings.API_V1_PREFIX)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------


@app.get(
    "/health",
    tags=["Health"],
    summary="Sprawdzenie stanu aplikacji i połączenia z bazą danych",
)
async def health_check() -> dict[str, str]:
    """Zwraca status zdrowia aplikacji oraz informację o bazie danych Neon."""
    db_provider = "Neon PostgreSQL" if "neon.tech" in settings.DATABASE_URL else "PostgreSQL"
    return {
        "status": "healthy",
        "service": "smart-meal-planner-pl",
        "database_provider": db_provider,
        "database_host": "ep-small-lab-b1y3gm3e.c-5.eu-central-1.aws.neon.tech" if "neon.tech" in settings.DATABASE_URL else "local",
    }
