"""Konfiguracja asynchronicznej sesji SQLAlchemy."""

from collections.abc import AsyncGenerator

from sqlalchemy.engine.url import make_url
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

import ssl as ssl_module

# ── Przygotowanie adresu połączenia ──────────────────────────────
# Sterownik asyncpg NIE rozumie parametrów z URL-a w stylu libpq
# (`sslmode`, `channel_binding`) — trzeba je usunąć i przekazać SSL
# osobno, przez connect_args.
#
# UWAGA: wcześniej robiono to podmianą tekstową (`url.replace(...)`),
# co psuło adresy kopiowane z panelu Neon. Neon podaje dziś string
# w postaci:
#   ...neon.tech/neondb?sslmode=require&channel_binding=require
# Usunięcie samego "?sslmode=require" zostawiało
#   ...neon.tech/neondb&channel_binding=require
# czyli nazwę bazy "neondb&channel_binding=require" — połączenie
# kończyło się błędem "database does not exist". Teraz adres jest
# parsowany poprawnie, niezależnie od kolejności parametrów.
_url = make_url(settings.DATABASE_URL)

_libpq_only_params = ("sslmode", "channel_binding", "sslrootcert", "options")
_query = {k: v for k, v in _url.query.items() if k not in _libpq_only_params}
_needs_ssl = (
    "neon.tech" in (_url.host or "")
    or _url.query.get("sslmode") in ("require", "verify-ca", "verify-full")
)
_url = _url.set(query=_query)

connect_args: dict = {}
if _needs_ssl:
    connect_args["ssl"] = ssl_module.create_default_context()

_is_sqlite = _url.get_backend_name() == "sqlite"

# Parametry puli nie mają zastosowania do SQLite (używa NullPool).
_pool_kwargs: dict = (
    {}
    if _is_sqlite
    else {
        "pool_size": 5,
        "max_overflow": 10,
        # Neon usypia bazę po okresie bezczynności (autosuspend), a Render
        # w darmowym planie usypia serwis. Bez pool_pre_ping pierwsze
        # żądanie po przerwie trafiałoby na martwe połączenie z puli
        # i kończyło się błędem servera zamiast zwyczajnie się połączyć.
        "pool_pre_ping": True,
        # Odświeżaj połączenia co 5 minut — dodatkowe zabezpieczenie przed
        # zrywaniem połączeń po stronie Neona.
        "pool_recycle": 300,
    }
)

engine = create_async_engine(
    _url,
    echo=False,
    connect_args=connect_args,
    **_pool_kwargs,
)

async_session_factory = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Bazowa klasa deklaratywna dla wszystkich modeli ORM."""

    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dostawca sesji bazodanowej do wstrzykiwania zależności (Depends).

    Yields:
        Asynchroniczna sesja SQLAlchemy.
    """
    async with async_session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
