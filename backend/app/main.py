"""Smart Meal Planner PL — punkt wejścia aplikacji FastAPI."""

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.gzip import GZipMiddleware
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

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
        # Przy pierwszym uruchomieniu po wprowadzeniu limitu zaliczamy
        # istniejące zwykłe plany. Archiwalne plany techniczne, tworzone
        # pod listy zakupów z przepisów, nie są planami posiłków.
        await conn.execute(text(
            "INSERT INTO meal_plan_creations "
            "(id, user_id, meal_plan_id, week_start, created_at) "
            "SELECT gen_random_uuid(), mp.user_id, mp.id, "
            "date_trunc('week', mp.created_at AT TIME ZONE 'Europe/Warsaw')::date, "
            "mp.created_at FROM meal_plans mp "
            "WHERE mp.status != 'archived' "
            "ON CONFLICT (meal_plan_id) DO NOTHING"
        ))
        # Historia utworzeń pozostaje po usunięciu listy. Włączając limit
        # tygodniowy na istniejącej bazie, zaliczamy też listy sprzed
        # aktualizacji (bez dublowania przy kolejnych startach serwera).
        await conn.execute(text(
            "INSERT INTO shopping_list_creations "
            "(id, user_id, shopping_list_id, week_start, created_at) "
            "SELECT gen_random_uuid(), mp.user_id, sl.id, "
            "date_trunc('week', sl.created_at AT TIME ZONE 'Europe/Warsaw')::date, "
            "sl.created_at FROM shopping_lists sl "
            "JOIN meal_plans mp ON mp.id = sl.meal_plan_id "
            "WHERE COALESCE(mp.preferences->>'shopping_list_merge', 'false') != 'true' "
            "ON CONFLICT (shopping_list_id) DO NOTHING"
        ))
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
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_product_id VARCHAR(100)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_purchase_token TEXT")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_platform VARCHAR(20)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_last_verified_at TIMESTAMPTZ")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS weight_kg DOUBLE PRECISION")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS height_cm DOUBLE PRECISION")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS age INTEGER")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(10)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS activity_level VARCHAR(20)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS daily_kcal_goal INTEGER")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN NOT NULL DEFAULT false")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code VARCHAR(6)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code_expires_at TIMESTAMPTZ")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_code VARCHAR(6)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_code_expires_at TIMESTAMPTZ")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar VARCHAR(20)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_points INTEGER NOT NULL DEFAULT 0")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ")
        )
        # UWAGA (ważne): istniejący użytkownicy sprzed wprowadzenia tej
        # funkcji NIE MOGĄ nagle stać się "niezweryfikowani" i zostać
        # zablokowani — kolumna is_email_verified dodana wyżej domyślnie
        # ustawia WSZYSTKICH na false. To uzupełnienie oznacza jako
        # zweryfikowane WYŁĄCZNIE konta, które nigdy nie dostały kodu
        # weryfikacyjnego (bo funkcja jeszcze nie istniała, gdy się
        # rejestrowali) — nowe, faktycznie oczekujące na weryfikację konta
        # ZAWSZE mają ustawiony kod i datę wygaśnięcia, więc ten warunek
        # ich nie obejmie. Bezpieczne do uruchamiania przy każdym starcie
        # (drugi raz nic już nie zmienia).
        await conn.execute(
            text(
                "UPDATE users SET is_email_verified = true "
                "WHERE is_email_verified = false "
                "AND email_verification_code IS NULL "
                "AND email_verification_code_expires_at IS NULL"
            )
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS created_by_user_id UUID")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS import_job_id UUID")
        )
        await conn.execute(
            text("CREATE UNIQUE INDEX IF NOT EXISTS uq_recipes_import_job_id "
                 "ON recipes (import_job_id) WHERE import_job_id IS NOT NULL")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'private'")
        )
        await conn.execute(
            text("ALTER TABLE promotions ADD COLUMN IF NOT EXISTS review_status VARCHAR(20) NOT NULL DEFAULT 'approved'")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS photo_base64 TEXT")
        )
        # Sign in with Apple — patrz app/models/user.py, app/services/apple_sign_in.py.
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_user_id VARCHAR(255)")
        )
        await conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_apple_user_id "
                "ON users (apple_user_id) WHERE apple_user_id IS NOT NULL"
            )
        )
        # Platforma (ios/android) ostatniego żądania — patrz nagłówek
        # X-Platform w app/api/deps.py.
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS platform VARCHAR(10)")
        )
        # Blokada konta przez administratora — patrz app/models/user.py.
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN NOT NULL DEFAULT FALSE")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS ban_reason VARCHAR(500)")
        )
        # Zdjęcia przepisów oczekujące na moderację — patrz app/models/recipe.py.
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS pending_photo_base64 TEXT")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS pending_photo_user_id UUID")
        )
        await conn.execute(
            text("ALTER TABLE recipes ADD COLUMN IF NOT EXISTS pending_photo_submitted_at TIMESTAMPTZ")
        )
        # Tokeny urządzeń do powiadomień push — patrz
        # app/models/device_token.py. Tabela powstaje przez create_all,
        # ale UNIQUE na tokenie dokładamy jawnie, bo create_all nie
        # dodaje ograniczeń do TABEL, KTÓRE JUŻ ISTNIEJĄ.
        await conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_device_tokens_token "
                "ON device_tokens (token)"
            )
        )
        await conn.execute(
            text(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS "
                "onboarding_bonus_claimed BOOLEAN NOT NULL DEFAULT FALSE"
            )
        )
        # Produkty zgłaszane przez użytkowników — patrz app/models/product.py.
        # Domyślne "approved" sprawia, że istniejące produkty katalogowe
        # pozostają widoczne bez żadnej migracji danych.
        await conn.execute(
            text("ALTER TABLE products ADD COLUMN IF NOT EXISTS created_by_user_id UUID")
        )
        await conn.execute(
            text(
                "ALTER TABLE products ADD COLUMN IF NOT EXISTS "
                "review_status VARCHAR(20) NOT NULL DEFAULT 'approved'"
            )
        )
        await conn.execute(
            text("ALTER TABLE products ADD COLUMN IF NOT EXISTS submitted_price NUMERIC(10,2)")
        )
        # Zdjęcie profilowe użytkownika — patrz app/models/user.py.
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_photo_base64 TEXT")
        )
        # Kampanie zakupowe powstały najpierw wyłącznie dla Apple. Te
        # kolumny rozszerzają istniejącą tabelę o oferty Google Play bez
        # usuwania ani dezaktywowania wcześniejszych kampanii iOS.
        await conn.execute(text(
            "ALTER TABLE purchase_campaigns ADD COLUMN IF NOT EXISTS "
            "platform VARCHAR(20) NOT NULL DEFAULT 'ios'"
        ))
        await conn.execute(text(
            "ALTER TABLE purchase_campaigns ALTER COLUMN ios_offer_url DROP NOT NULL"
        ))
        await conn.execute(text(
            "ALTER TABLE purchase_campaigns ADD COLUMN IF NOT EXISTS "
            "android_base_plan_id VARCHAR(120)"
        ))
        await conn.execute(text(
            "ALTER TABLE purchase_campaigns ADD COLUMN IF NOT EXISTS "
            "android_offer_id VARCHAR(120)"
        ))
        # Proponowane sklepy przy zgłoszeniu produktu — patrz
        # app/models/product.py.
        await conn.execute(
            text("ALTER TABLE products ADD COLUMN IF NOT EXISTS requested_store_ids JSON")
        )
        # Porcja/opakowanie rozpoznane z Open Food Facts albo etykiety AI.
        # Kolumna jest opcjonalna, więc wdrożenie nie zmienia istniejących
        # rekordów cache i nie blokuje startu aplikacji.
        await conn.execute(
            text(
                "ALTER TABLE barcode_product_cache ADD COLUMN IF NOT EXISTS "
                "serving_quantity DOUBLE PRECISION"
            )
        )
        # Ręcznie wpisane pozycje listy zakupów (np. chemia domowa) nie
        # mają odpowiednika w katalogu spożywczym ani StoreProduct.
        await conn.execute(
            text(
                "ALTER TABLE shopping_list_items ADD COLUMN IF NOT EXISTS "
                "custom_name VARCHAR(200)"
            )
        )
        await conn.execute(
            text(
                "ALTER TABLE shopping_list_items "
                "ALTER COLUMN store_product_id DROP NOT NULL"
            )
        )
        await conn.execute(text(
            "ALTER TABLE shopping_list_items ADD COLUMN IF NOT EXISTS "
            "is_from_pantry BOOLEAN NOT NULL DEFAULT FALSE"
        ))
        # Jednorazowa migracja starych pozycji sklepowych. Ponowne
        # uruchomienie nie może zmienić ręcznie połączonych pozycji.
        await conn.execute(text(
            "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns "
            "WHERE table_name = 'shopping_list_items' AND column_name = 'is_generated') "
            "THEN ALTER TABLE shopping_list_items ADD COLUMN is_generated "
            "BOOLEAN NOT NULL DEFAULT FALSE; "
            "UPDATE shopping_list_items sli SET is_generated = TRUE "
            "FROM shopping_lists sl, meal_plan_entries mpe, "
            "recipe_ingredients ri, store_products sp "
            "WHERE sli.shopping_list_id = sl.id "
            "AND mpe.meal_plan_id = sl.meal_plan_id "
            "AND ri.recipe_id = mpe.recipe_id "
            "AND sp.id = sli.store_product_id "
            "AND sp.product_id = ri.product_id; END IF; END $$"
        ))
        # Nawodnienie: jeden wpis na użytkownika i dzień — patrz
        # app/models/wellness.py.
        await conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_water_logs_user_date "
                "ON water_logs (user_id, date)"
            )
        )
        # Historia wagi została dodana do istniejącej bazy przez create_all.
        # Sam model zawiera UNIQUE(user_id, date), ale create_all nie dodaje
        # ograniczenia do tabeli, która powstała we wcześniejszym wdrożeniu.
        # Najpierw zachowujemy najnowszy wpis z każdego dnia i usuwamy starsze
        # duplikaty, a dopiero potem zakładamy indeks. Bez sprzątania CREATE
        # UNIQUE INDEX przerwałby start aplikacji, jeśli duplikaty już istnieją.
        await conn.execute(
            text(
                "DELETE FROM weight_logs WHERE id IN ("
                "SELECT id FROM ("
                "SELECT id, ROW_NUMBER() OVER ("
                "PARTITION BY user_id, date "
                "ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC"
                ") AS duplicate_number FROM weight_logs"
                ") duplicates WHERE duplicate_number > 1"
                ")"
            )
        )
        await conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_weight_logs_user_date "
                "ON weight_logs (user_id, date)"
            )
        )
        # Znacznik "ta promocja nadpisała cenę katalogową" — patrz
        # app/services/promotion_expiry.py.
        await conn.execute(
            text(
                "ALTER TABLE promotions ADD COLUMN IF NOT EXISTS "
                "price_applied BOOLEAN NOT NULL DEFAULT FALSE"
            )
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


async def _backfill_missing_nutrition_totals() -> None:
    """Uzupełnia `nutrition_total` dla przepisów, które go nie mają.

    UWAGA (naprawa poważnego błędu): przepisy dodane ręcznie albo przez
    import AI nigdy nie zapisywały tej wartości w bazie — była liczona
    tylko "na żywo" przy odpowiedzi API (patrz ensure_nutrition w
    schemas/recipe.py), więc np. dziennik kalorii w Śledzeniu (który
    czyta `recipe.nutrition_total` bezpośrednio z bazy, z pominięciem
    tego mechanizmu) zawsze widział puste wartości odżywcze dla takich
    przepisów. Endpointy tworzenia przepisu są już naprawione i zapisują
    tę wartość od razu — ta funkcja jednorazowo uzupełnia przepisy, które
    ISTNIAŁY W BAZIE PRZED tą naprawą.
    """
    try:
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload

        from app.db.session import async_session_factory
        from app.models.recipe import Recipe, RecipeIngredient
        from app.services.nutrition_calculator import compute_recipe_nutrition_total

        async with async_session_factory() as db:
            # UWAGA (naprawa): filtrowanie `WHERE nutrition_total IS NULL`
            # na poziomie SQL nie wyłapywało wszystkich przypadków — dla
            # kolumn typu JSON, Python `None` bywa zapisany jako literał
            # JSON "null" (prawdziwa wartość JSON), a nie jako SQL NULL,
            # więc `.is_(None)` w zapytaniu SQL nie zawsze to dopasowuje.
            # Pobieramy więc WSZYSTKIE przepisy i sprawdzamy w Pythonie —
            # po deserializacji SQLAlchemy oba przypadki (SQL NULL i JSON
            # "null") stają się identycznie Python `None`, więc to
            # niezawodne niezależnie od tego, jak faktycznie jest
            # zapisane w bazie. Tabela przepisów nie jest na tyle duża
            # (dziesiątki/setki, nie miliony), żeby to było problemem
            # wydajnościowym przy starcie aplikacji.
            result = await db.execute(
                select(Recipe).options(
                    selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product)
                )
            )
            all_recipes = list(result.scalars().all())
            recipes = [r for r in all_recipes if not r.nutrition_total]

            # PRZELICZENIE po zmianie sposobu liczenia tłuszczu do
            # smażenia (patrz _edible_grams w nutrition_calculator.py).
            # Przepisy, które mają już zapisane `nutrition_total`, nie
            # zostałyby ruszone przez powyższy warunek, więc smażone dania
            # zostałyby ze starą, mocno zawyżoną kalorycznością. Bierzemy
            # tylko te, w których faktycznie występuje tłuszcz smażalniczy
            # — nie ma powodu przeliczać całego katalogu.
            from app.services.nutrition_calculator import FRYING_FATS

            already_selected = {r.id for r in recipes}
            for r in all_recipes:
                if r.id in already_selected:
                    continue
                has_frying_fat = any(
                    (ing.product.name or "").strip().lower() in FRYING_FATS
                    for ing in r.ingredients
                    if ing.product is not None
                )
                if has_frying_fat:
                    recipes.append(r)

            if not recipes:
                return
            for recipe in recipes:
                recipe.nutrition_total = compute_recipe_nutrition_total(recipe.ingredients)
            await db.commit()
            logger.info("Przeliczono nutrition_total dla %d przepisów.", len(recipes))
    except Exception:
        logger.exception("Błąd podczas uzupełniania nutrition_total.")


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


