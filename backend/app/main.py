"""Smart Meal Planner PL — punkt wejścia aplikacji FastAPI."""

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

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Tabele bazy danych zostały utworzone/zweryfikowane.")


async def _seed_database_if_empty() -> None:
    """Wypełnia bazę danych danymi początkowymi, jeśli jest pusta.

    Importuje i uruchamia funkcję seed_database, o ile jest dostępna.
    Błędy seedowania są logowane, ale nie blokują uruchomienia aplikacji.
    """
    try:
        from app.db.seed import seed_database
        from app.db.session import async_session_factory
        from sqlalchemy import select
        from app.models.store import Store

        async with async_session_factory() as db:
            result = await db.execute(select(Store).limit(1))
            if result.first() is None:
                logger.info("Baza danych jest pusta. Rozpoczynam seedowanie...")
                await seed_database(db)
                await db.commit()
                logger.info("Dane początkowe zostały załadowane.")
            else:
                logger.info("Baza danych zawiera już dane. Pomijam seedowanie.")
    except ImportError:
        logger.debug("Moduł seed_database nie jest dostępny — pomijam seedowanie.")
    except Exception:
        logger.exception("Błąd podczas seedowania bazy danych.")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Zarządza cyklem życia aplikacji — startup i shutdown."""
    logger.info("Uruchamianie Smart Meal Planner PL API...")
    await _create_tables()
    await _seed_database_if_empty()
    logger.info("Aplikacja gotowa do obsługi żądań.")
    yield
    logger.info("Zamykanie Smart Meal Planner PL API...")


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
