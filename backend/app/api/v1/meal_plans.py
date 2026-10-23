"""Endpointy planów posiłków — generowanie, przeglądanie, modyfikacja."""

from copy import deepcopy
from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import (
    MealPlan,
    MealPlanEntry,
    ShoppingList,
    User,
    Recipe,
    RecipeIngredient,
    WeeklyPlanAutomation,
)
from app.schemas.meal_plan import (
    MealPlanGenerateRequest,
    MealPlanResponse,
)
from app.services import MealPlanGenerator, ShoppingListBuilder
from app.core.premium import is_premium_active
from app.core.market_clock import market_today
from app.core.markets import account_country
from app.services.store_market_access import get_store_in_account_market
from app.services.market_catalog import ensure_recipe_available_in_market
from app.services.meal_plan_lifecycle import (
    CURRENT_STATUSES,
    WARSAW,
    plan_has_expired,
    process_due_meal_plans,
)

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


class ResumeMealPlanRequest(BaseModel):
    start_date: date


def _ensure_plan_access(plan: MealPlan, user: User, *, editable: bool = False) -> None:
    """Żaden stary link ani endpoint statusu nie odblokuje wygasłego planu."""
    if plan.status == "expired":
        raise NotFoundException(detail="Ten plan posiłków już się zakończył.")


    if plan.status == "archived":
        if plan.archived_at is None:
            # Techniczne plany będące właścicielem samodzielnej listy zakupów.
            raise NotFoundException(detail=("Meal plan not found." if account_country(user) == "GB" else "Plan posiłków nie został znaleziony."))
        if not is_premium_active(user):
            raise HTTPException(status_code=403, detail=("Plan archives are available with Premium." if account_country(user) == "GB" else "Archiwum planów jest dostępne w Premium."))
        if editable:
            raise HTTPException(status_code=409, detail="Wznów plan z archiwum, aby ponownie z niego korzystać.")
    elif plan.status not in CURRENT_STATUSES or plan_has_expired(plan, country_code=account_country(user)):
        raise NotFoundException(detail="Ten plan posiłków już się zakończył.")


def _stored_household_size(value) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if 1 <= value <= 20 else None
    if isinstance(value, str):
        text = value.strip()
        if 1 <= len(text) <= 2 and text.isascii() and text.isdigit():
            parsed = int(text)
            return parsed if 1 <= parsed <= 20 else None
    return None


class WeeklyAutomationUpdate(BaseModel):
    enabled: bool
    weekday: int = Field(default=6, ge=0, le=6)
    hour: int = Field(default=18, ge=0, le=23)
    create_shopping_list: bool = True


class WeeklyAutomationResponse(BaseModel):
    enabled: bool
    weekday: int
    hour: int
    create_shopping_list: bool
    last_success_at: str | None = None
    last_error: str | None = None
    last_plan_id: str | None = None


