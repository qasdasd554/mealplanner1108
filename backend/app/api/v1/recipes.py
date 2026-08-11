"""Endpointy przepisów kulinarnych."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import (
    Product,
    Recipe,
    RecipeIngredient,
    RecipeTag,
    StoreProduct,
)
from app.schemas.recipe import RecipeCreate, RecipeResponse

router = APIRouter()


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
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    """Zwraca listę przepisów z możliwością filtrowania.

    Obsługuje filtrowanie po typie posiłku, kuchni, trudności,
    tagach, maksymalnym czasie przygotowania oraz wyszukiwanie pełnotekstowe.
    """
    query = select(Recipe).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
        selectinload(Recipe.tags),
    )

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
    return list(result.unique().scalars().all())


@router.get(
    "/available",
    response_model=list[RecipeResponse],
    summary="Przepisy z dostępnymi składnikami",
)
async def list_available_recipes(
    store_id: UUID = Query(..., description="ID sklepu do sprawdzenia dostępności"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
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
        .order_by(Recipe.name)
    )
    all_recipes = recipes_result.unique().scalars().all()

    # Filtruj przepisy — wszystkie składniki muszą być dostępne
    available_recipes: list[Recipe] = []
    for recipe in all_recipes:
        if not recipe.ingredients:
            continue
        ingredient_product_ids = {
            ing.product_id for ing in recipe.ingredients if ing.product_id is not None
        }
        if ingredient_product_ids and ingredient_product_ids.issubset(available_product_ids):
            available_recipes.append(recipe)

    # Paginacja w pamięci (po filtracji)
    return available_recipes[skip : skip + limit]


@router.get(
    "/{recipe_id}",
    response_model=RecipeResponse,
    summary="Szczegóły przepisu",
)
async def get_recipe(
    recipe_id: UUID,
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
    return recipe


@router.post(
    "/",
    response_model=RecipeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Utwórz nowy przepis",
)
async def create_recipe(
    recipe_in: RecipeCreate,
    db: AsyncSession = Depends(get_db),
) -> Recipe:
    """Tworzy nowy przepis z listą składników.

    MVP: nie wymaga autoryzacji administratora.
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
