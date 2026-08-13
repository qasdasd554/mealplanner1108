"""Endpointy dziennika żywieniowego (licznik kalorii i makroskładników).

Historia napraw:
* Cały moduł był kiedyś napisany synchronicznie na asynchronicznej sesji
  SQLAlchemy — każde wywołanie kończyło się błędem 500.
* Odpowiedzi nie zawierały nazwy przepisu (tylko `recipe_id` — surowy UUID),
  więc aplikacja nie miała jak pokazać, co użytkownik zjadł. Dodano pole
  `recipe_name`, wypełniane z załadowanej relacji `recipe`.
"""

import uuid
from datetime import date, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.models.food_log import FoodLogEntry
from app.models.meal_plan import MealPlanEntry
from app.models.recipe import Recipe
from app.models.user import User
from app.schemas.food_log import (
    DailySummaryResponse,
    FoodLogEntryCreate,
    FoodLogEntryResponse,
)

router = APIRouter()


def _macros_from_recipe(recipe: Optional[Recipe], servings: float) -> dict:
    """Przelicza makroskładniki przepisu na podaną liczbę porcji."""
    if not recipe or not recipe.nutrition_total:
        return {"calories": 0.0, "protein": 0.0, "fat": 0.0, "carbs": 0.0}
    n = recipe.nutrition_total
    return {
        "calories": (n.get("kcal", n.get("calories", 0.0)) or 0.0) * servings,
        "protein": (n.get("protein", 0.0) or 0.0) * servings,
        "fat": (n.get("fat", 0.0) or 0.0) * servings,
        "carbs": (n.get("carbs", n.get("carbohydrates", 0.0)) or 0.0) * servings,
    }


def _to_response(entry: FoodLogEntry) -> FoodLogEntryResponse:
    """Buduje odpowiedź API, dołączając nazwę przepisu (jeśli wpis go ma)."""
    return FoodLogEntryResponse(
        id=entry.id,
        user_id=entry.user_id,
        date=entry.date,
        meal_type=entry.meal_type,
        recipe_id=entry.recipe_id,
        custom_name=entry.custom_name,
        calories=entry.calories,
        protein=entry.protein,
        fat=entry.fat,
        carbs=entry.carbs,
        servings=entry.servings,
        created_at=entry.created_at,
        recipe_name=entry.recipe.name if entry.recipe_id and entry.recipe else None,
    )


