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

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.core.exceptions import NotFoundException
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

# Darmowe konta widzą tylko ostatnie 30 dni historii śledzenia — konta
# premium mają dostęp bez ograniczeń wstecz w czasie.
FREE_TIER_HISTORY_DAYS = 7


def _enforce_history_limit(entry_date: Optional[date], current_user: User) -> None:
    """Blokuje dostęp do wpisów starszych niż FREE_TIER_HISTORY_DAYS dla
    kont bez aktywnego premium. Dodawanie NOWYCH wpisów nie jest tu
    ograniczane — to dotyczy tylko PRZEGLĄDANIA starej historii."""
    if entry_date is None:
        return
    from app.core.premium import is_premium_active

    if is_premium_active(current_user):
        return
    oldest_allowed = date.today() - timedelta(days=FREE_TIER_HISTORY_DAYS)
    if entry_date < oldest_allowed:
        raise HTTPException(
            status_code=403,
            detail=(
                f"Darmowe konto ma dostęp do ostatnich {FREE_TIER_HISTORY_DAYS} dni historii. "
                "Odblokuj Premium, aby zobaczyć starsze wpisy."
            ),
        )


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
        # UWAGA (naprawa): wcześniej brak przepisu o podanym recipe_id był
        # cicho ignorowany — kod po prostu pomijał automatyczne przeliczenie
        # wartości odżywczych, ale NADAL próbował zapisać wpis z
        # nieistniejącym recipe_id, co naruszało klucz obcy w bazie i
        # kończyło się nieobsłużonym błędem 500 zamiast czytelnej
        # odpowiedzi 404.
        if not recipe:
            raise NotFoundException(detail=f"Nie znaleziono przepisu o ID {db_entry.recipe_id}")
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
    _enforce_history_limit(entry_date, current_user)

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
    _enforce_history_limit(entry_date, current_user)

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
    # Opcjonalna, jawnie podana data — jeśli obecna, ma pierwszeństwo przed
    # datą wyliczoną z harmonogramu planu (start_date + numer dnia).
    # Wcześniej brak tego parametru sprawiał, że nawet gdy użytkownik
    # przeglądał w "Śledzeniu" inny dzień niż dziś, dodanie posiłku z
    # planu i tak zapisywało się pod datą wynikającą z harmonogramu, co
    # w praktyce mogło rozjechać się z tym, co widział na ekranie.
    entry_date_override: Optional[date] = Query(None, alias="date"),
    # UWAGA (naprawa): wcześniej liczba porcji przy logowaniu z planu
    # ZAWSZE była tym, co zapisano w planie (servings_multiplier) — nie
    # było jak powiedzieć "zjadłem tylko połowę" albo "zjadłem podwójną
    # porcję". Ten opcjonalny parametr, jeśli podany, NADPISUJE wartość
    # z planu.
    servings_override: Optional[float] = Query(None, ge=0.1, le=20, alias="servings"),
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

    servings = servings_override if servings_override is not None else float(plan_entry.servings_multiplier or 1)
    macros = _macros_from_recipe(plan_entry.recipe, servings)

    if entry_date_override is not None:
        entry_date = entry_date_override
    else:
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
