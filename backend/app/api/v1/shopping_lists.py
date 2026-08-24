"""Endpointy list zakupów — przeglądanie, oznaczanie, zamienniki."""

from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.core.premium import is_premium_active
from app.db.session import get_db
from app.models import (
    MealPlan,
    MealPlanEntry,
    Recipe,
    ShoppingList,
    ShoppingListItem,
    StoreDepartment,
    StoreProduct,
    User,
)
from app.schemas.shopping_list import ShoppingListItemResponse, ShoppingListResponse
from app.services import ProductSubstitutionService
from app.services.shopping_list_builder import ShoppingListBuilder

router = APIRouter()

# Limity liczby "zarządzalnych" list zakupów (utworzonych explicite z
# wybranych przepisów, NIE zwykłych list generowanych automatycznie przy
# każdym planie posiłków — te są bez ograniczeń, bo to podstawowa funkcja
# aplikacji dostępna dla każdego konta).
MAX_SHOPPING_LISTS_STANDARD = 1
MAX_SHOPPING_LISTS_PREMIUM = 5


class ShoppingListFromRecipesRequest(BaseModel):
    """Żądanie stworzenia listy zakupów na konkretne dania — ALBO nowej
    (podlega limitowi 1 dla standardu / 5 dla Premium), ALBO dopisania
    składników do JUŻ ISTNIEJĄCEJ listy (existing_list_id) — to drugie
    nie tworzy nowej listy, więc nie zużywa limitu."""

    recipe_ids: list[UUID]
    store_id: UUID
    existing_list_id: UUID | None = None


