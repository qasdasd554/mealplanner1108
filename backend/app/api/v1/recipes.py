"""Endpointy przepisów kulinarnych."""

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, field_validator
from sqlalchemy import and_, delete, func, nullslast, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_admin, get_current_premium, get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import (
    Product,
    Recipe,
    RecipeIngredient,
    RecipeTag,
    StoreProduct,
    User,
)
from app.schemas.moderation import ContentReportCreate, ContentReportResponse
from app.schemas.recipe import AIRecipeImportRequest, RecipeCreate, RecipeResponse
from app.services.moderation import get_blocked_user_ids
from app.services.nutrition_calculator import compute_recipe_nutrition_total, is_ingredient_quantity_reasonable

router = APIRouter()


async def _get_favorite_recipe_ids(db: AsyncSession, user_id: UUID) -> set[UUID]:
    """Zwraca zbiór ID przepisów, które użytkownik ma w ulubionych."""
    from app.models import RecipeFavorite

    result = await db.execute(
        select(RecipeFavorite.recipe_id).where(RecipeFavorite.user_id == user_id)
    )
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


def _apply_recipe_sort(query, sort_by: str):
    """Dokłada sortowanie do zapytania o przepisy.

    Przepisy bez policzonych wartości odżywczych (`nutrition_total` puste
    — dotyczy głównie starszych wpisów sprzed wprowadzenia automatycznego
    liczenia) trafiają na KONIEC listy przy sortowaniu po kaloriach,
    zamiast udawać "0 kcal" i fałszywie zajmować pierwsze miejsca.
    """
    if sort_by == "kcal_asc":
        return query.order_by(nullslast(_kcal_per_serving_expr().asc()), Recipe.name)
    if sort_by == "kcal_desc":
        return query.order_by(nullslast(_kcal_per_serving_expr().desc()), Recipe.name)
    if sort_by == "prep_time":
        return query.order_by(nullslast(Recipe.prep_time_min.asc()), Recipe.name)
    return query.order_by(Recipe.name)


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


@router.get(
    "/",
    response_model=list[RecipeResponse],
    summary="Lista przepisów z filtrami",
)
async def list_recipes(
    meal_type: str | None = Query(None, description="Typ posiłku: breakfast, lunch, dinner, snack"),
    cuisine: str | None = Query(None, description="Kuchnia np. polska, włoska"),
    difficulty: str | None = Query(None, description="Poziom trudności: easy, medium, hard"),
    tags: list[str] | None = Query(None, description="Tagi do filtrowania"),
    max_prep_time: int | None = Query(None, ge=1, description="Maksymalny czas przygotowania w minutach"),
    search: str | None = Query(None, description="Szukaj po nazwie przepisu"),
    favorites_only: bool = Query(False, description="Pokaż tylko przepisy dodane do ulubionych"),
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
    query = select(Recipe).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
        selectinload(Recipe.tags),
    ).where(_visibility_filter(current_user.id, blocked_ids))

    if meal_type is not None:
        query = query.where(Recipe.meal_type == meal_type)

    if cuisine is not None:
        query = query.where(Recipe.cuisine.ilike(f"%{cuisine}%"))

    if difficulty is not None:
        query = query.where(Recipe.difficulty == difficulty)

    if max_prep_time is not None:
        query = query.where(Recipe.prep_time_min <= max_prep_time)

    if search:
        query = query.where(Recipe.name.ilike(f"%{search}%"))

    if community_only:
        query = query.where(Recipe.created_by_user_id.is_not(None), Recipe.visibility == "public")

    if tags:
        query = query.join(Recipe.tags).where(RecipeTag.tag.in_(tags))

    query = _apply_recipe_sort(query, sort_by).offset(skip).limit(limit)

    result = await db.execute(query)
    recipes = list(result.unique().scalars().all())

    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
    for recipe in recipes:
        recipe.is_favorite = recipe.id in favorite_ids
        recipe.is_own_recipe = recipe.created_by_user_id == current_user.id

    if favorites_only:
        recipes = [r for r in recipes if r.is_favorite]

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
    # Pobierz ID produktów dostępnych w sklepie
    available_result = await db.execute(
        select(StoreProduct.product_id).where(
            StoreProduct.store_id == store_id,
            StoreProduct.is_available == True,  # noqa: E712
        )
    )
    available_product_ids = set(available_result.scalars().all())

    # Pobierz wszystkie przepisy z ich składnikami
    blocked_ids = await get_blocked_user_ids(db, current_user.id)
    recipes_result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(_visibility_filter(current_user.id, blocked_ids))
        .order_by(Recipe.name)
    )
    all_recipes = recipes_result.unique().scalars().all()

    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)

    # Filtruj przepisy — wszystkie składniki muszą być dostępne
    available_recipes: list[Recipe] = []
    for recipe in all_recipes:
        if not recipe.ingredients:
            continue
        ingredient_product_ids = {
            ing.product_id for ing in recipe.ingredients if ing.product_id is not None
        }
        if ingredient_product_ids and ingredient_product_ids.issubset(available_product_ids):
            recipe.is_favorite = recipe.id in favorite_ids
            recipe.is_own_recipe = recipe.created_by_user_id == current_user.id
            available_recipes.append(recipe)

    # Paginacja w pamięci (po filtracji)
    return available_recipes[skip : skip + limit]