@router.post("/", response_model=FoodLogEntryResponse, status_code=status.HTTP_201_CREATED)
async def create_food_log_entry(
    entry_in: FoodLogEntryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not entry_in.recipe_id and not entry_in.custom_name:
        raise HTTPException(
            status_code=400,
            detail="Podaj przepis (recipe_id) albo własną nazwę posiłku (custom_name)",
        )

    db_entry = FoodLogEntry(**entry_in.model_dump(), user_id=current_user.id)

    recipe: Optional[Recipe] = None
    if db_entry.recipe_id:
        recipe = await db.get(Recipe, db_entry.recipe_id)
        if recipe:
            # Jeśli formularz nie podał gotowych wartości (np. dodanie
            # "z przepisu" bez ręcznego wpisania kalorii), przelicz je
            # automatycznie na podstawie przepisu i liczby porcji.
            #
            # UWAGA: `recipe.nutrition_total` to wartości odżywcze dla
            # CAŁEGO przepisu (np. przepis na 4 porcje ma nutrition_total
            # dla wszystkich 4 porcji razem), a `entry_in.servings` to
            # liczba porcji, które użytkownik faktycznie zjadł (z UI:
            # "Liczba porcji", domyślnie 1). Trzeba więc przeliczyć na
            # UŁAMEK całego przepisu — inaczej "1 porcja" dawała kalorie
            # całego przepisu (np. dla przepisu na 4 porcje wychodziło
            # 4x za dużo, sprawiając wrażenie, jakby zawsze dodawało
            # "więcej niż jedną porcję").
            recipe_servings = float(recipe.servings or 1)
            recipe_fraction = entry_in.servings / recipe_servings if recipe_servings else entry_in.servings
            if entry_in.calories == 0.0 and entry_in.protein == 0.0:
                macros = _macros_from_recipe(recipe, recipe_fraction)
                db_entry.calories = macros["calories"]
                db_entry.protein = macros["protein"]
                db_entry.fat = macros["fat"]
                db_entry.carbs = macros["carbs"]

    db.add(db_entry)
    await db.commit()
    await db.refresh(db_entry)
    db_entry.recipe = recipe
    return _to_response(db_entry)


@router.get("/", response_model=List[FoodLogEntryResponse])
async def read_food_log_entries(
    entry_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = (
        select(FoodLogEntry)
        .where(FoodLogEntry.user_id == current_user.id)
        .options(selectinload(FoodLogEntry.recipe))
    )
    if entry_date:
        query = query.where(FoodLogEntry.date == entry_date)
    query = query.order_by(FoodLogEntry.created_at)

    result = await db.execute(query)
    entries = result.scalars().all()
    return [_to_response(e) for e in entries]


@router.get("/summary", response_model=DailySummaryResponse)
async def get_daily_summary(
    entry_date: date,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = (
        select(FoodLogEntry)
        .where(
            FoodLogEntry.user_id == current_user.id,
            FoodLogEntry.date == entry_date,
        )
        .options(selectinload(FoodLogEntry.recipe))
    )
    result = await db.execute(query)
    entries = result.scalars().all()

    responses = [_to_response(e) for e in entries]
    summary = DailySummaryResponse(date=entry_date, entries=responses)
    for entry in entries:
        summary.total_calories += entry.calories
        summary.total_protein += entry.protein
        summary.total_fat += entry.fat
        summary.total_carbs += entry.carbs

    return summary


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_food_log_entry(
    entry_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = await db.get(FoodLogEntry, entry_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Nie znaleziono wpisu w dzienniku")
    if entry.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Brak uprawnień do usunięcia tego wpisu")

    await db.delete(entry)
    await db.commit()


@router.post(
    "/from-plan-entry/{meal_plan_entry_id}",
    response_model=FoodLogEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_from_meal_plan_entry(
    meal_plan_entry_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Relacje ładujemy od razu (selectinload) — w trybie asynchronicznym
    # leniwe doczytywanie `plan_entry.meal_plan` / `.recipe` rzuciłoby
    # MissingGreenlet.
    result = await db.execute(
        select(MealPlanEntry)
        .where(MealPlanEntry.id == meal_plan_entry_id)
        .options(
            selectinload(MealPlanEntry.meal_plan),
            selectinload(MealPlanEntry.recipe),
        )
    )
    plan_entry = result.scalar_one_or_none()

    if not plan_entry:
        raise HTTPException(status_code=404, detail="Nie znaleziono pozycji planu posiłków")

    if plan_entry.meal_plan.user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Brak uprawnień do tej pozycji planu posiłków"
        )

    servings = float(plan_entry.servings_multiplier or 1)
    macros = _macros_from_recipe(plan_entry.recipe, servings)

    # Dzień wpisu = data startu planu + (numer dnia - 1); day_number liczony od 1.
    entry_date = plan_entry.meal_plan.start_date + timedelta(
        days=max((plan_entry.day_number or 1) - 1, 0)
    )

    db_entry = FoodLogEntry(
        user_id=current_user.id,
        date=entry_date,
        meal_type=plan_entry.meal_slot,
        recipe_id=plan_entry.recipe_id,
        servings=servings,
        calories=macros["calories"],
        protein=macros["protein"],
        fat=macros["fat"],
        carbs=macros["carbs"],
    )

    db.add(db_entry)
    await db.commit()
    await db.refresh(db_entry)
    db_entry.recipe = plan_entry.recipe
    return _to_response(db_entry)
