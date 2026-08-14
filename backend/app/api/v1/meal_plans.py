"""Endpointy planów posiłków — generowanie, przeglądanie, modyfikacja."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import MealPlan, MealPlanEntry, ShoppingList, User, Recipe, RecipeIngredient
from app.schemas.meal_plan import (
    MealPlanGenerateRequest,
    MealPlanResponse,
)
from app.services import MealPlanGenerator, ShoppingListBuilder

router = APIRouter()


class StatusUpdate(BaseModel):
    """Schemat aktualizacji statusu planu posiłków."""

    model_config = ConfigDict(from_attributes=True)

    status: str  # active, completed, archived


class StoreUpdate(BaseModel):
    """Schemat zmiany sklepu przypisanego do planu posiłków."""

    model_config = ConfigDict(from_attributes=True)

    store_id: UUID


class RecipeSwap(BaseModel):
    """Schemat zamiany przepisu w planie posiłków."""

    model_config = ConfigDict(from_attributes=True)

    recipe_id: UUID


@router.post(
    "/generate",
    response_model=MealPlanResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Wygeneruj plan posiłków",
)
async def generate_meal_plan(
    request: MealPlanGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MealPlan:
    """Generuje plan posiłków na podstawie preferencji użytkownika.

    Używa serwisu ``MealPlanGenerator`` do inteligentnego doboru
    przepisów z uwzględnieniem alergenów, dostępności produktów
    i różnorodności składników.

    Limit: 15 wywołań na godzinę na użytkownika — to kosztowna operacja
    (przeszukuje cały katalog przepisów, liczy scoring, buduje listę
    zakupów), bez limitu można by zasypać serwer żądaniami.
    """
    from app.core.rate_limit import enforce_user_rate_limit, meal_plan_generation_limiter
    from app.services.exceptions import ServiceError

    enforce_user_rate_limit(meal_plan_generation_limiter, current_user.id, "generowanie planu posiłków")

    try:
        generator = MealPlanGenerator(db)
        meal_plan = await generator.generate(
            user_id=current_user.id,
            store_id=request.store_id,
            duration_days=request.duration_days,
            meals_per_day=request.meals_per_day,
            max_budget=request.max_budget,
            preferences=request.preferences,
            household_size=request.household_size,
            target_kcal=request.target_kcal,
        )
        return meal_plan
    except ServiceError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get(
    "/",
    response_model=list[MealPlanResponse],
    summary="Lista planów posiłków użytkownika",
)
async def list_meal_plans(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MealPlan]:
    """Zwraca wszystkie plany posiłków bieżącego użytkownika."""
    result = await db.execute(
        select(MealPlan)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product),
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.tags)
        )
        .where(MealPlan.user_id == current_user.id)
        .order_by(MealPlan.created_at.desc())
    )
    return list(result.unique().scalars().all())


@router.get(
    "/{plan_id}",
    response_model=MealPlanResponse,
    summary="Szczegóły planu posiłków",
)
async def get_meal_plan(
    plan_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MealPlan:
    """Zwraca plan posiłków z pozycjami (przepisami przypisanymi do slotów)."""
    result = await db.execute(
        select(MealPlan)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product),
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.tags)
        )
        .where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(
            detail=f"Plan posiłków o ID {plan_id} nie został znaleziony"
        )
    return plan


@router.put(
    "/{plan_id}/store",
    response_model=MealPlanResponse,
    summary="Zmień sklep przypisany do planu posiłków i przelicz listę zakupów",
)
async def update_meal_plan_store(
    plan_id: UUID,
    payload: StoreUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MealPlan:
    """Zmienia sklep, do którego przypisany jest plan, i przelicza listę
    zakupów pod nowe ceny/działy.

    Wcześniej takiego endpointu w ogóle nie było — w ekranie porównania
    cen dało się zobaczyć, że inny sklep wypada taniej, ale nie dało się
    nic z tym zrobić (dotknięcie innego sklepu nic nie robiło, bo nie
    było go do czego podpiąć).
    """
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail=f"Plan posiłków o ID {plan_id} nie został znaleziony")

    from app.models import Store

    store_result = await db.execute(select(Store).where(Store.id == payload.store_id))
    if store_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Sklep nie został znaleziony")

    plan.store_id = payload.store_id

    shopping_list_result = await db.execute(
        select(ShoppingList).where(ShoppingList.meal_plan_id == plan_id)
    )
    shopping_list = shopping_list_result.scalar_one_or_none()
    if shopping_list is not None:
        shopping_list.store_id = payload.store_id

    await db.commit()

    if shopping_list is not None:
        builder = ShoppingListBuilder(db)
        await builder.recalculate(shopping_list.id)

    # Przeładuj plan z relacjami
    result = await db.execute(
        select(MealPlan)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product),
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.tags),
        )
        .where(MealPlan.id == plan_id)
    )
    return result.scalar_one()


@router.put(
    "/{plan_id}/status",
    response_model=MealPlanResponse,
    summary="Zmień status planu posiłków",
)
async def update_meal_plan_status(
    plan_id: UUID,
    payload: StatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MealPlan:
    """Aktualizuje status planu posiłków (aktywny, ukończony, zarchiwizowany).

    Dozwolone wartości: ``active``, ``completed``, ``archived``.
    """
    allowed_statuses = {"active", "completed", "archived"}
    if payload.status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Nieprawidłowy status. Dozwolone: {', '.join(sorted(allowed_statuses))}",
        )

    result = await db.execute(
        select(MealPlan)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product),
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.tags)
        )
        .where(
            MealPlan.id == plan_id, MealPlan.user_id == current_user.id
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(
            detail=f"Plan posiłków o ID {plan_id} nie został znaleziony"
        )

    plan.status = payload.status
    db.add(plan)
    await db.commit()
    
    # Przeładuj obiekt z relacjami
    result = await db.execute(
        select(MealPlan)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product),
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.tags)
        )
        .where(MealPlan.id == plan_id)
    )
    return result.scalar_one()


@router.put(
    "/{plan_id}/entries/{entry_id}/swap",
    response_model=MealPlanResponse,
    summary="Zamień przepis w planie",
)
async def swap_recipe_in_plan(
    plan_id: UUID,
    entry_id: UUID,
    payload: RecipeSwap,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MealPlan:
    """Zamienia przepis w pozycji planu posiłków i przelicza listę zakupów.

    Po zamianie przepisu serwis ``ShoppingListBuilder`` ponownie
    generuje listę zakupów z uwzględnieniem nowego przepisu.
    """
    # Pobierz plan z weryfikacją właściciela
    plan_result = await db.execute(
        select(MealPlan)
        .options(selectinload(MealPlan.entries), selectinload(MealPlan.shopping_list))
        .where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = plan_result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(
            detail=f"Plan posiłków o ID {plan_id} nie został znaleziony"
        )

    # Znajdź pozycję do zamiany
    entry_result = await db.execute(
        select(MealPlanEntry).where(
            MealPlanEntry.id == entry_id,
            MealPlanEntry.meal_plan_id == plan_id,
        )
    )
    entry = entry_result.scalar_one_or_none()
    if entry is None:
        raise NotFoundException(
            detail=f"Pozycja planu o ID {entry_id} nie została znaleziona",
        )

    # Zamień przepis
    entry.recipe_id = payload.recipe_id
    db.add(entry)
    await db.flush()

    # Przelicz listę zakupów
    if plan.shopping_list is not None:
        shopping_list_builder = ShoppingListBuilder(db)
        await shopping_list_builder.recalculate(plan.shopping_list.id)
    else:
        shopping_list_builder = ShoppingListBuilder(db)
        await shopping_list_builder.build_from_meal_plan(plan.id)

    await db.commit()

    # Załaduj ponownie z relacjami
    result = await db.execute(
        select(MealPlan)
        .options(
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.ingredients)
            .selectinload(RecipeIngredient.product),
            selectinload(MealPlan.entries)
            .selectinload(MealPlanEntry.recipe)
            .selectinload(Recipe.tags)
        )
        .where(MealPlan.id == plan_id)
    )
    return result.scalar_one()


@router.delete(
    "/{plan_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Usuń plan posiłków",
)
async def delete_meal_plan(
    plan_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Usuwa plan posiłków wraz z powiązanymi pozycjami i listą zakupów."""
    result = await db.execute(
        select(MealPlan).where(
            MealPlan.id == plan_id, MealPlan.user_id == current_user.id
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(
            detail=f"Plan posiłków o ID {plan_id} nie został znaleziony"
        )

    await db.delete(plan)
    await db.commit()
