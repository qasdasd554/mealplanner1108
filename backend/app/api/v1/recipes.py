"""Endpointy przepisów kulinarnych."""

import logging
import time
from datetime import datetime, timedelta, timezone
import re
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, field_validator
from sqlalchemy import and_, delete, exists, func, nullslast, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import load_only, selectinload

from app.api.deps import get_current_admin, get_current_premium, get_current_user
from app.core.exceptions import NotFoundException
from app.core.markets import account_country, MarketCode
from app.db.session import get_db
from app.models import (
    Friendship,
    Product,
    Recipe,
    RecipeIngredient,
    RecipeTag,
    StoreProduct,
    User,
)
from app.schemas.moderation import ContentReportCreate, ContentReportResponse
from app.schemas.recipe import (
    AIRecipeEditRequest,
    AIRecipeImportRequest,
    RecipeCreate,
    RecipeListItemResponse,
    RecipeResponse,
    RecipeVariantCreate,
)
from app.services.moderation import get_blocked_user_ids
from app.services.nutrition_calculator import compute_recipe_nutrition_total, is_ingredient_quantity_reasonable
from app.services.recipe_photo_thumbnail import create_recipe_photo_thumbnail
from app.services.market_catalog import (
    apply_recipe_market_filter,
    ensure_recipe_available_in_market,
    recipe_market_availability,
)
from app.services.store_market_access import get_store_in_account_market

router = APIRouter()
logger = logging.getLogger(__name__)


def _product_has_complete_nutrition(product: Product) -> bool:
    from app.services.recipe_ingredient_catalogue import has_recipe_nutrition
    return has_recipe_nutrition(product)


async def _validate_recipe_ingredient_products(
    db: AsyncSession,
    ingredients,
    user_id: UUID,
) -> dict[UUID, Product]:
    """Ładuje dozwolone produkty i odrzuca składniki, których nie da się policzyć."""
    requested_ids = {ingredient.product_id for ingredient in ingredients}
    if not requested_ids:
        return {}
    result = await db.execute(
        select(Product).where(
            Product.id.in_(requested_ids),
            or_(
                Product.review_status == "approved",
                Product.created_by_user_id == user_id,
            ),
        )
    )
    products = {product.id: product for product in result.scalars().all()}
    missing_ids = requested_ids - products.keys()
    if missing_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "Nie znaleziono dostępnego produktu/produktów: "
                f"{', '.join(str(item) for item in missing_ids)}"
            ),
        )
    for ingredient in ingredients:
        product = products[ingredient.product_id]
        source = (product.nutrition_per_100 or {}).get("_source", {})
        private_missing = (product.created_by_user_id == user_id
            and isinstance(source, dict) and source.get("provider") == "unresolved_recipe_ingredient")
        if not _product_has_complete_nutrition(product) and not private_missing:
            raise HTTPException(
                status_code=422,
                detail=(
                    f'Produkt "{product.name}" nie ma pełnych wartości '
                    "odżywczych. Uzupełnij dane z etykiety."
                ),
            )
        if ingredient.unit == "opak" and not product.serving_quantity:
            raise HTTPException(
                status_code=422,
                detail=(
                    f'Nie znamy masy całego opakowania produktu "{product.name}". '
                    "Wybierz gramy lub mililitry."
                ),
            )
    return products


async def _get_favorite_recipe_ids(
    db: AsyncSession,
    user_id: UUID,
    recipe_ids: set[UUID] | None = None,
) -> set[UUID]:
    """Zwraca zbiór ID przepisów, które użytkownik ma w ulubionych."""
    from app.models import RecipeFavorite

    query = select(RecipeFavorite.recipe_id).where(RecipeFavorite.user_id == user_id)
    if recipe_ids is not None:
        if not recipe_ids:
            return set()
        query = query.where(RecipeFavorite.recipe_id.in_(recipe_ids))
    result = await db.execute(query)
    return set(result.scalars().all())


def _kcal_per_serving_expr():
    """Wyrażenie SQL: kalorie przypadające na JEDNĄ porcję (czyli na
    jedną osobę), a nie na cały przepis.

    `nutrition_total` to suma dla całego dania, więc sortowanie po samej
    tej wartości stawiałoby wysoko duże, wieloporcjowe przepisy — dzielimy
    przez `servings`, żeby porównywać to, co użytkownik faktycznie zje.

    NULLIF chroni przed dzieleniem przez zero, gdyby jakiś przepis miał
    servings = 0 (nie powinien, kolumna ma default 2, ale dzielenie przez
    zero wywaliłoby całe zapytanie, nie tylko ten jeden wiersz).
    """
    return Recipe.nutrition_total["kcal"].as_float() / func.nullif(Recipe.servings, 0)


def _apply_recipe_sort(query, sort_by: str, *, country_code: str = "PL"):
    """Dokłada sortowanie do zapytania o przepisy.

    Przepisy bez policzonych wartości odżywczych (`nutrition_total` puste
    — dotyczy głównie starszych wpisów sprzed wprowadzenia automatycznego
    liczenia) trafiają na KONIEC listy przy sortowaniu po kaloriach,
    zamiast udawać "0 kcal" i fałszywie zajmować pierwsze miejsca.
    """
    display_name = Recipe.name
    if country_code == "GB":
        from app.services.system_content_language import english_system_name_order
        display_name = english_system_name_order(Recipe, kind="recipes")
    if sort_by == "kcal_asc":
        return query.order_by(nullslast(_kcal_per_serving_expr().asc()), display_name, Recipe.id)
    if sort_by == "kcal_desc":
        return query.order_by(nullslast(_kcal_per_serving_expr().desc()), display_name, Recipe.id)
    if sort_by == "prep_time":
        return query.order_by(nullslast(Recipe.prep_time_min.asc()), display_name, Recipe.id)
    return query.order_by(display_name, Recipe.id)


def _recipe_list_options():
    """Ładuje tylko pola potrzebne kafelkom listy.

    Szczególnie ważne jest pominięcie ``photo_base64`` (do 3 MB na jeden
    przepis), instrukcji i relacji składników. Pełny przepis jest już
    pobierany po wejściu w jego szczegóły.
    """
    return (
        load_only(
            Recipe.id,
            Recipe.name,
            Recipe.description,
            Recipe.cuisine,
            Recipe.meal_type,
            Recipe.prep_time_min,
            Recipe.cook_time_min,
            Recipe.servings,
            Recipe.difficulty,
            Recipe.nutrition_total,
            Recipe.image_url,
            Recipe.photo_thumbnail_base64,
            Recipe.is_active,
            Recipe.created_at,
            Recipe.visibility,
            Recipe.created_by_user_id,
        ),
        selectinload(Recipe.tags),
        selectinload(Recipe.creator).load_only(
            User.id, User.display_name, User.avatar, User.tiktok_username,
            User.role, User.is_premium, User.premium_product_id, User.premium_expires_at,
        ).raiseload("*"),
    )


def _visibility_filter(current_user_id: UUID, blocked_user_ids: set[UUID] | None = None):
    """Warunek widoczności przepisu:
    - wspólny katalog (created_by_user_id puste — 81 oficjalnych) LUB
    - własny przepis (dowolny status — prywatny, oczekujący, odrzucony) LUB
    - cudzy przepis zaakceptowany do wspólnego katalogu (visibility="public")

    `blocked_user_ids` (opcjonalne, dla list widocznych szerzej niż tylko
    własne przepisy) dodatkowo wyklucza autorów, których bieżący
    użytkownik zablokował — Apple Guideline 1.2: zablokowany użytkownik
    nie może dalej pokazywać się zablokowanej osobie.
    """
    base = or_(
        Recipe.created_by_user_id.is_(None),
        Recipe.created_by_user_id == current_user_id,
        Recipe.visibility == "public",
    )
    if blocked_user_ids:
        return and_(base, Recipe.created_by_user_id.not_in(blocked_user_ids))
    return base


def _recipe_search_filter(search: str, *, country_code: str = "PL"):
    """Dopasowuje jedno pole wyszukiwania do przepisu, autora i składnika.

    Skorelowane ``EXISTS`` nie mnożą rekordów przepisu (jak zwykłe JOIN-y),
    więc paginacja nadal zwraca dokładnie 30 różnych kart i nie wymaga
    pobierania ciężkiej relacji składników. Znaki LIKE wpisane przez
    użytkownika traktujemy dosłownie.
    """
    escaped = (
        search.strip()
        .replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )
    pattern = f"%{escaped}%"
    product_name_match = Product.name.ilike(pattern, escape="\\")
    translated_title_match = None
    if country_code == "GB":
        from app.services.system_content_language import english_system_name_match

        product_name_match = or_(product_name_match,
            english_system_name_match(Product, search, kind="ingredients"))
        translated_title_match = english_system_name_match(Recipe, search, kind="recipes")
    author_match = exists(
        select(1).where(
            User.id == Recipe.created_by_user_id,
            or_(
                User.display_name.ilike(pattern, escape="\\"),
                User.tiktok_username.ilike(pattern, escape="\\"),
            ),
        )
    )
    ingredient_match = exists(
        select(1)
        .select_from(RecipeIngredient)
        .join(Product, Product.id == RecipeIngredient.product_id)
        .where(
            RecipeIngredient.recipe_id == Recipe.id,
            product_name_match,
        )
    )
    conditions = [
        Recipe.name.ilike(pattern, escape="\\"),
        author_match,
        ingredient_match,
    ]
    if translated_title_match is not None:
        conditions.append(translated_title_match)
    return or_(*conditions)


