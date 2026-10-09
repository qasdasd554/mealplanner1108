"""Endpointy planów posiłków — generowanie, przeglądanie, modyfikacja."""

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
            detail="Automatyczny tydzień jest dostępny w Premium.",
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
        raise HTTPException(status_code=403, detail="Ta funkcja wymaga Premium.")
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