async def _weekly_contest_background_loop() -> None:
    """Sprawdza co godzinę, czy poprzedni tydzień konkursu przepisów
    czeka na rozliczenie (patrz app/services/weekly_contest.py) — jeśli
    tak, przyznaje punkty TOP 3 i wysyła powiadomienie do wszystkich.

    Tak samo jak _price_scraper_background_loop: zwykła pętla w tym
    samym procesie, nie prawdziwy cron. Odporne na usypianie usługi na
    darmowym planie Render — funkcja process_weekly_contest_payout
    sama sprawdza, CZY dany tydzień był już rozliczony, więc niezależnie
    od tego, o której dokładnie godzinie serwer się obudzi, poprawnie
    rozliczy zaległy tydzień przy najbliższej okazji.
    """
    await asyncio.sleep(30)
    while True:
        try:
            from app.db.session import async_session_factory
            from app.services.weekly_contest import process_weekly_contest_payout

            async with async_session_factory() as db:
                result = await process_weekly_contest_payout(db)
                if result is not None:
                    logger.info("Konkurs tygodniowy: rozliczono tydzień %s", result.week_start_date)
        except Exception:
            logger.exception("Błąd przy rozliczaniu konkursu tygodniowego")
        await asyncio.sleep(60 * 60)  # 1 godzina