@router.get(
    "/mine",
    response_model=list[ShoppingListResponse],
    summary="Twoje zarządzalne listy zakupów (utworzone z wybranych przepisów)",
)
async def get_my_shopping_lists(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ShoppingList]:
    """Zwraca listy zakupów utworzone przez /from-recipes — te, do
    których można dopisywać kolejne przepisy, albo które liczą się do
    limitu (1 dla standardu, 5 dla Premium). NIE zwraca zwykłych list
    powiązanych z prawdziwymi, wielodniowymi planami posiłków."""
    result = await db.execute(
        select(ShoppingList)
        .join(MealPlan, MealPlan.id == ShoppingList.meal_plan_id)
        .options(
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(MealPlan.user_id == current_user.id, MealPlan.status == "archived")
        .order_by(ShoppingList.created_at.desc())
    )
    return list(result.scalars().all())


@router.post(
    "/from-recipes",
    response_model=ShoppingListResponse,
    status_code=201,
    summary="Stwórz listę zakupów na konkretne danie/dania, albo dopisz do istniejącej",
)
async def create_shopping_list_from_recipes(
    payload: ShoppingListFromRecipesRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingList:
    """Generuje listę zakupów na podstawie WYBRANYCH przepisów — bez
    tworzenia pełnego, wielodniowego planu posiłków. Przydatne, gdy
    chcesz kupić składniki na jedno konkretne danie (albo kilka), a nie
    na cały tydzień.

    Pod spodem tworzy lekki, "techniczny" plan posiłków (status
    "archived" — nigdy nie pojawia się jako Twój aktywny plan) i używa
    dokładnie tego samego, sprawdzonego mechanizmu budowania listy
    zakupów co przy zwykłych planach — więc ceny, zaokrąglanie do
    opakowań i grupowanie po działach sklepu działają identycznie.
    """
    if not payload.recipe_ids:
        raise HTTPException(status_code=400, detail="Podaj przynajmniej jeden przepis")

    # Sprawdź, że wszystkie przepisy istnieją i są widoczne dla użytkownika
    # (własne prywatne, publiczne, albo oficjalne — ta sama reguła co przy
    # normalnym przeglądaniu przepisów).
    from app.api.v1.recipes import _visibility_filter

    recipes_result = await db.execute(
        select(Recipe.id).where(
            Recipe.id.in_(payload.recipe_ids),
            _visibility_filter(current_user.id),
        )
    )
    found_ids = set(recipes_result.scalars().all())
    missing = set(payload.recipe_ids) - found_ids
    if missing:
        raise NotFoundException(detail=f"Nie znaleziono przepisu/przepisów: {missing}")

    if payload.existing_list_id is not None:
        # --- Dopisanie do ISTNIEJĄCEJ listy — nie zużywa limitu ---
        # UWAGA: zgodnie z konwencją całej reszty tego pliku (patrz
        # komentarz w schemas/shopping_list.py), "ID listy" widziane przez
        # frontend to FAKTYCZNIE meal_plan_id, nie klucz główny
        # ShoppingList — dlatego porównujemy MealPlan.id, nie ShoppingList.id.
        existing = await db.execute(
            select(ShoppingList)
            .join(MealPlan, MealPlan.id == ShoppingList.meal_plan_id)
            .where(MealPlan.id == payload.existing_list_id, MealPlan.user_id == current_user.id)
        )
        target_list = existing.scalar_one_or_none()
        if target_list is None:
            raise NotFoundException(detail="Nie znaleziono podanej listy zakupów.")

        max_day_result = await db.execute(
            select(func.max(MealPlanEntry.day_number)).where(MealPlanEntry.meal_plan_id == target_list.meal_plan_id)
        )
        next_day = (max_day_result.scalar() or 0) + 1
        for recipe_id in payload.recipe_ids:
            db.add(
                MealPlanEntry(
                    meal_plan_id=target_list.meal_plan_id,
                    recipe_id=recipe_id,
                    day_number=next_day,
                    meal_slot="obiad",
                )
            )
        await db.commit()

        builder = ShoppingListBuilder(db)
        # UWAGA (naprawa): build_from_meal_plan ZAWSZE próbuje UTWORZYĆ
        # nową ShoppingList — przy istniejącej liście naruszało to
        # unikalny klucz meal_plan_id (IntegrityError). Właściwa metoda
        # do PRZELICZENIA już istniejącej listy to recalculate(), która
        # przyjmuje prawdziwy klucz główny ShoppingList.id (nie
        # meal_plan_id) i aktualizuje pozycje w miejscu.
        shopping_list = await builder.recalculate(target_list.id)
    else:
        # --- Nowa lista — podlega limitowi ---
        count_result = await db.execute(
            select(func.count(ShoppingList.id))
            .join(MealPlan, MealPlan.id == ShoppingList.meal_plan_id)
            .where(MealPlan.user_id == current_user.id, MealPlan.status == "archived")
        )
        current_count = count_result.scalar() or 0
        limit = MAX_SHOPPING_LISTS_PREMIUM if is_premium_active(current_user) else MAX_SHOPPING_LISTS_STANDARD

        if current_count >= limit:
            if limit == MAX_SHOPPING_LISTS_STANDARD:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        f"Konto standardowe może mieć maksymalnie {MAX_SHOPPING_LISTS_STANDARD} "
                        "taką listę zakupów. Usuń istniejącą, dopisz do niej kolejne przepisy, "
                        "albo przejdź na Premium (do 5 list)."
                    ),
                )
            raise HTTPException(
                status_code=403,
                detail=f"Konto Premium może mieć maksymalnie {MAX_SHOPPING_LISTS_PREMIUM} takich list zakupów.",
            )

        plan = MealPlan(
            user_id=current_user.id,
            store_id=payload.store_id,
            start_date=date.today(),
            duration_days=1,
            meals_per_day=len(payload.recipe_ids),
            status="archived",
        )
        db.add(plan)
        await db.flush()

        for recipe_id in payload.recipe_ids:
            db.add(
                MealPlanEntry(
                    meal_plan_id=plan.id,
                    recipe_id=recipe_id,
                    day_number=1,
                    meal_slot="obiad",
                )
            )
        await db.commit()

        builder = ShoppingListBuilder(db)
        shopping_list = await builder.build_from_meal_plan(plan.id)

    # UWAGA (naprawa): populate_existing=True jest KLUCZOWE w gałęzi
    # "dopisz do istniejącej" — obiekt ShoppingList o tym ID jest już
    # częściowo załadowany w identity map tej sesji (przez recalculate()),
    # więc bez wymuszenia SQLAlchemy po cichu IGNORUJE poniższe
    # selectinload i zwraca stary, niekompletny stan — co przy próbie
    # dostępu do np. item.department w kontekście asynchronicznym rzuca
    # MissingGreenlet (leniwe ładowanie tam, gdzie go nie oczekujemy).
    result = await db.execute(
        select(ShoppingList)
        .execution_options(populate_existing=True)
        .options(
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(ShoppingList.id == shopping_list.id)
    )
    return result.scalar_one()



class SubstituteRequest(BaseModel):
    """Schemat żądania zamiany produktu na liście zakupów."""

    model_config = ConfigDict(from_attributes=True)

    substitute_product_id: UUID


class ShoppingListSummary(BaseModel):
    """Podsumowanie listy zakupów — łączna cena, postęp zakupów."""

    model_config = ConfigDict(from_attributes=True)

    total_items: int
    checked_items: int
    unchecked_items: int
    total_estimated_price: float
    checked_price: float
    remaining_price: float
    completion_percentage: float


async def _get_shopping_list_or_404(
    list_id: UUID,
    current_user: User,
    db: AsyncSession,
) -> ShoppingList:
    """Pobiera listę zakupów z weryfikacją właściciela.

    Raises:
        NotFoundException: jeśli lista nie istnieje lub nie należy do użytkownika.
    """
    result = await db.execute(
        select(ShoppingList)
        .join(MealPlan, ShoppingList.meal_plan_id == MealPlan.id)
        .options(
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(
            ShoppingList.meal_plan_id == list_id,
            MealPlan.user_id == current_user.id,
        )
    )
    shopping_list = result.scalar_one_or_none()
    if shopping_list is None:
        raise NotFoundException(
            detail=f"Lista zakupów o ID {list_id} nie została znaleziona"
        )
    return shopping_list


@router.get(
    "/{list_id}",
    response_model=ShoppingListResponse,
    summary="Pobierz listę zakupów pogrupowaną po działach",
)
async def get_shopping_list(
    list_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingList:
    """Zwraca listę zakupów z pozycjami pogrupowanymi po działach sklepu."""
    return await _get_shopping_list_or_404(list_id, current_user, db)


@router.put(
    "/{list_id}/items/{item_id}/check",
    response_model=ShoppingListItemResponse,
    summary="Zaznacz/odznacz pozycję na liście",
)
async def toggle_item_checked(
    list_id: UUID,
    item_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListItem:
    """Przełącza status oznaczenia pozycji na liście zakupów (kupione/niekupione)."""
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    result = await db.execute(
        select(ShoppingListItem)
        .options(
            selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingListItem.department),
            selectinload(ShoppingListItem.substituted_for_product),
        )
        .where(
            ShoppingListItem.id == item_id,
            ShoppingListItem.shopping_list_id == shopping_list.id,
        )
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(
            detail=f"Pozycja o ID {item_id} nie została znaleziona na liście"
        )

    item.is_checked = not item.is_checked
    db.add(item)
    await db.commit()
    
    # Przeładuj obiekt z relacjami
    result = await db.execute(
        select(ShoppingListItem)
        .options(
            selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingListItem.department),
            selectinload(ShoppingListItem.substituted_for_product),
        )
        .execution_options(populate_existing=True)
        .where(ShoppingListItem.id == item_id)
    )
    return result.scalar_one()


@router.put(
    "/{list_id}/items/{item_id}/substitute",
    response_model=ShoppingListItemResponse,
    summary="Zamień produkt na liście zakupów",
)
async def substitute_item(
    list_id: UUID,
    item_id: UUID,
    payload: SubstituteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListItem:
    """Zamienia produkt na liście zakupów na wskazany zamiennik.

    Aktualizuje produkt, cenę jednostkową oraz dział sklepu
    na podstawie danych zamiennika.
    """
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    # Znajdź pozycję
    result = await db.execute(
        select(ShoppingListItem)
        .options(selectinload(ShoppingListItem.store_product))
        .where(
            ShoppingListItem.id == item_id,
            ShoppingListItem.shopping_list_id == shopping_list.id,
        )
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(
            detail=f"Pozycja o ID {item_id} nie została znaleziona na liście"
        )

    substitution_service = ProductSubstitutionService(db)
    updated_item = await substitution_service.substitute_shopping_list_item(
        item=item,
        substitute_product_id=payload.substitute_product_id,
        store_id=shopping_list.store_id,
    )

    await db.commit()
    
    # Przeładuj obiekt z relacjami
    result = await db.execute(
        select(ShoppingListItem)
        .options(
            selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingListItem.department),
            selectinload(ShoppingListItem.substituted_for_product),
        )
        .execution_options(populate_existing=True)
        .where(ShoppingListItem.id == item_id)
    )
    return result.scalar_one()


@router.get(
    "/{list_id}/summary",
    response_model=ShoppingListSummary,
    summary="Podsumowanie listy zakupów",
)
async def get_shopping_list_summary(
    list_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListSummary:
    """Zwraca podsumowanie listy zakupów: łączną cenę, postęp zakupów, itp."""
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    items = shopping_list.items or []
    total_items = len(items)
    checked_items = sum(1 for i in items if i.is_checked)
    unchecked_items = total_items - checked_items

    total_price = sum(float(i.estimated_price or 0) for i in items)
    checked_price = sum(float(i.estimated_price or 0) for i in items if i.is_checked)
    remaining_price = total_price - checked_price

    completion = (checked_items / total_items * 100) if total_items > 0 else 0.0

    return ShoppingListSummary(
        total_items=total_items,
        checked_items=checked_items,
        unchecked_items=unchecked_items,
        total_estimated_price=round(total_price, 2),
        checked_price=round(checked_price, 2),
        remaining_price=round(remaining_price, 2),
        completion_percentage=round(completion, 1),
    )


@router.delete(
    "/{list_id}",
    status_code=204,
    summary="Usuń zarządzalną listę zakupów (zwalnia miejsce w limicie)",
)
async def delete_shopping_list(
    list_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Usuwa listę zakupów WRAZ z powiązanym, technicznym planem
    (kasowanie kaskadowe). Działa TYLKO na listach utworzonych przez
    /from-recipes (status "archived") — nie da się tak usunąć listy
    powiązanej z prawdziwym, aktywnym planem posiłków.

    UWAGA: zgodnie z konwencją całej reszty tego pliku, "ID listy"
    widziane przez frontend to FAKTYCZNIE meal_plan_id (patrz komentarz
    w schemas/shopping_list.py) — więc list_id tutaj porównujemy
    bezpośrednio z MealPlan.id, bez potrzeby złączenia przez ShoppingList.
    """
    result = await db.execute(
        select(MealPlan).where(
            MealPlan.id == list_id, MealPlan.user_id == current_user.id, MealPlan.status == "archived"
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail="Nie znaleziono listy zakupów do usunięcia.")

    await db.delete(plan)
    await db.commit()