@router.get(
    "/mine",
    response_model=list[RecipeResponse],
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
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.created_by_user_id == current_user.id)
    )
    # Domyślne "newest" jest specyficzne dla tego widoku (własne przepisy
    # najwygodniej oglądać od ostatnio dodanych), pozostałe tryby są
    # wspólne z główną listą.
    if sort_by == "newest":
        query = query.order_by(Recipe.created_at.desc())
    else:
        query = _apply_recipe_sort(query, sort_by)

    result = await db.execute(query)
    recipes = list(result.unique().scalars().all())
    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
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
        )
        .where(Recipe.id == recipe_id)
    )
    recipe = result.scalar_one_or_none()
    if recipe is None:
        raise NotFoundException(
            detail=f"Przepis o ID {recipe_id} nie został znaleziony"
        )
    # Prywatne przepisy są widoczne TYLKO dla właściciela — chyba że są
    # publicznie zaakceptowane (visibility="public"). Próbę dostępu do
    # cudzego, nadal-prywatnego przepisu traktujemy jak nieistniejący,
    # żeby nie ujawniać nawet samego faktu jego istnienia.
    is_own = recipe.created_by_user_id == current_user.id
    is_public = recipe.visibility == "public"
    if recipe.created_by_user_id is not None and not is_own and not is_public:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")
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
    ale wymaga to konta Premium ORAZ akceptacji administratora, zanim
    faktycznie stanie się publiczny (patrz PUT /recipes/{id}/approve).
    """
    from app.core.premium import is_premium_active

    visibility = "private"
    if recipe_in.request_public:
        if not is_premium_active(current_user):
            raise HTTPException(
                status_code=403,
                detail="Zgłaszanie przepisów do wspólnego katalogu wymaga konta Premium.",
            )
        visibility = "pending"

    # UWAGA (naprawa): wcześniej brakujący/nieistniejący product_id w
    # składniku nie był w ogóle sprawdzany — dopiero baza danych odrzucała
    # to jako naruszenie klucza obcego, kończąc się nieobsłużonym błędem
    # 500 zamiast czytelnej odpowiedzi. Sprawdzamy WSZYSTKIE product_id na
    # raz (jedno zapytanie) PRZED zapisaniem czegokolwiek do bazy.
    if recipe_in.ingredients:
        requested_ids = {ing.product_id for ing in recipe_in.ingredients}
        existing_result = await db.execute(select(Product.id).where(Product.id.in_(requested_ids)))
        existing_ids = set(existing_result.scalars().all())
        missing_ids = requested_ids - existing_ids
        if missing_ids:
            raise HTTPException(
                status_code=400,
                detail=f"Nie znaleziono produktu/produktów: {', '.join(str(i) for i in missing_ids)}",
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


async def _notify_admins_pending_recipe(db: AsyncSession, recipe: Recipe, author: User) -> None:
    """Powiadamia WSZYSTKICH administratorów o nowym przepisie czekającym
    na akceptację do wspólnego katalogu."""
    from app.models.notification import Notification

    admins_result = await db.execute(select(User.id).where(User.role == "admin"))
    admin_ids = list(admins_result.scalars().all())
    if not admin_ids:
        return

    author_name = author.display_name or "Ktoś"
    message = f'{author_name} zgłosił(a) przepis "{recipe.name}" do wspólnego katalogu — wymaga akceptacji.'
    for admin_id in admin_ids:
        db.add(
            Notification(
                user_id=admin_id,
                notification_type="recipe_pending_approval",
                message=message,
                recipe_id=recipe.id,
            )
        )
    await db.commit()


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

        db.add(
            Notification(
                user_id=recipe.created_by_user_id,
                notification_type="recipe_approved",
                message=f'Twój przepis "{recipe.name}" został zaakceptowany i jest teraz widoczny dla wszystkich!',
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
) -> list[Recipe]:
    """Zwraca wszystkie przepisy oczekujące na akceptację administratora."""
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.visibility == "pending")
        .order_by(Recipe.created_at)
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
        validate_and_clean_recipe_dict,
    )

    provided = [bool(payload.text), bool(payload.photo_base64), bool(payload.url)]
    if sum(provided) != 1:
        raise HTTPException(
            status_code=400,
            detail="Podaj dokładnie jedno z: tekst przepisu, zdjęcie albo link.",
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
            detail=(
                f"Ta funkcja wymaga Premium albo 2 punktów (masz {current_user.premium_points}). "
                "Kup punkty w zakładce Premium."
            ),
        )

    enforce_user_rate_limit(ai_recipe_import_limiter, current_user.id, "rozpoznawanie przepisu przez AI")

    # Pełna lista nazw produktów — AI dobiera składniki WYŁĄCZNIE spośród
    # nich, żeby lista zakupów/porównanie cen dalej działały poprawnie
    # dla przepisów dodanych przez AI.
    products_result = await db.execute(select(Product.name))
    available_products = list(products_result.scalars().all())

    try:
        if payload.text:
            parsed = await extract_recipe_from_text(payload.text, available_products)
        elif payload.photo_base64:
            parsed = await extract_recipe_from_photo(
                payload.photo_base64, available_products, hint=payload.photo_hint
            )
        else:
            parsed = await extract_recipe_from_url(payload.url, available_products)
    except AIRecipeImportError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    parsed = validate_and_clean_recipe_dict(parsed)

    if not parsed["ingredients"]:
        raise HTTPException(
            status_code=422,
            detail="AI nie rozpoznało żadnych składników pasujących do dostępnych produktów.",
        )

    # UWAGA: rozpoznanie się UDAŁO — dopiero TERAZ, nie wcześniej,
    # pobieramy 2 punkty od kont bez Premium (jeśli user jest Premium,
    # nic się nie odejmuje — korzysta z funkcji w ramach subskrypcji).
    if not user_is_premium:
        current_user.premium_points -= 2
        db.add(current_user)

    # Zgłoszenie do wspólnego katalogu — jak przy ręcznym dodawaniu.
    visibility = "pending" if payload.request_public else "private"

    # Dopasuj nazwy produktów zwrócone przez AI do prawdziwych wierszy
    # Product (dokładne dopasowanie po nazwie, bez rozróżniania wielkości
    # liter — prompt instruuje AI, żeby używało DOKŁADNIE tych nazw).
    all_products_result = await db.execute(select(Product))
    products_by_name = {p.name.lower(): p for p in all_products_result.scalars().all()}

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
        visibility=visibility,
        # Jeśli przepis rozpoznano ZE ZDJĘCIA, to samo zdjęcie staje się
        # zdjęciem przepisu — to zwykle prawdziwe zdjęcie tego dania,
        # więc szkoda by było go nie wykorzystać.
        photo_base64=payload.photo_base64,
    )
    db.add(recipe)
    await db.flush()

    matched_count = 0
    for ing in parsed["ingredients"]:
        product = products_by_name.get(ing["product_name"].lower())
        if product is None:
            continue
        # UWAGA (naprawa): AI generuje przepisy niezależnie od schematu
        # Pydantic używanego przy ręcznym tworzeniu, więc bez tego
        # sprawdzenia mogłoby przemknąć się coś tak samo absurdalnego jak
        # "200 sztuk awokado" — ta sama funkcja co przy ręcznym/API
        # tworzeniu przepisu, żeby obie ścieżki łapały to samo. Cicho
        # pomijamy pojedynczy nierozsądny składnik (zamiast wywalać cały
        # import) — spójne z tym, jak już traktujemy niedopasowane
        # produkty kilka linijek wyżej.
        if not is_ingredient_quantity_reasonable(ing["quantity"], ing["unit"]):
            continue
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
            detail="Żaden ze składników rozpoznanych przez AI nie pasował do dostępnych produktów.",
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
    return final_recipe


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
    zostało odrzucone bez zmian — odrzucony przepis trzeba najpierw
    zedytować, żeby to miało sens, ale edycja przepisów to osobna,
    jeszcze nieistniejąca funkcja).
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

    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(_visibility_filter(current_user.id), Recipe.is_active == True)  # noqa: E712
    )
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
    recipe.pending_photo_base64 = None
    recipe.pending_photo_user_id = None
    recipe.pending_photo_submitted_at = None
    db.add(recipe)

    if submitter_id is not None:
        db.add(
            Notification(
                user_id=submitter_id,
                notification_type="recipe_photo",
                message=f'Twoje zdjęcie do przepisu "{recipe.name}" zostało zaakceptowane.',
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
        db.add(
            Notification(
                user_id=submitter_id,
                notification_type="recipe_photo",
                message=f'Twoje zdjęcie do przepisu "{recipe.name}" nie zostało zaakceptowane.',
                recipe_id=recipe.id,
            )
        )
    await db.commit()