async def _promotion_expiry_background_loop() -> None:
    """Cofa ceny promocyjne po wygaśnięciu promocji (patrz
    app/services/promotion_expiry.py). Ten sam wzorzec co pozostałe
    zadania w tle — zwykła pętla w procesie aplikacji, bez osobnego
    workera, bo darmowy plan Render go nie przewiduje. Operacja jest
    idempotentna (znacznik `price_applied` zdejmowany po przetworzeniu),
    więc wielokrotne uruchomienie niczego nie psuje.
    """
    await asyncio.sleep(45)
    while True:
        try:
            from app.db.session import async_session_factory
            from app.services.promotion_expiry import restore_expired_promotion_prices

            async with async_session_factory() as db:
                restored = await restore_expired_promotion_prices(db)
                if restored:
                    logger.info("Przywrócono ceny regularne dla %d produktów.", restored)
        except Exception:
            logger.exception("Błąd przy przywracaniu cen po wygasłych promocjach")
        await asyncio.sleep(60 * 60)  # 1 godzina


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Zarządza cyklem życia aplikacji — startup i shutdown."""
    logger.info("Uruchamianie Smart Meal Planner PL API...")
    await _create_tables()
    await _seed_database_if_empty()
    await _backfill_missing_nutrition_totals()
    scraper_task = asyncio.create_task(_price_scraper_background_loop())
    weekly_contest_task = asyncio.create_task(_weekly_contest_background_loop())
    promotion_expiry_task = asyncio.create_task(_promotion_expiry_background_loop())
    from app.services.recipe_import_worker import recipe_import_worker_loop

    recipe_import_task = asyncio.create_task(recipe_import_worker_loop())
    logger.info("Aplikacja gotowa do obsługi żądań.")
    yield
    logger.info("Zamykanie Smart Meal Planner PL API...")
    scraper_task.cancel()
    weekly_contest_task.cancel()
    promotion_expiry_task.cancel()
    recipe_import_task.cancel()


app = FastAPI(
    title="Smart Meal Planner PL API",
    description="API do planowania posiłków z integracją z polskimi sieciami handlowymi",
    version="1.0.32",
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------

# Kompresuj większe odpowiedzi JSON, w tym listy przepisów ze zdjęciami.
# Flutter rozpakowuje gzip automatycznie, więc format API się nie zmienia.
app.add_middleware(GZipMiddleware, minimum_size=1000, compresslevel=5)

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
@app.head("/health", include_in_schema=False)
async def health_check(db: AsyncSession = Depends(get_db)) -> dict[str, str]:
    """Zwraca status zdrowia aplikacji oraz informację o bazie danych Neon."""
    from app.models.product import Product

    db_provider = "Neon PostgreSQL" if "neon.tech" in settings.DATABASE_URL else "PostgreSQL"
    catalog_products = await db.scalar(select(func.count(Product.id))) or 0
    return {
        "status": "healthy",
        "service": "smart-meal-planner-pl",
        "release": "1.0.32+229",
        "catalog_products": str(catalog_products),
        "database_provider": db_provider,
        "database_host": "ep-small-lab-b1y3gm3e.c-5.eu-central-1.aws.neon.tech" if "neon.tech" in settings.DATABASE_URL else "local",
    }


@app.get(
    "/app/version-info",
    tags=["Health"],
    summary="Numer najnowszej opublikowanej wersji aplikacji",
)
async def app_version_info(platform: str | None = None) -> dict:
    """Publiczny (bez logowania) endpoint sprawdzany przez aplikację przy
    starcie. Aplikacja przesyła swoją platformę (`?platform=ios` albo
    `android`) i porównuje własny numer builda z odpowiednim progiem.

    Zwraca też adres do sklepu WŁAŚCIWEGO dla platformy — wcześniej był
    tu wyłącznie link do Google Play, więc użytkownik iOS dostałby link,
    którego nie da się otworzyć na jego urządzeniu.
    """
    is_ios = (platform or "").lower() == "ios"
    return {
        # Zachowane dla zgodności ze starszymi wersjami aplikacji, które
        # jeszcze nie wysyłają parametru `platform` i czytają to pole.
        "latest_version_code": settings.LATEST_APP_VERSION_CODE,
        "play_store_url": "https://play.google.com/store/apps/details?id=com.meal_planner_polska_v1",
        # Nowe, rozdzielone na platformy.
        "latest_build_number": (
            settings.LATEST_IOS_BUILD_NUMBER if is_ios else settings.LATEST_ANDROID_VERSION_CODE
        ),
        "force_update": (
            settings.FORCE_UPDATE_IOS if is_ios else settings.FORCE_UPDATE_ANDROID
        ),
        "store_url": (
            "https://apps.apple.com/app/id6806607230"
            if is_ios
            else "https://play.google.com/store/apps/details?id=com.meal_planner_polska_v1"
        ),
    }