def _automation_response(
    automation: WeeklyPlanAutomation | None,
) -> WeeklyAutomationResponse:
    return WeeklyAutomationResponse(
        enabled=automation.enabled if automation else False,
        weekday=automation.weekday if automation else 6,
        hour=automation.hour if automation else 18,
        create_shopping_list=(
            automation.create_shopping_list if automation else True
        ),
        last_success_at=(
            automation.last_success_at.isoformat()
            if automation and automation.last_success_at
            else None
        ),
        last_error=automation.last_error if automation else None,
        last_plan_id=(
            str(automation.last_plan_id)
            if automation and automation.last_plan_id
            else None
        ),
    )


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

    Limity:
    - Techniczny (wszyscy): 15 wywołań/godzinę — ochrona przed zasypaniem
      serwera żądaniami.
    - Biznesowy (tylko konta bez Premium): jeden NOWY plan w tygodniu
      kalendarzowym. Usunięcie planu nie odnawia limitu. Premium nie ma
      limitu liczby planów.
    """
    from app.core.rate_limit import enforce_user_rate_limit, meal_plan_generation_limiter
    from app.services.exceptions import ServiceError
    from app.services.meal_plan_quota import ensure_can_create_meal_plan

    enforce_user_rate_limit(meal_plan_generation_limiter, current_user.id, "generowanie planu posiłków")
    await ensure_can_create_meal_plan(db, user=current_user)

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
            include_pantry=request.include_pantry,
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
    """Zwraca bieżące plany; archiwum Premium ma osobny endpoint."""
    await process_due_meal_plans(db, user_id=current_user.id, send_reminders=False)
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
            MealPlan.user_id == current_user.id,
            MealPlan.status.in_(CURRENT_STATUSES),
        )
        .order_by(MealPlan.created_at.desc())
    )
    return [plan for plan in result.unique().scalars().all() if not plan_has_expired(plan, country_code=account_country(current_user))]


@router.get(
    "/archive",
    response_model=list[MealPlanResponse],
    summary="Archiwum planów Premium",
)
async def list_archived_meal_plans(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MealPlan]:
    if not is_premium_active(current_user):
        raise HTTPException(status_code=403, detail=("Plan archives are available with Premium." if account_country(current_user) == "GB" else "Archiwum planów jest dostępne w Premium."))
    await process_due_meal_plans(db, user_id=current_user.id, send_reminders=False)
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
        .where(
            MealPlan.user_id == current_user.id,
            MealPlan.status == "archived",
            MealPlan.archived_at.is_not(None),
        )
        .order_by(MealPlan.archived_at.desc())
    )
    return list(result.unique().scalars().all())


@router.get(
    "/automation",
    response_model=WeeklyAutomationResponse,
    summary="Ustawienia automatycznego tygodnia Premium",
)
async def get_weekly_automation(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WeeklyAutomationResponse:
    result = await db.execute(
        select(WeeklyPlanAutomation).where(
            WeeklyPlanAutomation.user_id == current_user.id
        )
    )
    return _automation_response(result.scalar_one_or_none())


@router.put(
    "/automation",
    response_model=WeeklyAutomationResponse,
    summary="Zapisz automatyczny tydzień Premium",
)
async def update_weekly_automation(
    payload: WeeklyAutomationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WeeklyAutomationResponse:
    from app.core.premium import is_premium_active

    if payload.enabled and not is_premium_active(current_user):
        raise HTTPException(
            status_code=403,
            detail=("Automatic weekly planning is available with Premium." if account_country(current_user) == "GB" else "Automatyczny tydzień jest dostępny w Premium."),
        )
    result = await db.execute(
        select(WeeklyPlanAutomation).where(
            WeeklyPlanAutomation.user_id == current_user.id
        )
    )
    automation = result.scalar_one_or_none()
    if automation is None:
        automation = WeeklyPlanAutomation(user_id=current_user.id)
    automation.enabled = payload.enabled
    automation.weekday = payload.weekday
    automation.hour = payload.hour
    automation.create_shopping_list = payload.create_shopping_list
    db.add(automation)
    await db.commit()
    await db.refresh(automation)
    return _automation_response(automation)


@router.post(
    "/automation/run-now",
    response_model=WeeklyAutomationResponse,
    summary="Utwórz automatyczny plan teraz",
)
async def run_weekly_automation_now(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WeeklyAutomationResponse:
    from app.core.premium import is_premium_active
    from app.core.rate_limit import enforce_user_rate_limit, meal_plan_generation_limiter
    from app.services.weekly_plan_automation import generate_for_user

    if not is_premium_active(current_user):
        raise HTTPException(status_code=403, detail=("This feature requires Premium." if account_country(current_user) == "GB" else "Ta funkcja wymaga Premium."))
    enforce_user_rate_limit(
        meal_plan_generation_limiter,
        current_user.id,
        "automatyczne generowanie planu",
    )
    result = await db.execute(
        select(WeeklyPlanAutomation).where(
            WeeklyPlanAutomation.user_id == current_user.id
        )
    )
    automation = result.scalar_one_or_none()
    if automation is None:
        automation = WeeklyPlanAutomation(user_id=current_user.id, enabled=True)
        db.add(automation)
        await db.commit()
        await db.refresh(automation)
    await generate_for_user(db, automation, current_user)
    await db.refresh(automation)
    return _automation_response(automation)


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
    await process_due_meal_plans(db, user_id=current_user.id, send_reminders=False)
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
    _ensure_plan_access(plan, current_user)
    return plan


@router.post(
    "/{plan_id}/resume",
    response_model=MealPlanResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Wznów plan z archiwum Premium",
)
async def resume_meal_plan(
    plan_id: UUID,
    payload: ResumeMealPlanRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MealPlan:
    """Kopiuje posiłki do nowego okresu, bez AI i bez zużycia punktów."""
    if not is_premium_active(current_user):
        raise HTTPException(status_code=403, detail=("Resuming plans is available with Premium." if account_country(current_user) == "GB" else "Wznawianie planów jest dostępne w Premium."))
    if payload.start_date < market_today(current_user):
        raise HTTPException(status_code=422, detail=("The start date cannot be before today." if account_country(current_user) == "GB" else "Data rozpoczęcia nie może być wcześniejsza niż dzisiaj."))
    from app.core.rate_limit import enforce_user_rate_limit, meal_plan_generation_limiter

    enforce_user_rate_limit(meal_plan_generation_limiter, current_user.id, "wznawianie planu")
    result = await db.execute(
        select(MealPlan)
        .options(selectinload(MealPlan.entries))
        .where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
        .with_for_update(of=MealPlan)
    )
    archived = result.scalar_one_or_none()
    if archived is None:
        raise NotFoundException(detail=("Meal plan not found." if account_country(current_user) == "GB" else "Plan posiłków nie został znaleziony."))
    if archived.status != "archived" or archived.archived_at is None:
        raise HTTPException(status_code=409, detail=("Only archived plans can be resumed." if account_country(current_user) == "GB" else "Można wznowić tylko plan z archiwum."))
    if not archived.entries:
        raise HTTPException(status_code=409, detail=("This plan no longer has any meals to resume." if account_country(current_user) == "GB" else "Ten plan nie ma już posiłków do wznowienia."))
    if await get_store_in_account_market(db, archived.store_id, current_user) is None:
        raise NotFoundException(detail=("The shop for this plan is not available in your account country." if account_country(current_user) == "GB" else "Sklep tego planu nie jest dostępny w kraju tego konta."))
    preferences = deepcopy(archived.preferences) if isinstance(archived.preferences, dict) else {}
    previous_people = _stored_household_size(preferences.get("household_size"))
    scale = Decimal("1")
    if previous_people is not None and previous_people > 8:
        scale = Decimal("8") / Decimal(previous_people)
        preferences["household_size"] = 8
        warnings = preferences.get("preference_warnings", [])
        warnings = [value for value in warnings if isinstance(value, str)] if isinstance(warnings, list) else []
        preferences["preference_warnings"] = [*warnings, ("We adjusted the plan to the limit of 8 people." if account_country(current_user) == "GB" else "Plan dostosowaliśmy do limitu 8 osób.")]
    elif previous_people is None:
        preferences["household_size"] = min(8, _stored_household_size(current_user.household_size) or 1)
    resumed = MealPlan(
        user_id=current_user.id,
        store_id=archived.store_id,
        start_date=payload.start_date,
        duration_days=archived.duration_days,
        meals_per_day=archived.meals_per_day,
        status="active",
        preferences=preferences,
    )
    db.add(resumed)
    await db.flush()
    for entry in archived.entries:
        db.add(MealPlanEntry(
            meal_plan_id=resumed.id,
            recipe_id=entry.recipe_id,
            day_number=entry.day_number,
            meal_slot=entry.meal_slot,
            servings_multiplier=(
                max(Decimal("0.01"), (entry.servings_multiplier * scale).quantize(Decimal("0.01")))
                if scale != 1 else entry.servings_multiplier
            ),
        ))
    # Każde wznowienie ma własną listę zakupów. Stara lista (w tym zakupy
    # już odhaczone) pozostaje nietknięta. Zapis planu, historii limitu i
    # nowej listy jest zatwierdzany wspólnie przez standardowy builder.
    from app.services.exceptions import ServiceError
    from app.services.meal_plan_quota import record_meal_plan_creation

    try:
        await record_meal_plan_creation(db, user=current_user, meal_plan_id=resumed.id)
        await ShoppingListBuilder(db).build_from_meal_plan(
            resumed.id, include_pantry=preferences.get("include_pantry", True)
        )
        await db.commit()
    except ServiceError as error:
        await db.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error
    except Exception:
        await db.rollback()
        raise
    return await get_meal_plan(resumed.id, current_user=current_user, db=db)


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
    _ensure_plan_access(plan, current_user, editable=True)

    if await get_store_in_account_market(db, payload.store_id, current_user) is None:
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

    _ensure_plan_access(plan, current_user, editable=True)
    if payload.status == "archived" and not is_premium_active(current_user):
        raise HTTPException(status_code=403, detail="Archiwizowanie planów jest dostępne w Premium.")

    plan.status = payload.status
    if payload.status == "archived":
        plan.archived_at = datetime.now(timezone.utc)
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
    _ensure_plan_access(plan, current_user, editable=True)

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

    # Pośrednie odczytanie przepisu przez plan podlega tej samej widoczności.
    from app.services.recipe_access import ensure_recipe_access

    recipe = await db.get(Recipe, payload.recipe_id)
    await ensure_recipe_access(db, recipe, current_user)
    await ensure_recipe_available_in_market(db, recipe, current_user, store_id=plan.store_id)

    # Zamień przepis
    entry.recipe_id = payload.recipe_id
    db.add(entry)
    await db.flush()

    # Przelicz listę zakupów
    if plan.shopping_list is not None:
        shopping_list_builder = ShoppingListBuilder(db)
        await shopping_list_builder.recalculate(plan.shopping_list.id)
    # Jeśli użytkownik usunął listę, sama zamiana dania nie powinna
    # tworzyć nowej listy ani zużywać tygodniowego limitu.

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

    _ensure_plan_access(plan, current_user)

    # UWAGA (naprawa): usuwamy powiązane wiersze RĘCZNIE, zamiast polegać
    # wyłącznie na kaskadowym usuwaniu w bazie danych (ON DELETE CASCADE).
    # Tabele tej aplikacji są tworzone przez `Base.metadata.create_all()`
    # przy starcie, nie przez pełne migracje Alembic — jeśli ograniczenie
    # klucza obcego zostało zdefiniowane w modelu PO TYM, jak dana tabela
    # już istniała w bazie produkcyjnej, `create_all()` NIE aktualizuje
    # wstecznie istniejących ograniczeń. Efekt: próba usunięcia planu
    # z wciąż powiązaną listą zakupów mogła kończyć się cichym błędem
    # integralności bazy (500), zanim dotarła do frontendu jako "nie
    # działa". Jawne usuwanie w prawidłowej kolejności działa niezależnie
    # od faktycznego stanu ograniczeń w bazie.
    from app.models import ShoppingList, ShoppingListItem

    shopping_list_result = await db.execute(
        select(ShoppingList).where(ShoppingList.meal_plan_id == plan.id)
    )
    shopping_list = shopping_list_result.scalar_one_or_none()
    if shopping_list is not None:
        await db.execute(
            delete(ShoppingListItem).where(ShoppingListItem.shopping_list_id == shopping_list.id)
        )
        await db.delete(shopping_list)

    await db.execute(delete(MealPlanEntry).where(MealPlanEntry.meal_plan_id == plan.id))

    await db.delete(plan)
    await db.commit()
