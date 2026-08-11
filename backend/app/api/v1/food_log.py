"""Endpointy dziennika żywieniowego (licznik kalorii i makroskładników).

UWAGA: cały ten moduł był wcześniej napisany synchronicznie (`def`, `db.execute`,
`db.commit()`), podczas gdy `get_db` dostarcza **asynchroniczną** sesję
SQLAlchemy. W efekcie każde wywołanie kończyło się błędem
`AttributeError: 'coroutine' object has no attribute 'scalars'`, czyli
odpowiedzią 500 — dziennik kalorii nie działał wcale.
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
        "calories": (n.get("calories", 0.0) or 0.0) * servings,
        "protein": (n.get("protein", 0.0) or 0.0) * servings,
        "fat": (n.get("fat", 0.0) or 0.0) * servings,
        "carbs": (n.get("carbohydrates", 0.0) or 0.0) * servings,
    }


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

    # Jeśli wskazano przepis, przelicz makro na podstawie jego wartości.
    if db_entry.recipe_id:
        recipe = await db.get(Recipe, db_entry.recipe_id)
        if recipe:
            macros = _macros_from_recipe(recipe, entry_in.servings)
            db_entry.calories = macros["calories"]
            db_entry.protein = macros["protein"]
            db_entry.fat = macros["fat"]
            db_entry.carbs = macros["carbs"]

    db.add(db_entry)
    await db.commit()
    await db.refresh(db_entry)
    return db_entry


@router.get("/", response_model=List[FoodLogEntryResponse])
async def read_food_log_entries(
    entry_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(FoodLogEntry).where(FoodLogEntry.user_id == current_user.id)
    if entry_date:
        query = query.where(FoodLogEntry.date == entry_date)
    query = query.order_by(FoodLogEntry.created_at)

    result = await db.execute(query)
    return result.scalars().all()


@router.get("/summary", response_model=DailySummaryResponse)
async def get_daily_summary(
    entry_date: date,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(FoodLogEntry).where(
        FoodLogEntry.user_id == current_user.id,
        FoodLogEntry.date == entry_date,
    )
    result = await db.execute(query)
    entries = result.scalars().all()

    summary = DailySummaryResponse(date=entry_date, entries=entries)
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

    # UWAGA: poprzednia wersja odwoływała się do pól, których model nie ma
    # (`plan_entry.meal_type`, `plan_entry.servings`, `plan_entry.meal_plan.date`).
    # Rzeczywiste nazwy to `meal_slot`, `servings_multiplier` oraz
    # `meal_plan.start_date` + `day_number`.
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
    return db_entry