@router.get(
    "/",
    response_model=list[RecipeListItemResponse],
    summary="Lista przepisów z filtrami",
)
async def list_recipes(
    meal_type: str | None = Query(None, description="Typ posiłku: breakfast, lunch, dinner, snack"),
    cuisine: str | None = Query(None, description="Kuchnia np. polska, włoska"),
    difficulty: str | None = Query(None, description="Poziom trudności: easy, medium, hard"),
    tags: list[str] | None = Query(None, description="Tagi do filtrowania"),
    max_prep_time: int | None = Query(None, ge=1, description="Maksymalny czas przygotowania w minutach"),
    search: str | None = Query(
        None,
        description="Szukaj po nazwie przepisu, autorze lub składniku",
    ),
    favorites_only: bool = Query(False, description="Pokaż tylko przepisy dodane do ulubionych"),
    new_only: bool = Query(False, description="Pokaż przepisy z ostatnich 14 dni"),
    # Przepisy dodane przez społeczność — publiczne, ale NIE część
    # oryginalnych 81 oficjalnych przepisów dostarczonych z aplikacją
    # (te mają created_by_user_id puste).
    community_only: bool = Query(False, description="Pokaż tylko przepisy dodane przez społeczność"),
    sort_by: str = Query(
        "name",
        description=(
            "Sortowanie: 'name' (domyślne, alfabetycznie), "
            "'kcal_asc' / 'kcal_desc' (kalorie na jedną porcję, czyli na osobę), "
            "'prep_time' (najszybsze najpierw)"
        ),
    ),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    """Zwraca listę przepisów z możliwością filtrowania.

    Obsługuje filtrowanie po typie posiłku, kuchni, trudności,
    tagach, maksymalnym czasie przygotowania oraz wyszukiwanie pełnotekstowe.
    """
    blocked_ids = await get_blocked_user_ids(db, current_user.id)
    query = select(Recipe).options(*_recipe_list_options()).where(
        _visibility_filter(current_user.id, blocked_ids)
    )
    query = apply_recipe_market_filter(query, current_user)

    if meal_type is not None:
        query = query.where(Recipe.meal_type == meal_type)

    if cuisine is not None:
        query = query.where(Recipe.cuisine.ilike(f"%{cuisine}%"))

    if difficulty is not None:
        query = query.where(Recipe.difficulty == difficulty)

    if max_prep_time is not None:
        query = query.where(Recipe.prep_time_min <= max_prep_time)

    if search and search.strip():
        query = query.where(_recipe_search_filter(search, country_code=account_country(current_user)))

    if community_only:
        query = query.where(Recipe.created_by_user_id.is_not(None), Recipe.visibility == "public")

    if tags:
        query = query.where(Recipe.tags.any(RecipeTag.tag.in_(tags)))

    if new_only:
        query = query.where(Recipe.created_at >= datetime.now(timezone.utc) - timedelta(days=14))

    favorite_ids: set[UUID] = set()
    if favorites_only:
        favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
        if not favorite_ids:
            return []
        query = query.where(Recipe.id.in_(favorite_ids))

    query = _apply_recipe_sort(query, sort_by, country_code=account_country(current_user)).offset(skip).limit(limit)

    result = await db.execute(query)
    recipes = list(result.unique().scalars().all())

    if not favorites_only:
        favorite_ids = await _get_favorite_recipe_ids(
            db,
            current_user.id,
            {recipe.id for recipe in recipes},
        )

    for recipe in recipes:
        recipe.is_favorite = recipe.id in favorite_ids
        recipe.is_own_recipe = recipe.created_by_user_id == current_user.id

    return recipes


@router.get(
    "/available",
    response_model=list[RecipeResponse],
    summary="Przepisy z dostępnymi składnikami",
)
async def list_available_recipes(
    store_id: UUID = Query(..., description="ID sklepu do sprawdzenia dostępności"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    """Zwraca przepisy, których wszystkie składniki są dostępne w danym sklepie.

    Dla każdego przepisu sprawdza, czy każdy wymagany produkt
    jest oznaczony jako dostępny (``is_available=True``) w wybranym sklepie.
    """
    if await get_store_in_account_market(db, store_id, current_user) is None:
        raise NotFoundException(detail="Sklep nie jest dostępny w kraju tego konta.")
    # Dostępność i paginację obsługuje baza. Wcześniej endpoint pobierał
    # wszystkie przepisy wraz ze składnikami, filtrował je w Pythonie i
    # dopiero potem wybierał stronę.
    available_product_ids = select(StoreProduct.product_id).where(
            StoreProduct.store_id == store_id,
            StoreProduct.is_available == True,  # noqa: E712
        )
    has_product_ingredient = exists(
        select(1).where(
            RecipeIngredient.recipe_id == Recipe.id,
            RecipeIngredient.product_id.is_not(None),
        )
    )
    has_unavailable_ingredient = exists(
        select(1).where(
            RecipeIngredient.recipe_id == Recipe.id,
            RecipeIngredient.product_id.is_not(None),
            RecipeIngredient.product_id.not_in(available_product_ids),
        )
    )

    # Keep the Polish result set unchanged. For UK choices use the same
    # required-ingredient predicate as the catalogue, scoped further to the
    # selected UK store; missing optional seasonings never exclude a dish.
    availability_conditions = (
        (recipe_market_availability("GB", store_id=store_id),)
        if account_country(current_user) == "GB"
        else (has_product_ingredient, ~has_unavailable_ingredient)
    )

    blocked_ids = await get_blocked_user_ids(db, current_user.id)
    recipes_result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(
            _visibility_filter(current_user.id, blocked_ids),
            *availability_conditions,
        )
        .order_by(Recipe.name)
        .offset(skip)
        .limit(limit)
    )
    available_recipes = list(recipes_result.unique().scalars().all())

    favorite_ids = await _get_favorite_recipe_ids(
        db,
        current_user.id,
        {recipe.id for recipe in available_recipes},
    )

    for recipe in available_recipes:
        recipe.is_favorite = recipe.id in favorite_ids
        recipe.is_own_recipe = recipe.created_by_user_id == current_user.id

    return available_recipes


@router.get(
    "/mine",
    response_model=list[RecipeListItemResponse],
    summary="Moje przepisy dodane przez AI",
)
async def list_my_recipes(
    sort_by: str = Query(
        "newest",
        description=(
            "Sortowanie: 'newest' (domyślne, najnowsze najpierw), 'name', "
            "'kcal_asc' / 'kcal_desc' (kalorie na porcję), 'prep_time'"
        ),
    ),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    new_only: bool = Query(False),
    favorites_only: bool = Query(False),
    search: str | None = Query(None),
    meal_type: str | None = Query(None),
    difficulty: str | None = Query(None),
    tags: list[str] | None = Query(None),
    community_only: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    """Zwraca WYŁĄCZNIE przepisy dodane przez zalogowanego użytkownika
    (przez AI) — nie miesza ich ze wspólnym katalogiem 81 oficjalnych
    przepisów.

    Obsługuje to samo sortowanie co główna lista: wcześniej ten endpoint
    ZAWSZE sortował po dacie dodania, przez co wybór "Kalorie: od
    najmniej" w interfejsie nie robił nic, gdy użytkownik miał włączony
    przełącznik "Moje" — wyglądało to jak zepsute sortowanie.
    """
    query = (
        select(Recipe)
        .options(*_recipe_list_options())
        .where(Recipe.created_by_user_id == current_user.id)
    )
    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
    if favorites_only:
        if not favorite_ids:
            return []
        query = query.where(Recipe.id.in_(favorite_ids))
    if new_only:
        query = query.where(Recipe.created_at >= datetime.now(timezone.utc) - timedelta(days=14))
    if search and search.strip():
        query = query.where(_recipe_search_filter(search, country_code=account_country(current_user)))
    if meal_type:
        query = query.where(Recipe.meal_type == meal_type)
    if difficulty:
        query = query.where(Recipe.difficulty == difficulty)
    if tags:
        query = query.where(Recipe.tags.any(RecipeTag.tag.in_(tags)))
    if community_only:
        query = query.where(Recipe.visibility == "public")
    # Domyślne "newest" jest specyficzne dla tego widoku (własne przepisy
    # najwygodniej oglądać od ostatnio dodanych), pozostałe tryby są
    # wspólne z główną listą.
    if sort_by == "newest":
        query = query.order_by(Recipe.created_at.desc(), Recipe.id)
    else:
        query = _apply_recipe_sort(query, sort_by, country_code=account_country(current_user))

    result = await db.execute(query.offset(skip).limit(limit))
    recipes = list(result.unique().scalars().all())
    for recipe in recipes:
        recipe.is_favorite = recipe.id in favorite_ids
        recipe.is_own_recipe = True
    return recipes


@router.get(
    "/ai-status",
    summary="Sprawdź stan klucza/limitów Gemini API (admin)",
)
async def get_ai_status(
    current_user: User = Depends(get_current_admin),
) -> dict:
    """Proaktywnie sprawdza, czy klucz Gemini API działa i czy limity
    tokenów/zapytań nie zostały wyczerpane — zanim natrafi na to
    prawdziwy użytkownik próbujący dodać przepis przez AI. Sprawdza
    KAŻDY model z osobna (każdy ma własny, niezależny limit)."""
    from app.services.gemini_status import check_gemini_status

    return await check_gemini_status()


@router.get(
    "/{recipe_id}",
    response_model=RecipeResponse,
    summary="Szczegóły przepisu",
)
async def get_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Zwraca szczegóły przepisu wraz ze składnikami."""
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
            # Do wyświetlenia "Dodane przez [nazwa]" na ekranie
            # szczegółów — patrz attach_creator_info w schemas/recipe.py.
            selectinload(Recipe.creator),
        )
        .where(Recipe.id == recipe_id)
    )
    recipe = result.scalar_one_or_none()
    if recipe is None:
        raise NotFoundException(
            detail=f"Przepis o ID {recipe_id} nie został znaleziony"
        )
    # Prywatny/oczekujący przepis może zobaczyć właściciel, administrator
    # wykonujący moderację oraz zaakceptowany znajomy. Wcześniej administrator
    # dostawał 404 po wejściu ze swojej listy „do akceptacji”, więc ekran
    # szczegółów nie mógł odświeżyć pełnych danych przed decyzją.
    # Dla wszystkich pozostałych zachowujemy 404, żeby nie ujawniać nawet
    # samego faktu istnienia prywatnej treści.
    from app.services.recipe_access import ensure_recipe_access

    await ensure_recipe_access(db, recipe, current_user)
    is_own = recipe.created_by_user_id == current_user.id
    # Owners retain recovery/editing access to their own private imports.
    # Administrators must also be able to inspect a recipe before approval.
    if not is_own and getattr(current_user, "role", None) != "admin":
        await ensure_recipe_available_in_market(db, recipe, current_user)
    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
    recipe.is_favorite = recipe.id in favorite_ids
    recipe.is_own_recipe = is_own
    return recipe


@router.post(
    "/",
    response_model=RecipeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Utwórz nowy przepis ręcznie",
)
async def create_recipe(
    recipe_in: RecipeCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Tworzy nowy przepis ręcznie wprowadzony przez użytkownika.

    Domyślnie przepis jest PRYWATNY — widoczny tylko dla twórcy, tak jak
    przepisy dodawane przez AI. Jeśli `request_public=True`, przepis
    zostaje zgłoszony do wspólnego katalogu widocznego dla wszystkich —
    wymaga to TYLKO akceptacji administratora, zanim faktycznie stanie
    się publiczny (patrz PUT /recipes/{id}/approve).

    NAPRAWA: wcześniej to zgłoszenie wymagało konta Premium. Zgłaszanie
    do wspólnego katalogu — a tym samym udział w cotygodniowym konkursie
    (ranking liczy WYŁĄCZNIE przepisy visibility="public") — ma być
    dostępne dla każdego konta, nie tylko Premium. Moderacja
    administratora pozostaje jedynym zabezpieczeniem przed spamem/
    nieodpowiednimi zgłoszeniami — to ona, nie status konta, decyduje,
    co trafia do wspólnego katalogu.
    """
    visibility = "pending" if recipe_in.request_public else "private"

    # UWAGA (naprawa): wcześniej brakujący/nieistniejący product_id w
    # składniku nie był w ogóle sprawdzany — dopiero baza danych odrzucała
    # to jako naruszenie klucza obcego, kończąc się nieobsłużonym błędem
    # 500 zamiast czytelnej odpowiedzi. Sprawdzamy WSZYSTKIE product_id na
    # raz (jedno zapytanie) PRZED zapisaniem czegokolwiek do bazy.
    await _validate_recipe_ingredient_products(
        db, recipe_in.ingredients, current_user.id
    )

    recipe = Recipe(
        name=recipe_in.name,
        description=recipe_in.description,
        meal_type=recipe_in.meal_type,
        cuisine=recipe_in.cuisine,
        difficulty=recipe_in.difficulty,
        prep_time_min=recipe_in.prep_time_min,
        cook_time_min=recipe_in.cook_time_min,
        servings=recipe_in.servings,
        instructions=recipe_in.instructions,
        suggested_seasonings=recipe_in.suggested_seasonings,
        created_by_user_id=current_user.id,
        visibility=visibility,
        photo_base64=recipe_in.photo_base64,
        photo_thumbnail_base64=create_recipe_photo_thumbnail(
            recipe_in.photo_base64
        ),
    )
    db.add(recipe)
    await db.flush()

    for ing_data in recipe_in.ingredients:
        db.add(
            RecipeIngredient(
                recipe_id=recipe.id,
                product_id=ing_data.product_id,
                quantity=ing_data.quantity,
                unit=ing_data.unit,
                is_optional=ing_data.is_optional,
            )
        )

    for tag_name in recipe_in.tags:
        db.add(RecipeTag(recipe_id=recipe.id, tag=tag_name))

    await db.commit()

    if visibility == "pending":
        await _notify_admins_pending_recipe(db, recipe, current_user)

    # Załaduj ponownie z relacjami
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
            # Nazwa i awatar autora są istotne dla moderatora przed
            # opublikowaniem przepisu we wspólnym katalogu.
            selectinload(Recipe.creator),
        )
        .where(Recipe.id == recipe.id)
    )
    final_recipe = result.scalar_one()

    # UWAGA (naprawa poważnego błędu): wcześniej nutrition_total NIGDY nie
    # było zapisywane w bazie dla przepisów tworzonych ręcznie — liczone
    # było tylko "na żywo" przy zwracaniu odpowiedzi API (patrz
    # ensure_nutrition w schemas/recipe.py). Każdy INNY kod czytający
    # `recipe.nutrition_total` bezpośrednio z bazy (np. dziennik kalorii
    # w Śledzeniu) zawsze widział puste wartości dla takich przepisów.
    # Zapisujemy prawdziwą wartość TERAZ, raz na zawsze.
    final_recipe.nutrition_total = compute_recipe_nutrition_total(final_recipe.ingredients)
    # UWAGA (naprawa): CELOWO bez db.refresh() tutaj — domyślnie wygasza
    # ono WSZYSTKIE atrybuty obiektu, łącznie z wcześniej dociągniętymi
    # relacjami (ingredients, tags), które Pydantic zaraz potem próbuje
    # zserializować. Bez eager-loadingu leniwe doładowanie w kontekście
    # asynchronicznym rzuca MissingGreenlet, co objawiało się nieczytelnym
    # błędem walidacji odpowiedzi. Wartość nutrition_total mam już w
    # pamięci — nie trzeba jej ponownie czytać z bazy.
    await db.commit()
    final_recipe.is_favorite = False
    final_recipe.is_own_recipe = True
    return final_recipe


@router.post(
    "/{recipe_id}/variants",
    response_model=RecipeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Zapisz zmieniony wariant przepisu w Moje",
)
async def save_recipe_variant(
    recipe_id: UUID,
    variant_in: RecipeVariantCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Zapisuje prywatną kopię dopiero po świadomym wyborze użytkownika.

    Zmiany wykonywane na ekranie przepisu pozostają po stronie telefonu.
    Wywoływany po „Zapisz w Moje” lub przed utworzeniem listy zakupów
    z widocznego, zmienionego wariantu. Oryginał nie jest modyfikowany.
    """
    source_result = await db.execute(
        select(Recipe)
        .options(selectinload(Recipe.tags))
        .where(Recipe.id == recipe_id)
    )
    source = source_result.scalar_one_or_none()
    if source is None:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")

    is_own = source.created_by_user_id == current_user.id
    is_public = source.created_by_user_id is None or source.visibility == "public"
    if not is_own and not is_public:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")
    if not is_own and getattr(current_user, "role", None) != "admin":
        await ensure_recipe_available_in_market(db, source, current_user)

    await _validate_recipe_ingredient_products(
        db, variant_in.ingredients, current_user.id
    )

    from app.services.system_content_language import recipe_display_content
    country = account_country(current_user)
    source_content = recipe_display_content(source, country_code=country)
    suffix_label = "edited" if country == "GB" else "edytowane"
    suffix_pattern = r" - (?:edytowane|edited) \d+$" if country == "GB" else r" - edytowane \d+$"
    base_name = re.sub(suffix_pattern, "", source_content["name"], flags=re.IGNORECASE)
    prefix = f"{base_name} - {suffix_label} "
    names_result = await db.execute(
        select(Recipe.name).where(
            Recipe.created_by_user_id == current_user.id,
            Recipe.name.startswith(prefix),
        )
    )
    numbers: list[int] = []
    pattern = re.compile(rf"^{re.escape(prefix)}(\d+)$", re.IGNORECASE)
    for name in names_result.scalars().all():
        match = pattern.match(name)
        if match:
            numbers.append(int(match.group(1)))
    variant_number = max(numbers, default=0) + 1
    suffix = f" - {suffix_label} {variant_number}"
    variant_name = f"{base_name[:300 - len(suffix)].rstrip()}{suffix}"

    variant = Recipe(
        name=variant_name,
        description=source_content["description"],
        cuisine=source.cuisine,
        meal_type=source.meal_type,
        prep_time_min=source.prep_time_min,
        cook_time_min=source.cook_time_min,
        servings=source.servings,
        difficulty=source.difficulty,
        instructions=source_content["instructions"],
        suggested_seasonings=source_content["suggested_seasonings"],
        image_url=source.image_url,
        photo_base64=source.photo_base64,
        photo_thumbnail_base64=source.photo_thumbnail_base64,
        created_by_user_id=current_user.id,
        visibility="private",
    )
    db.add(variant)
    await db.flush()

    for ingredient in variant_in.ingredients:
        db.add(
            RecipeIngredient(
                recipe_id=variant.id,
                product_id=ingredient.product_id,
                quantity=ingredient.quantity,
                unit=ingredient.unit,
                is_optional=ingredient.is_optional,
            )
        )
    for tag in source.tags:
        db.add(RecipeTag(recipe_id=variant.id, tag=tag.tag))
    await db.commit()

    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
            selectinload(Recipe.creator),
        )
        .where(Recipe.id == variant.id)
    )
    saved = result.scalar_one()
    saved.nutrition_total = compute_recipe_nutrition_total(saved.ingredients)
    await db.commit()
    saved.is_favorite = False
    saved.is_own_recipe = True
    return saved


async def _notify_admins_pending_recipe(db: AsyncSession, recipe: Recipe, author: User) -> None:
    """Powiadamia WSZYSTKICH administratorów o nowym przepisie czekającym
    na akceptację do wspólnego katalogu."""
    from app.services.admin_notifications import notify_admins_pending_review

    author_name = author.display_name or "Ktoś"
    message = f'{author_name} zgłosił(a) przepis "{recipe.name}" do wspólnego katalogu — wymaga akceptacji.'
    await notify_admins_pending_review(
        db,
        notification_type="recipe_pending_approval",
        message=message,
        english_message=f'{author.display_name or "Someone"} submitted recipe "{recipe.name}" to the public catalogue — approval required.',
        recipe_id=recipe.id,
    )


@router.put(
    "/{recipe_id}/approve",
    response_model=RecipeResponse,
    summary="Zaakceptuj przepis do wspólnego katalogu (admin)",
)
async def approve_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Akceptuje zgłoszony przepis — staje się widoczny dla wszystkich."""
    recipe = await db.get(Recipe, recipe_id)
    if recipe is None:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")
    recipe.visibility = "public"
    await db.commit()

    # Powiadom autora, że jego przepis został zaakceptowany.
    if recipe.created_by_user_id is not None:
        from app.models.notification import Notification
        from app.services.notification_language import recipient_text

        db.add(
            Notification(
                user_id=recipe.created_by_user_id,
                notification_type="recipe_approved",
                message=await recipient_text(db, recipe.created_by_user_id,
                    f'Twój przepis "{recipe.name}" został zaakceptowany i jest teraz widoczny dla wszystkich!',
                    f'Your recipe "{recipe.name}" has been approved and is now public!',
                ),
                recipe_id=recipe.id,
            )
        )
        await db.commit()

    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.id == recipe.id)
    )
    final_recipe = result.scalar_one()
    final_recipe.is_favorite = False
    final_recipe.is_own_recipe = final_recipe.created_by_user_id == current_user.id
    return final_recipe


