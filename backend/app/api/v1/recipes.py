"""Endpointy przepisów kulinarnych."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_premium, get_current_user
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
from app.schemas.recipe import AIRecipeImportRequest, RecipeCreate, RecipeResponse

router = APIRouter()


async def _get_favorite_recipe_ids(db: AsyncSession, user_id: UUID) -> set[UUID]:
    """Zwraca zbiór ID przepisów, które użytkownik ma w ulubionych."""
    from app.models import RecipeFavorite

    result = await db.execute(
        select(RecipeFavorite.recipe_id).where(RecipeFavorite.user_id == user_id)
    )
    return set(result.scalars().all())


def _visibility_filter(current_user_id: UUID):
    """Warunek widoczności przepisu: wspólny katalog (created_by_user_id
    puste) LUB własny, prywatny przepis dodany przez AI."""
    return or_(Recipe.created_by_user_id.is_(None), Recipe.created_by_user_id == current_user_id)


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
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    """Zwraca listę przepisów z możliwością filtrowania.

    Obsługuje filtrowanie po typie posiłku, kuchni, trudności,
    tagach, maksymalnym czasie przygotowania oraz wyszukiwanie pełnotekstowe.
    """
    query = select(Recipe).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
        selectinload(Recipe.tags),
    ).where(_visibility_filter(current_user.id))

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

    if tags:
        query = query.join(Recipe.tags).where(RecipeTag.tag.in_(tags))

    query = query.order_by(Recipe.name).offset(skip).limit(limit)

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
    recipes_result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(_visibility_filter(current_user.id))
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    """Zwraca WYŁĄCZNIE przepisy dodane przez zalogowanego użytkownika
    (przez AI) — nie miesza ich ze wspólnym katalogiem 81 oficjalnych
    przepisów."""
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.created_by_user_id == current_user.id)
        .order_by(Recipe.created_at.desc())
    )
    recipes = list(result.unique().scalars().all())
    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
    for recipe in recipes:
        recipe.is_favorite = recipe.id in favorite_ids
        recipe.is_own_recipe = True
    return recipes


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
    # Prywatne przepisy (dodane przez AI) są widoczne TYLKO dla właściciela
    # — traktujemy próbę dostępu do cudzego jak nieistniejący przepis,
    # żeby nie ujawniać nawet samego faktu jego istnienia.
    if recipe.created_by_user_id is not None and recipe.created_by_user_id != current_user.id:
        raise NotFoundException(detail=f"Przepis o ID {recipe_id} nie został znaleziony")
    favorite_ids = await _get_favorite_recipe_ids(db, current_user.id)
    recipe.is_favorite = recipe.id in favorite_ids
    recipe.is_own_recipe = recipe.created_by_user_id == current_user.id
    return recipe


@router.post(
    "/",
    response_model=RecipeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Utwórz nowy przepis",
)
async def create_recipe(
    recipe_in: RecipeCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Tworzy nowy przepis z listą składników.

    UWAGA (naprawa bezpieczeństwa): wcześniej ten endpoint w ogóle nie
    wymagał zalogowania — dosłownie każdy w internecie, bez konta, mógł
    zaśmiecać bazę fałszywymi przepisami. Teraz wymaga przynajmniej
    zalogowania. To wciąż nie jest docelowy model uprawnień dla funkcji
    "dodaj własny przepis" (zapowiedzianej w aplikacji, ale jeszcze
    niezbudowanej od strony UI) — gdy ta funkcja powstanie, prawdopodobnie
    będzie też potrzebować moderacji/oznaczenia autora, zanim przepis
    trafi do wspólnego katalogu widocznego dla wszystkich.
    """
    recipe = Recipe(
        name=recipe_in.name,
        description=recipe_in.description,
        meal_type=recipe_in.meal_type,
        cuisine=recipe_in.cuisine,
        difficulty=recipe_in.difficulty,
        prep_time_min=recipe_in.prep_time_min,
        cook_time_min=recipe_in.cook_time_min,
        servings=recipe_in.servings,
        image_url=getattr(recipe_in, "image_url", None),
    )
    db.add(recipe)
    await db.flush()

    # Dodaj składniki
    if hasattr(recipe_in, "ingredients") and recipe_in.ingredients:
        for ing_data in recipe_in.ingredients:
            ingredient = RecipeIngredient(
                recipe_id=recipe.id,
                product_id=ing_data.product_id,
                quantity=ing_data.quantity,
                unit=ing_data.unit,
                is_optional=getattr(ing_data, "is_optional", False),
            )
            db.add(ingredient)

    # Dodaj tagi
    if hasattr(recipe_in, "tags") and recipe_in.tags:
        for tag_name in recipe_in.tags:
            tag = RecipeTag(recipe_id=recipe.id, tag=tag_name)
            db.add(tag)

    await db.commit()

    # Załaduj ponownie z relacjami
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
        )
        .where(Recipe.id == recipe.id)
    )
    return result.scalar_one()


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
    summary="Rozpoznaj i dodaj przepis przez AI (Premium)",
)
async def ai_import_recipe(
    payload: AIRecipeImportRequest,
    current_user: User = Depends(get_current_premium),
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Rozpoznaje przepis z wklejonego tekstu ALBO zdjęcia i tworzy z niego
    nowy, PRYWATNY przepis (widoczny tylko dla Ciebie — nie trafia
    automatycznie do wspólnego katalogu).

    Funkcja Premium. Limit: 20 wywołań/dzień (niezależnie od statusu
    premium) — każde wywołanie kosztuje realne pieniądze (API Anthropic).
    """
    from app.core.rate_limit import ai_recipe_import_limiter, enforce_user_rate_limit
    from app.services.ai_recipe_import import (
        AIRecipeImportError,
        extract_recipe_from_photo,
        extract_recipe_from_text,
        validate_and_clean_recipe_dict,
    )

    if not payload.text and not payload.photo_base64:
        raise HTTPException(
            status_code=400, detail="Podaj tekst przepisu albo zdjęcie (dokładnie jedno z nich)"
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
        else:
            parsed = await extract_recipe_from_photo(payload.photo_base64, available_products)
    except AIRecipeImportError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    parsed = validate_and_clean_recipe_dict(parsed)

    if not parsed["ingredients"]:
        raise HTTPException(
            status_code=422,
            detail="AI nie rozpoznało żadnych składników pasujących do dostępnych produktów.",
        )

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
    )
    db.add(recipe)
    await db.flush()

    matched_count = 0
    for ing in parsed["ingredients"]:
        product = products_by_name.get(ing["product_name"].lower())
        if product is None:
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
    final_recipe.is_own_recipe = True
    return final_recipe