@router.put(
    "/{recipe_id}/reject",
    response_model=RecipeResponse,
    summary="Odrzuć przepis zgłoszony do wspólnego katalogu (admin)",
)
async def reject_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Odrzuca zgłoszenie — przepis wraca do stanu prywatnego, ale
    zachowuje ślad, że nie przeszedł akceptacji."""
    recipe = await db.get(Recipe, recipe_id)
    if recipe is None:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")
    recipe.visibility = "rejected"
    await db.commit()

    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.id == recipe.id)
    )
    final_recipe = result.scalar_one()
    final_recipe.is_favorite = False
    final_recipe.is_own_recipe = final_recipe.created_by_user_id == current_user.id
    return final_recipe


@router.get(
    "/pending/review",
    response_model=list[RecipeResponse],
    summary="Lista przepisów czekających na akceptację (admin)",
)
async def list_pending_recipes(
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
) -> list[Recipe]:
    """Zwraca wszystkie przepisy oczekujące na akceptację administratora."""
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
            selectinload(Recipe.creator),
        )
        .where(Recipe.visibility == "pending")
        .where(
            exists(select(User.id).where(
                User.id == Recipe.created_by_user_id, User.country_code == market,
            )) if market else True
        )
        .order_by(Recipe.created_at)
    )
    recipes = list(result.unique().scalars().all())
    for recipe in recipes:
        recipe.is_favorite = False
        recipe.is_own_recipe = False
    return recipes


@router.get(
    "/admin/all-user-recipes",
    response_model=list[RecipeResponse],
    summary="Wszystkie przepisy użytkowników, z autorem (admin)",
)
async def list_all_user_recipes(
    skip: int = Query(0, ge=0),
    limit: int = Query(30, ge=1, le=100),
    current_user: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    market: MarketCode | None = None,
) -> list[Recipe]:
    """Wszystkie przepisy dodane przez użytkowników — niezależnie od
    statusu (private/pending/public/rejected) — z informacją o autorze,
    żeby administrator widział, do kogo dany przepis należy, zanim
    zdecyduje o usunięciu. Celowo POMIJA 81 oficjalnych przepisów
    (created_by_user_id puste) — te nie mają autora do pokazania i nie
    są tym, co administrator miałby tu moderować.
    """
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
            selectinload(Recipe.creator),
        )
        .where(Recipe.created_by_user_id.is_not(None))
        .where(
            exists(select(User.id).where(
                User.id == Recipe.created_by_user_id, User.country_code == market,
            )) if market else True
        )
        .order_by(Recipe.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    recipes = list(result.unique().scalars().all())
    for recipe in recipes:
        recipe.is_favorite = False
        recipe.is_own_recipe = False
    return recipes


@router.post(
    "/{recipe_id}/favorite",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Dodaj przepis do ulubionych",
)
async def add_recipe_favorite(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Dodaje przepis do ulubionych. Idempotentne — dodanie już ulubionego
    przepisu nic nie zmienia."""
    from sqlalchemy.exc import IntegrityError

    from app.models import RecipeFavorite

    recipe = await db.get(Recipe, recipe_id)
    if recipe is None:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")

    existing = await db.execute(
        select(RecipeFavorite).where(
            RecipeFavorite.user_id == current_user.id,
            RecipeFavorite.recipe_id == recipe_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return

    favorite = RecipeFavorite(user_id=current_user.id, recipe_id=recipe_id)
    db.add(favorite)
    try:
        await db.commit()
    except IntegrityError:
        # Wyścig: dwa równoległe żądania w tym samym momencie — ograniczenie
        # unikalności w bazie i tak to obsłuży, traktujemy jako sukces.
        await db.rollback()


@router.delete(
    "/{recipe_id}/favorite",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Usuń przepis z ulubionych",
)
async def remove_recipe_favorite(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Usuwa przepis z ulubionych. Idempotentne — usunięcie nieistniejącego
    ulubionego nic nie zmienia."""
    from app.models import RecipeFavorite

    existing = await db.execute(
        select(RecipeFavorite).where(
            RecipeFavorite.user_id == current_user.id,
            RecipeFavorite.recipe_id == recipe_id,
        )
    )
    favorite = existing.scalar_one_or_none()
    if favorite is not None:
        await db.delete(favorite)
        await db.commit()


@router.post(
    "/ai-import",
    response_model=RecipeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Rozpoznaj i dodaj przepis przez AI (Premium albo 2 punkty)",
)
async def ai_import_recipe(
    payload: AIRecipeImportRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    return await _create_ai_recipe(payload, current_user, db)


async def _create_ai_recipe(
    payload: AIRecipeImportRequest,
    current_user: User,
    db: AsyncSession,
    *,
    import_job_id: UUID | None = None,
    skip_rate_limit: bool = False,
) -> Recipe:
    """Rozpoznaje przepis z wklejonego tekstu, zdjęcia ALBO linku
    (np. blog kulinarny, TikTok, Instagram) i tworzy z niego nowy,
    PRYWATNY przepis (widoczny tylko dla Ciebie — nie trafia
    automatycznie do wspólnego katalogu).

    UWAGA (rozszerzenie): wcześniej WYŁĄCZNIE Premium (get_current_premium).
    Teraz też dostępne dla kont bez Premium, w zamian za 2 punkty
    premium (patrz app/api/v1/billing.py, zakup pakietów punktów) —
    punkty pobierane DOPIERO po UDANYM rozpoznaniu (nie za samą próbę),
    żeby nieudane/niejasne zdjęcie czy tekst nie kosztowało użytkownika
    punktów bez żadnego rezultatu.

    Limit: 20 wywołań/dzień (niezależnie od statusu premium) — każde
    wywołanie kosztuje realne pieniądze (API Gemini).
    """
    from app.core.rate_limit import ai_recipe_import_limiter, enforce_user_rate_limit
    from app.services.ai_recipe_import import (
        AIRecipeImportError,
        extract_recipe_from_photo,
        extract_recipe_from_text,
        extract_recipe_from_url,
        recipe_message,
        validate_and_clean_recipe_dict,
    )
    from app.services.recipe_ingredient_integrity import looks_like_whole_meal

    started_at = time.perf_counter()
    country = account_country(current_user)
    market_kwargs = {"country_code": country} if country == "GB" else {}
    source_kind = "text" if payload.text else "photo" if payload.photo_base64 else "url"
    provided = [bool(payload.text), bool(payload.photo_base64), bool(payload.url)]
    if sum(provided) != 1:
        raise HTTPException(
            status_code=400,
            detail=recipe_message(country, "Podaj dokładnie jedno z: tekst przepisu, zdjęcie albo link.", "Provide exactly one of: recipe text, a photo or a link."),
        )

    # Sprawdzenie uprawnienia PRZED kosztownym wywołaniem AI — niepremium
    # bez wystarczających punktów nie powinien w ogóle zainicjować
    # zapytania do Gemini (to kosztuje realne pieniądze niezależnie od
    # tego, czy ostatecznie i tak zostałby odrzucony).
    from app.core.premium import is_premium_active

    user_is_premium = is_premium_active(current_user)
    if not user_is_premium and current_user.premium_points < 2:
        raise HTTPException(
            status_code=402,
            detail=recipe_message(country,
                f"Ta funkcja wymaga Premium albo 2 punktów (masz {current_user.premium_points}). "
                "Kup punkty w zakładce Premium.",
                f"This feature requires Premium or 2 points (you have {current_user.premium_points}). Buy points in the Premium tab.",
            ),
        )

    if not skip_rate_limit:
        try:
            enforce_user_rate_limit(ai_recipe_import_limiter, current_user.id, recipe_message(country, "rozpoznawanie przepisu przez AI", "AI recipe recognition"))
        except HTTPException as exc:
            if country == "GB" and exc.status_code == 429:
                exc.detail = "Too many AI recipe requests. Please try again later."
            raise

    # Jeden odczyt katalogu zamiast osobno listy nazw do promptu i potem
    # całej tabeli do zapisu. Cudze niezatwierdzone produkty nie powinny
    # trafiać ani do promptu, ani do przepisu innego użytkownika.
    products_result = await db.execute(select(Product).where(or_(
        Product.review_status == "approved",
        Product.created_by_user_id == current_user.id,
    )))
    available_product_rows = [
        product
        for product in products_result.scalars().all()
        if _product_has_complete_nutrition(product) and not looks_like_whole_meal(product.name)
    ]
    available_products = list(dict.fromkeys(p.name for p in available_product_rows))
    catalog_seconds = time.perf_counter() - started_at

    try:
        if payload.text:
            parsed = await extract_recipe_from_text(payload.text, available_products, **market_kwargs)
        elif payload.photo_base64:
            parsed = await extract_recipe_from_photo(
                payload.photo_base64, available_products, hint=payload.photo_hint, **market_kwargs
            )
        else:
            parsed = await extract_recipe_from_url(payload.url, available_products, **market_kwargs)
    except AIRecipeImportError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    extraction_seconds = time.perf_counter() - started_at - catalog_seconds

    try:
        parsed = validate_and_clean_recipe_dict(parsed, **market_kwargs)
    except AIRecipeImportError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    if not parsed["ingredients"]:
        raise HTTPException(
            status_code=422,
            detail=recipe_message(country, "AI nie rozpoznało żadnych składników pasujących do dostępnych produktów.", "AI did not recognise any ingredients matching the available catalogue products."),
        )

    # Resolve ALL required ingredients before charging points or storing the
    # recipe. A partial recipe produces an incomplete shopping basket.
    from app.services.recipe_ingredient_integrity import validate_ingredient_names
    from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients, materialize_recipe_ingredients
    matched_ingredients = await resolve_recipe_ingredients(parsed["ingredients"], available_product_rows, country=country, user_id=current_user.id)
    unresolved_names = [ingredient["product_name"] for ingredient, product in matched_ingredients
        if product is None or not is_ingredient_quantity_reasonable(ingredient["quantity"], ingredient["unit"])]
    if unresolved_names:
        names = ", ".join(dict.fromkeys(unresolved_names))[:500]
        raise HTTPException(status_code=422, detail=recipe_message(country,
            f"Nie odnaleziono wiarygodnych danych składników: {names}, także w zewnętrznej bazie. Nie zapisano niepełnego przepisu ani nie pobrano punktów. Spróbuj ponownie lub uzupełnij dane składnika.",
            f"Reliable ingredient data was not found for: {names}, including in the external database. No incomplete recipe was saved and no points were charged. Try again or add the ingredient details.",
        ))
    validate_ingredient_names(parsed["name"], [product.name for _, product in matched_ingredients], country_code=country)
    try:
        matched_ingredients = await materialize_recipe_ingredients(db, matched_ingredients)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=recipe_message(country,
            "Nie udało się bezpiecznie dopasować produktu do katalogu. Nie pobrano punktów.",
            "Could not safely match the product to the catalogue. No points were charged.")) from exc

    # UWAGA: rozpoznanie się UDAŁO — dopiero TERAZ, nie wcześniej,
    # pobieramy 2 punkty od kont bez Premium (jeśli user jest Premium,
    # nic się nie odejmuje — korzysta z funkcji w ramach subskrypcji).
    if not user_is_premium:
        from app.services.premium_points import spend_points

        try:
            await spend_points(db, current_user.id, 2)
        except HTTPException as exc:
            if country == "GB" and exc.status_code == 402:
                exc.detail = "You need 2 Premium points."
            raise

    # Zgłoszenie do wspólnego katalogu — jak przy ręcznym dodawaniu.
    visibility = "pending" if payload.request_public else "private"

    recipe = Recipe(
        name=parsed["name"][:300],
        description=parsed.get("description"),
        cuisine=parsed.get("cuisine"),
        meal_type=parsed["meal_type"],
        prep_time_min=parsed.get("prep_time_min"),
        cook_time_min=parsed.get("cook_time_min"),
        servings=parsed["servings"],
        difficulty=parsed["difficulty"],
        instructions=parsed["instructions"],
        suggested_seasonings=parsed["suggested_seasonings"],
        created_by_user_id=current_user.id,
        import_job_id=import_job_id,
        visibility=visibility,
        # Jeśli przepis rozpoznano ZE ZDJĘCIA, to samo zdjęcie staje się
        # zdjęciem przepisu — to zwykle prawdziwe zdjęcie tego dania,
        # więc szkoda by było go nie wykorzystać.
        photo_base64=payload.photo_base64,
        photo_thumbnail_base64=create_recipe_photo_thumbnail(
            payload.photo_base64
        ),
    )
    db.add(recipe)
    await db.flush()

    matched_count = 0
    for ing, product in matched_ingredients:
        db.add(
            RecipeIngredient(
                recipe_id=recipe.id,
                product_id=product.id,
                quantity=ing["quantity"],
                unit=ing["unit"],
                is_optional=False,
            )
        )
        matched_count += 1

    if matched_count == 0:
        await db.rollback()
        raise HTTPException(
            status_code=422,
            detail=recipe_message(country, "Żaden ze składników rozpoznanych przez AI nie pasował do dostępnych produktów.", "None of the ingredients recognised by AI matched the available catalogue products."),
        )

    await db.commit()

    if visibility == "pending":
        await _notify_admins_pending_recipe(db, recipe, current_user)


    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.id == recipe.id)
    )
    final_recipe = result.scalar_one()

    # UWAGA (naprawa poważnego błędu — patrz identyczny komentarz przy
    # create_recipe wyżej): nutrition_total nigdy nie było zapisywane w
    # bazie dla przepisów z importu AI, więc dziennik kalorii w
    # Śledzeniu zawsze widział dla nich puste wartości odżywcze.
    final_recipe.nutrition_total = compute_recipe_nutrition_total(final_recipe.ingredients)
    # UWAGA (naprawa): CELOWO bez db.refresh() tutaj — domyślnie wygasza
    # ono WSZYSTKIE atrybuty obiektu, łącznie z wcześniej dociągniętymi
    # relacjami (ingredients, tags), które Pydantic zaraz potem próbuje
    # zserializować. Bez eager-loadingu leniwe doładowanie w kontekście
    # asynchronicznym rzuca MissingGreenlet, co objawiało się nieczytelnym
    # błędem walidacji odpowiedzi. Wartość nutrition_total mam już w
    # pamięci — nie trzeba jej ponownie czytać z bazy.
    await db.commit()

    final_recipe.is_favorite = False
    final_recipe.is_own_recipe = True
    logger.info(
        "AI recipe import source=%s catalog=%.2fs extraction=%.2fs total=%.2fs",
        source_kind, catalog_seconds, extraction_seconds, time.perf_counter() - started_at,
    )
    return final_recipe


@router.post(
    "/{recipe_id}/ai-edit",
    response_model=RecipeResponse,
    summary="Zmień własny przepis przez AI za 1 punkt premium",
)
async def edit_recipe_with_ai(
    recipe_id: UUID,
    payload: AIRecipeEditRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RecipeResponse:
    from app.core.rate_limit import ai_recipe_import_limiter, enforce_user_rate_limit
    from app.services.ai_recipe_import import (
        AIRecipeImportError,
        match_product_name,
        recipe_message,
        revise_recipe_with_ai,
    )

    user_id = current_user.id
    country = account_country(current_user)
    market_kwargs = {"country_code": country} if country == "GB" else {}
    if current_user.premium_points < 1:
        raise HTTPException(status_code=402, detail=recipe_message(country, "Zmiana przez AI kosztuje 1 punkt premium.", "Editing with AI costs 1 Premium point."))
    try:
        enforce_user_rate_limit(ai_recipe_import_limiter, user_id, recipe_message(country, "edycja przepisu przez AI", "AI recipe editing"))
    except HTTPException as exc:
        if country == "GB" and exc.status_code == 429:
            exc.detail = "Too many AI recipe requests. Please try again later."
        raise

    result = await db.execute(select(Recipe).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product)
    ).where(Recipe.id == recipe_id))
    recipe = result.scalar_one_or_none()
    if recipe is None or recipe.created_by_user_id != user_id:
        raise HTTPException(status_code=404, detail=recipe_message(country, "Nie znaleziono Twojego przepisu.", "Your recipe was not found."))
    if recipe.visibility != "private":
        raise HTTPException(
            status_code=409,
            detail=recipe_message(country, "Przepis zgłoszony do publikacji nie może być zmieniany w trakcie moderacji.", "A submitted recipe cannot be edited while it is being reviewed."),
        )

    snapshot = {
        "name": recipe.name,
        "description": recipe.description,
        "cuisine": recipe.cuisine,
        "meal_type": recipe.meal_type,
        "prep_time_min": recipe.prep_time_min,
        "cook_time_min": recipe.cook_time_min,
        "servings": recipe.servings,
        "difficulty": recipe.difficulty,
        "ingredients": [
            {"product_name": ingredient.product.name,
             "quantity": float(ingredient.quantity), "unit": ingredient.unit}
            for ingredient in recipe.ingredients if ingredient.product is not None
        ],
        "instructions": list(recipe.instructions or []),
        "suggested_seasonings": list(recipe.suggested_seasonings or []),
    }
    product_result = await db.execute(select(Product).where(or_(
        Product.review_status == "approved", Product.created_by_user_id == user_id,
    )))
    from app.services.recipe_ingredient_integrity import looks_like_whole_meal
    available_rows = [
        product
        for product in product_result.scalars().all()
        if _product_has_complete_nutrition(product) and not looks_like_whole_meal(product.name)
    ]
    available_names = list(dict.fromkeys(product.name for product in available_rows))
    # Nie trzymaj połączenia i transakcji z Neonem w czasie odpowiedzi Gemini.
    await db.rollback()

    try:
        parsed = await revise_recipe_with_ai(snapshot, payload.prompt, available_names, **market_kwargs)
    except AIRecipeImportError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    # Rollback expired the earlier ORM rows. Reload once, never lazy-load one
    # ingredient at a time after the network call.
    catalogue_result = await db.execute(select(Product).where(or_(
        Product.review_status == "approved", Product.created_by_user_id == user_id,
    )))
    from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients, materialize_recipe_ingredients
    pairs = await resolve_recipe_ingredients(parsed["ingredients"], catalogue_result.scalars().all(), country=country, user_id=user_id)
    for ingredient, _ in pairs:
        if not is_ingredient_quantity_reasonable(ingredient["quantity"], ingredient["unit"]):
            raise HTTPException(status_code=422, detail=recipe_message(country, "AI podało nieprawidłową ilość składnika.", "AI returned an invalid ingredient quantity."))
    from app.services.recipe_ingredient_integrity import validate_ingredient_names
    validate_ingredient_names(parsed["name"], [product.name for _, product in pairs], country_code=country)
    matched = [(product.id, product.name, ingredient) for ingredient, product in pairs]
    if not matched or not parsed["instructions"]:
        raise HTTPException(status_code=422, detail=recipe_message(country, "AI zwróciło niekompletny przepis. Punkt nie został pobrany.", "AI returned an incomplete recipe. No point was charged."))

    before = [(i["product_name"], i["quantity"], i["unit"]) for i in snapshot["ingredients"]]
    after = [(name, i["quantity"], i["unit"]) for _, name, i in matched]
    if before == after and all(parsed.get(key) == snapshot.get(key) for key in (
        "name", "description", "cuisine", "meal_type", "prep_time_min",
        "cook_time_min", "servings", "difficulty", "instructions", "suggested_seasonings",
    )):
        raise HTTPException(status_code=422, detail=recipe_message(country, "AI nie wprowadziło żadnej zmiany. Punkt nie został pobrany.", "AI made no changes. No point was charged."))

    locked_user = (await db.execute(
        select(User).where(User.id == user_id).with_for_update().execution_options(populate_existing=True)
    )).scalar_one()
    locked_recipe = (await db.execute(
        select(Recipe).where(Recipe.id == recipe_id).with_for_update()
    )).scalar_one_or_none()
    if locked_recipe is None or locked_recipe.created_by_user_id != user_id:
        raise HTTPException(status_code=404, detail=recipe_message(country, "Nie znaleziono Twojego przepisu.", "Your recipe was not found."))
    if locked_recipe.visibility != "private":
        raise HTTPException(status_code=409, detail=recipe_message(country, "Przepis został już zgłoszony do moderacji.", "The recipe has already been submitted for review."))
    if locked_user.premium_points < 1:
        raise HTTPException(status_code=402, detail=recipe_message(country, "Brakuje 1 punktu premium.", "You need 1 Premium point."))

    try:
        pairs = await materialize_recipe_ingredients(db, pairs)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=recipe_message(country,
            "Nie udało się bezpiecznie dopasować składnika. Punkt nie został pobrany.",
            "Could not safely match the ingredient. No point was charged.")) from exc
    matched = [(product.id, product.name, ingredient) for ingredient, product in pairs]

    locked_recipe.name = parsed["name"][:300]
    locked_recipe.description = parsed.get("description")
    locked_recipe.cuisine = (parsed.get("cuisine") or "")[:100] or None
    locked_recipe.meal_type = parsed["meal_type"]
    locked_recipe.prep_time_min = parsed.get("prep_time_min")
    locked_recipe.cook_time_min = parsed.get("cook_time_min")
    locked_recipe.servings = parsed["servings"]
    locked_recipe.difficulty = parsed["difficulty"]
    locked_recipe.instructions = parsed["instructions"]
    locked_recipe.suggested_seasonings = parsed["suggested_seasonings"]
    await db.execute(delete(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe_id))
    db.add_all(RecipeIngredient(
        recipe_id=recipe_id, product_id=product_id,
        quantity=ingredient["quantity"], unit=ingredient["unit"], is_optional=False,
    ) for product_id, _, ingredient in matched)
    from app.services.premium_points import spend_points

    try:
        await spend_points(db, user_id, 1)
    except HTTPException as exc:
        if country == "GB" and exc.status_code == 402:
            exc.detail = "You need 1 Premium point."
        raise
    await db.flush()

    final_result = await db.execute(select(Recipe).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
        selectinload(Recipe.tags),
    ).where(Recipe.id == recipe_id).execution_options(populate_existing=True))
    final_recipe = final_result.scalar_one()
    final_recipe.nutrition_total = compute_recipe_nutrition_total(final_recipe.ingredients)
    final_recipe.is_own_recipe = True
    final_recipe.is_favorite = recipe_id in await _get_favorite_recipe_ids(db, user_id)
    response = RecipeResponse.model_validate(final_recipe)
    await db.commit()
    return response


@router.put(
    "/{recipe_id}/request-publish",
    response_model=RecipeResponse,
    summary="Zgłoś własny przepis do publikacji we wspólnym katalogu",
)
async def request_publish_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Zmienia widoczność WŁASNEGO, prywatnego przepisu na "pending" —
    czeka teraz na przegląd administratora, dokładnie tak samo jak
    przepisy zgłoszone od razu przy tworzeniu (opcja "Udostępnij
    społeczności"). Tylko właściciel przepisu może to zrobić, i tylko
    dla przepisu, który jest jeszcze prywatny (nie da się "ponownie
    zgłosić" czegoś, co już czeka na przegląd, jest publiczne, albo
    zostało odrzucone bez zmian — odrzucony przepis wymaga osobnego
    rozpatrzenia przed ponownym zgłoszeniem).
    """
    recipe = await db.get(Recipe, recipe_id)
    if recipe is None:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")
    if recipe.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Możesz opublikować tylko własny przepis.")
    if recipe.visibility != "private":
        raise HTTPException(
            status_code=400,
            detail={
                "pending": "Ten przepis już czeka na przegląd administratora.",
                "public": "Ten przepis jest już publiczny.",
                "rejected": "Ten przepis został odrzucony — skontaktuj się z administratorem, żeby dowiedzieć się dlaczego.",
            }.get(recipe.visibility, "Tego przepisu nie można teraz opublikować."),
        )

    recipe.visibility = "pending"
    await db.commit()

    await _notify_admins_pending_recipe(db, recipe, current_user)

    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.id == recipe.id)
    )
    final_recipe = result.scalar_one()
    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
    final_recipe.is_favorite = final_recipe.id in favorite_ids
    final_recipe.is_own_recipe = True
    return final_recipe


@router.delete(
    "/{recipe_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Usuń własny przepis",
)
async def delete_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Usuwa przepis dodany przez użytkownika (ręcznie albo przez AI) wraz
    ze wszystkimi powiązanymi danymi.

    UWAGA (naprawa braku funkcji): wcześniej w ogóle nie było jak usunąć
    własnego przepisu — dało się go dodać, polubić, skomentować, ale nie
    usunąć. Tylko WŁAŚCICIEL przepisu (albo administrator) może go
    usunąć — 81 oficjalnych przepisów (created_by_user_id puste) nie da
    się usunąć tą drogą w ogóle.

    Powiązane dane są usuwane JAWNIE w kodzie, a nie tylko przez
    kaskadowe ograniczenia w bazie (ON DELETE CASCADE) — z tego samego
    powodu, co przy usuwaniu planu posiłków (patrz meal_plans.py):
    tabele tej aplikacji są tworzone przez `Base.metadata.create_all()`
    przy starcie, nie przez pełne migracje, więc ograniczenia dodane do
    modeli PO TYM, jak dana tabela już istniała w bazie produkcyjnej,
    mogły nie zostać tam faktycznie zastosowane.

    Jeśli przepis był PUBLICZNY (zaakceptowany do wspólnego katalogu),
    usunięcie go usuwa go też z list zakupów/planów innych użytkowników,
    którzy go używali — to świadoma decyzja: to Twój przepis, masz prawo
    go usunąć, ale skutek dotyczy wszystkich, którzy z niego korzystali.
    """
    from app.models import FoodLogEntry, MealPlanEntry, Notification, RecipeComment, RecipeCommentLike, RecipeFavorite

    recipe = await db.get(Recipe, recipe_id)
    if recipe is None:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")

    if recipe.created_by_user_id is None:
        raise HTTPException(
            status_code=403,
            detail="Nie można usunąć oficjalnego przepisu dostarczonego z aplikacją.",
        )
    if recipe.created_by_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Możesz usunąć tylko własny przepis.")

    # Polubienia komentarzy pod komentarzami DO TEGO przepisu — trzeba
    # usunąć PRZED samymi komentarzami (klucz obcy wskazuje na comment_id).
    comment_ids_result = await db.execute(
        select(RecipeComment.id).where(RecipeComment.recipe_id == recipe_id)
    )
    comment_ids = list(comment_ids_result.scalars().all())
    if comment_ids:
        await db.execute(delete(RecipeCommentLike).where(RecipeCommentLike.comment_id.in_(comment_ids)))

    await db.execute(delete(RecipeComment).where(RecipeComment.recipe_id == recipe_id))
    await db.execute(delete(RecipeFavorite).where(RecipeFavorite.recipe_id == recipe_id))
    await db.execute(delete(MealPlanEntry).where(MealPlanEntry.recipe_id == recipe_id))
    await db.execute(delete(Notification).where(Notification.recipe_id == recipe_id))
    # Wpisy dziennika kalorii NIE są usuwane — tylko odłączane od przepisu
    # (zachowują już policzone wartości odżywcze, tak jak historyczny zapis
    # tego, co ktoś faktycznie zjadł, niezależnie od losu samego przepisu).
    await db.execute(
        update(FoodLogEntry).where(FoodLogEntry.recipe_id == recipe_id).values(recipe_id=None)
    )
    await db.execute(delete(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe_id))
    await db.execute(delete(RecipeTag).where(RecipeTag.recipe_id == recipe_id))

    await db.delete(recipe)
    await db.commit()


class MatchByIngredientsRequest(BaseModel):
    """Żądanie dopasowania przepisów do posiadanych w domu produktów —
    funkcja Premium "Co ugotować z tego, co mam"."""

    product_ids: list[UUID]


@router.post(
    "/{recipe_id}/report",
    response_model=ContentReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Zgłoś przepis do moderacji",
)
async def report_recipe(
    recipe_id: UUID,
    payload: ContentReportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ContentReportResponse:
    """Zgłasza przepis administratorowi (Apple Guideline 1.2). Dotyczy
    głównie przepisów dodanych przez społeczność, ale technicznie działa
    dla dowolnego — admin i tak decyduje, czy zgłoszenie jest zasadne."""
    from app.core.rate_limit import content_report_limiter, enforce_user_rate_limit
    from app.models import ContentReport

    enforce_user_rate_limit(content_report_limiter, current_user.id, "zgłaszanie treści")

    recipe = await db.get(Recipe, recipe_id)
    if not recipe:
        raise NotFoundException("Nie znaleziono przepisu")

    report = ContentReport(
        reporter_user_id=current_user.id,
        content_type="recipe",
        content_id=recipe_id,
        reason=payload.reason,
        details=payload.details,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)

    from app.services.admin_notifications import notify_admins_pending_review

    await notify_admins_pending_review(
        db,
        notification_type="content_report_pending",
        message=(
            f'{current_user.display_name or "Użytkownik"} zgłosił(a) przepis '
            f'"{recipe.name}" do moderacji.'
        ),
        english_message=f'{current_user.display_name or "A user"} reported recipe "{recipe.name}" for moderation.',
        recipe_id=recipe.id,
    )
    return report


class RecipeMatchResponse(BaseModel):
    """Wynik dopasowania — przepis wraz z informacją o tym, ile ze
    swoich WYMAGANYCH (nieopcjonalnych) składników pokrywają posiadane
    produkty, i czego dokładnie brakuje."""

    model_config = ConfigDict(from_attributes=True)

    recipe: RecipeResponse
    matched_count: int
    total_required: int
    missing_ingredient_names: list[str]


@router.post(
    "/match-by-ingredients",
    response_model=list[RecipeMatchResponse],
    summary='Dopasuj przepisy do posiadanych składników — "Co ugotować z tego, co mam" (Premium)',
)
async def match_recipes_by_ingredients(
    payload: MatchByIngredientsRequest,
    current_user: User = Depends(get_current_premium),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Zwraca przepisy z katalogu widoczne dla użytkownika (oficjalne,
    publiczne, własne), posortowane od NAJLEPIEJ dopasowanych do
    podanej listy posiadanych produktów — czyli takich, gdzie brakuje
    najmniej (albo wcale) WYMAGANYCH składników. Składniki oznaczone
    jako opcjonalne (`is_optional`) NIE liczą się do wymogu — ich brak
    nie obniża dopasowania.

    Celowo NIE generuje nowych przepisów przez AI — dopasowuje wyłącznie
    istniejący katalog, więc działa natychmiast i bez kosztu wywołania AI.
    """
    if not payload.product_ids:
        raise HTTPException(status_code=400, detail="Podaj przynajmniej jeden posiadany składnik")

    have_ids = set(payload.product_ids)

    query = (
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(_visibility_filter(current_user.id), Recipe.is_active == True)  # noqa: E712
    )
    result = await db.execute(apply_recipe_market_filter(query, current_user))
    recipes = result.scalars().all()

    matches: list[dict] = []
    for recipe in recipes:
        required = [ing for ing in recipe.ingredients if not ing.is_optional]
        if not required:
            continue
        matched = [ing for ing in required if ing.product_id in have_ids]
        if not matched:
            # Zero wspólnych składników — nie ma sensu zaśmiecać wyników
            # przepisem, z którym nie łączy nas absolutnie nic.
            continue
        missing_names = [
            ing.product.name for ing in required if ing.product_id not in have_ids and ing.product
        ]
        matches.append(
            {
                "recipe": recipe,
                "matched_count": len(matched),
                "total_required": len(required),
                "missing_ingredient_names": missing_names,
            }
        )

    # Sortowanie: najpierw najwyższy procent pokrycia (pełne dopasowania
    # na samej górze), a przy remisie — mniej brakujących składników w
    # liczbach bezwzględnych (prostszy zakup, nawet przy tym samym %).
    matches.sort(key=lambda m: (-(m["matched_count"] / m["total_required"]), len(m["missing_ingredient_names"])))

    return matches[:30]


# ══════════════════════════════════════════════════════════════════
# ZDJĘCIA PRZEPISÓW ZGŁASZANE PRZEZ UŻYTKOWNIKÓW
# Zdjęcie trafia najpierw do `pending_photo_base64` i staje się widoczne
# dopiero po akceptacji administratora — inaczej każdy mógłby podmienić
# zdjęcie w dowolnym przepisie (również w 81 oficjalnych) bez kontroli.
# ══════════════════════════════════════════════════════════════════
class RecipePhotoSubmission(BaseModel):
    photo_base64: str

    @field_validator("photo_base64")
    @classmethod
    def validate_photo(cls, v: str) -> str:
        from app.core.photo_validation import validate_and_check_photo_base64

        return validate_and_check_photo_base64(v, 3 * 1024 * 1024)


@router.post(
    "/{recipe_id}/photo",
    status_code=201,
    summary="Zgłoś zdjęcie do przepisu (czeka na akceptację administratora)",
)
async def submit_recipe_photo(
    recipe_id: UUID,
    payload: RecipePhotoSubmission,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.core.rate_limit import enforce_user_rate_limit, recipe_photo_submission_limiter

    enforce_user_rate_limit(
        recipe_photo_submission_limiter, current_user.id, "zgłaszanie zdjęć do przepisów"
    )

    recipe = await db.get(Recipe, recipe_id)
    if recipe is None:
        raise NotFoundException("Nie znaleziono przepisu")

    # Widoczność sprawdzana jawnie: bez tego dałoby się zgłosić zdjęcie do
    # CUDZEGO prywatnego przepisu, którego zgłaszający nie ma prawa nawet
    # zobaczyć — a treść zgłoszenia trafiłaby potem do panelu admina
    # razem z nazwą tego przepisu.
    is_visible = (
        recipe.created_by_user_id is None
        or recipe.created_by_user_id == current_user.id
        or recipe.visibility == "public"
    )
    if not is_visible:
        raise NotFoundException("Nie znaleziono przepisu")

    if recipe.pending_photo_base64 is not None:
        raise HTTPException(
            status_code=409,
            detail="Do tego przepisu zgłoszono już zdjęcie, które czeka na akceptację.",
        )

    recipe.pending_photo_base64 = payload.photo_base64
    recipe.pending_photo_user_id = current_user.id
    recipe.pending_photo_submitted_at = datetime.now(timezone.utc)
    db.add(recipe)
    await db.commit()

    from app.services.admin_notifications import notify_admins_pending_review

    await notify_admins_pending_review(
        db,
        notification_type="photo_pending_approval",
        message=(
            f'{current_user.display_name or "Użytkownik"} dodał(a) zdjęcie do '
            f'przepisu "{recipe.name}" — wymaga akceptacji.'
        ),
        english_message=f'{current_user.display_name or "A user"} added a photo to recipe "{recipe.name}" — approval required.',
        recipe_id=recipe.id,
    )
    return {"detail": "Zdjęcie zgłoszone. Pojawi się po akceptacji przez administratora."}


class PendingPhotoEntry(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    recipe_id: UUID
    recipe_name: str
    photo_base64: str
    submitted_by: str | None
    submitted_at: datetime | None
    has_current_photo: bool


@router.get(
    "/admin/pending-photos",
    response_model=list[PendingPhotoEntry],
    summary="Zdjęcia oczekujące na akceptację (admin)",
)
async def list_pending_photos(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> list[PendingPhotoEntry]:
    result = await db.execute(
        select(Recipe, User)
        .outerjoin(User, User.id == Recipe.pending_photo_user_id)
        .where(Recipe.pending_photo_base64.is_not(None))
        .order_by(Recipe.pending_photo_submitted_at.asc())
    )
    return [
        PendingPhotoEntry(
            recipe_id=recipe.id,
            recipe_name=recipe.name,
            photo_base64=recipe.pending_photo_base64,
            submitted_by=(user.display_name or user.email) if user else None,
            submitted_at=recipe.pending_photo_submitted_at,
            has_current_photo=recipe.photo_base64 is not None,
        )
        for recipe, user in result.all()
    ]


@router.post(
    "/{recipe_id}/photo/approve",
    status_code=204,
    summary="Zaakceptuj zgłoszone zdjęcie (admin)",
)
async def approve_recipe_photo(
    recipe_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> None:
    recipe = await db.get(Recipe, recipe_id)
    if recipe is None or recipe.pending_photo_base64 is None:
        raise NotFoundException("Brak zdjęcia oczekującego dla tego przepisu")

    from app.models.notification import Notification

    submitter_id = recipe.pending_photo_user_id
    recipe.photo_base64 = recipe.pending_photo_base64
    recipe.photo_thumbnail_base64 = create_recipe_photo_thumbnail(
        recipe.pending_photo_base64
    )
    recipe.pending_photo_base64 = None
    recipe.pending_photo_user_id = None
    recipe.pending_photo_submitted_at = None
    db.add(recipe)

    if submitter_id is not None:
        from app.services.notification_language import recipient_text

        db.add(
            Notification(
                user_id=submitter_id,
                notification_type="recipe_photo",
                message=await recipient_text(db, submitter_id,
                    f'Twoje zdjęcie do przepisu "{recipe.name}" zostało zaakceptowane.',
                    f'Your photo for recipe "{recipe.name}" has been approved.',
                ),
                recipe_id=recipe.id,
            )
        )
    await db.commit()


@router.post(
    "/{recipe_id}/photo/reject",
    status_code=204,
    summary="Odrzuć zgłoszone zdjęcie (admin)",
)
async def reject_recipe_photo(
    recipe_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> None:
    recipe = await db.get(Recipe, recipe_id)
    if recipe is None or recipe.pending_photo_base64 is None:
        raise NotFoundException("Brak zdjęcia oczekującego dla tego przepisu")

    from app.models.notification import Notification

    submitter_id = recipe.pending_photo_user_id
    recipe.pending_photo_base64 = None
    recipe.pending_photo_user_id = None
    recipe.pending_photo_submitted_at = None
    db.add(recipe)

    if submitter_id is not None:
        from app.services.notification_language import recipient_text

        db.add(
            Notification(
                user_id=submitter_id,
                notification_type="recipe_photo",
                message=await recipient_text(db, submitter_id,
                    f'Twoje zdjęcie do przepisu "{recipe.name}" nie zostało zaakceptowane.',
                    f'Your photo for recipe "{recipe.name}" was not approved.',
                ),
                recipe_id=recipe.id,
            )
        )
    await db.commit()

async def _send_pushes(db, notifications) -> None:
    """Wysyła push dla listy powiadomień — PO ich zapisaniu w bazie.
    Cicho pomijane, gdy push jest wyłączony (brak klucza FCM)."""
    from app.services.push import is_push_enabled, push_for_notification

    if not is_push_enabled():
        return
    for n in notifications:
        await push_for_notification(db, n)
