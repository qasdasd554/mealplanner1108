"""Endpointy list zakupów — przeglądanie, oznaczanie, zamienniki."""

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import exists, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException, ProductUnavailableException
from app.core.language import account_text
from app.core.markets import account_country
from app.services.notification_language import notification_text
from app.db.session import get_db
from app.models import (
    MealPlan,
    MealPlanEntry,
    BlockedUser,
    Product,
    Recipe,
    RecipeIngredient,
    ShoppingList,
    ShoppingListItem,
    ShoppingListShare,
    ShoppingListItemRegionalSnapshot,
    Store,
    StoreDepartment,
    StoreProduct,
    User,
)
from app.schemas.shopping_list import ShoppingListItemResponse, ShoppingListResponse
from app.services import ProductSubstitutionService
from app.services.shopping_list_builder import ShoppingListBuilder
from app.services.store_market_access import get_store_in_account_market
from app.services.market_catalog import recipe_market_availability
from app.services.regional_shopping import (
    apply_regional_item_quote, copy_regional_snapshot, load_regional_offers,
    refresh_regional_items, resolve_manual_regional_quantity,
    regional_pricing_date,
    refresh_regional_plan_budget,
    complete_regional_items_to_pantry,
    frozen_regional_purchase_quote, regional_snapshot_requirement,
)
from app.services.regional_offer_pricing import select_uk_offer_quote
from app.services.regional_requirements import to_regional_base_quantity
from app.services.shopping_list_quota import (
    can_append_recipes_to_existing_list,
    record_shopping_list_creation,
)

router = APIRouter()

class ShoppingListFromRecipesRequest(BaseModel):
    """Żądanie stworzenia listy zakupów na konkretne dania — ALBO nowej
    (podlega limitowi tygodniowemu dla konta standardowego), ALBO dopisania
    składników do JUŻ ISTNIEJĄCEJ listy (existing_list_id). Dopisywanie
    kolejnych przepisów jest funkcją Premium, aby nie obchodziło limitu."""

    recipe_ids: list[UUID]
    store_id: UUID
    existing_list_id: UUID | None = None


class EmptyShoppingListRequest(BaseModel):
    """Pierwsza, pusta lista tworzona przyciskiem „+” w Zakupach."""

    store_id: UUID


class MergeShoppingListsRequest(BaseModel):
    """Połącz co najmniej dwie własne, otwarte listy z jednego sklepu."""

    list_ids: list[UUID] = Field(..., min_length=2)


class ShoppingListStoreRequest(BaseModel):
    """A store for this current list, never a request to rebuild its recipes."""

    store_id: UUID


def shopping_item_merge_key(item: ShoppingListItem) -> tuple:
    """Stan kupienia jest częścią klucza, aby nie zgubić części zakupów."""
    snapshot = getattr(item, "regional_snapshot", None)
    if snapshot is not None:
        if item.is_checked and not item.is_from_pantry:
            # Two already bought packages are separate historical purchases,
            # not a fresh combined requirement to round to a new package.
            return ("GB-purchased", item.id)
        return (
            "GB", snapshot.product_id,
            None if snapshot.product_id else (item.custom_name or "").strip().casefold(),
            item.unit, item.is_from_pantry, item.is_checked, item.substituted_for,
        )
    return (
        item.is_from_pantry,
        item.store_product_id,
        (item.custom_name or "").strip().casefold(),
        item.unit,
        item.department_id,
        item.substituted_for,
        item.is_checked,
    )


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
    których można dopisywać kolejne przepisy. NIE zwraca zwykłych list
    powiązanych z prawdziwymi, wielodniowymi planami posiłków.

    NAPRAWA: warunek sprawdzał WYŁĄCZNIE `MealPlan.user_id ==
    current_user.id`, więc listy UDOSTĘPNIONE przez innego użytkownika
    nie pojawiały się tutaj wcale. Zaproszenie dawało się przyjąć,
    dostęp po ID działał, ale lista nigdy nie trafiała do wykazu
    w aplikacji — z perspektywy użytkownika akceptacja nie robiła nic.
    Teraz dokładamy ten sam warunek udostępnienia, którego używa
    _get_shopping_list_or_404, żeby oba miejsca widziały to samo.
    """
    shared_access = exists().where(
        ShoppingListShare.meal_plan_id == MealPlan.id,
        ShoppingListShare.shared_with_user_id == current_user.id,
        ShoppingListShare.status == "accepted",
    )

    result = await db.execute(
        select(ShoppingList)
        .join(MealPlan, MealPlan.id == ShoppingList.meal_plan_id)
        .options(
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(
            or_(MealPlan.user_id == current_user.id, shared_access),
            # NAPRAWA: był tu warunek `MealPlan.status == "archived"`, który
            # przepuszczał WYŁĄCZNIE sztuczne plany tworzone pod listy
            # z pojedynczych dań (/from-recipes). Listy wygenerowane
            # z PRAWDZIWEGO planu posiłków mają status "draft"/"active",
            # więc nie pojawiały się w zakładce Zakupy wcale — użytkownik
            # tworzył plan, generował listę i nigdzie jej nie widział.
            #
            # Lista zakończona (przeniesiona do spiżarni albo domknięta)
            # nadal jest wykluczana — zakupy są zrobione, więc nie ma czego
            # pokazywać, a jej obecność sugerowałaby, że "Zakończ" nie
            # zadziałało.
            ShoppingList.status.notin_(["completed", "merged"]),
        )
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
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Podaj przynajmniej jeden przepis", "Choose at least one recipe."))

    if await get_store_in_account_market(db, payload.store_id, current_user) is None:
        raise NotFoundException(detail=account_text(current_user,
            "Wybrany sklep nie jest dostępny w kraju tego konta", "The selected shop is not available in this account's country."))

    # Sprawdź, że wszystkie przepisy istnieją i są widoczne dla użytkownika
    # (własne prywatne, publiczne, albo oficjalne — ta sama reguła co przy
    # normalnym przeglądaniu przepisów).
    from app.api.v1.recipes import _visibility_filter
    from app.services.recipe_access import recipe_origin_in_market

    recipe_query = select(Recipe).options(
        selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
    ).where(
        Recipe.id.in_(payload.recipe_ids),
        Recipe.is_active.is_(True),
        _visibility_filter(current_user.id),
        recipe_origin_in_market(account_country(current_user)),
    )
    if account_country(current_user) == "GB":
        # Just like recipe detail, keep the owner's own imports usable even
        # while an ingredient's country evidence/nutrition is incomplete.
        # The builder preserves exact quantities and unknown prices; it must
        # not replace a missing ingredient with a ready meal or invent stock.
        recipe_query = recipe_query.where(or_(
            Recipe.created_by_user_id == current_user.id,
            recipe_market_availability("GB", store_id=payload.store_id),
        ))
    recipes_result = await db.execute(recipe_query)
    selected_recipes = recipes_result.scalars().all()
    found_ids = {recipe.id for recipe in selected_recipes}
    missing = set(payload.recipe_ids) - found_ids
    if missing:
        raise NotFoundException(detail=account_text(current_user,
            f"Nie znaleziono przepisu/przepisów: {missing}", f"Recipe(s) not found: {missing}"))

    # Transfer the saved ingredient rows, never infer a product from the
    # recipe title. Source/import validation belongs before saving a recipe,
    # not a name-based refusal to create this shopping list.

    if payload.existing_list_id is not None:
        # Dopisywanie kolejnych przepisów do jednej listy wcześniej
        # pozwalało kontu standardowemu bez końca obchodzić limit jednej
        # listy tygodniowo. Ręczne dopisywanie pojedynczych produktów
        # pozostaje dostępne; ograniczamy tylko import całego przepisu.
        if not can_append_recipes_to_existing_list(current_user):
            raise HTTPException(
                status_code=403,
                detail=account_text(current_user,
                    "Konto standardowe może utworzyć jedną listę zakupów "
                    "w tygodniu. Dodawanie kolejnych przepisów do istniejącej "
                    "listy jest dostępne w Premium.",
                    "A Standard account can create one shopping list per week. "
                    "Adding more recipes to an existing list is available with Premium."
                ),
            )

        # --- Dopisanie do ISTNIEJĄCEJ listy dla Premium ---
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
            raise NotFoundException(detail=account_text(current_user,
                "Nie znaleziono podanej listy zakupów.", "Shopping list not found."))
        if target_list.status in {"completed", "merged"}:
            raise HTTPException(status_code=409, detail=account_text(current_user,
                "Ta lista jest już zakończona.", "This shopping list is already completed."))
        if target_list.store_id != payload.store_id:
            raise HTTPException(status_code=400, detail=account_text(current_user,
                "Lista jest przypisana do innego sklepu.", "This shopping list belongs to a different shop."))

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
        # Wspólny builder sprawdza limit tygodniowy także dla list
        # powstałych z normalnego planu posiłków.

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
        await db.flush()

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


@router.post(
    "/empty",
    response_model=ShoppingListResponse,
    status_code=201,
    summary="Utwórz pustą listę zakupów",
)
async def create_empty_shopping_list(
    payload: EmptyShoppingListRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingList:
    """Tworzy pierwszą listę bez wymuszania planu lub przepisu.

    Lista nadal jest przypisana do sklepu, dzięki czemu późniejsze
    dodawanie produktów katalogowych może zachować ceny i działy.
    """
    store = await get_store_in_account_market(db, payload.store_id, current_user)
    if store is None:
        raise NotFoundException(detail=account_text(current_user,
            "Wybrany sklep nie jest dostępny w kraju tego konta", "The selected shop is not available in this account's country."))

    plan = MealPlan(
        user_id=current_user.id,
        store_id=payload.store_id,
        start_date=date.today(),
        duration_days=1,
        meals_per_day=0,
        status="archived",
    )
    db.add(plan)
    await db.flush()

    shopping_list = ShoppingList(
        meal_plan_id=plan.id,
        store_id=payload.store_id,
        status="pending",
    )
    db.add(shopping_list)
    await db.flush()
    await record_shopping_list_creation(
        db, user=current_user, shopping_list_id=shopping_list.id,
    )
    await db.commit()

    result = await db.execute(
        select(ShoppingList)
        .options(
            selectinload(ShoppingList.items)
            .selectinload(ShoppingListItem.store_product)
            .selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(
                ShoppingListItem.substituted_for_product
            ),
            selectinload(ShoppingList.store),
        )
        .where(ShoppingList.id == shopping_list.id)
    )
    return result.scalar_one()


@router.post(
    "/merge",
    response_model=ShoppingListResponse,
    status_code=201,
    summary="Połącz listy zakupów przypisane do tego samego sklepu",
)
async def merge_shopping_lists(
    payload: MergeShoppingListsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingList:
    ids = list(dict.fromkeys(payload.list_ids))
    if len(ids) < 2:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Wybierz co najmniej dwie różne listy.", "Choose at least two different shopping lists."))

    await db.execute(
        text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
        {"key": f"shopping-merge:{current_user.id}"},
    )
    result = await db.execute(
        select(ShoppingList)
        .join(MealPlan, ShoppingList.meal_plan_id == MealPlan.id)
        .options(selectinload(ShoppingList.items))
        .where(
            ShoppingList.meal_plan_id.in_(ids),
            MealPlan.user_id == current_user.id,
            ShoppingList.status.notin_(["completed", "merged"]),
        )
    )
    by_plan = {shopping_list.meal_plan_id: shopping_list for shopping_list in result.scalars().all()}
    if len(by_plan) != len(ids):
        raise HTTPException(status_code=404, detail=account_text(current_user,
            "Nie znaleziono jednej z wybranych list.", "One of the selected shopping lists was not found."))
    lists = [by_plan[list_id] for list_id in ids]
    store_id = lists[0].store_id
    if any(shopping_list.store_id != store_id for shopping_list in lists):
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Można łączyć tylko listy z tego samego sklepu.", "Only shopping lists from the same shop can be merged."))
    if await get_store_in_account_market(db, store_id, current_user) is None:
        raise NotFoundException(detail=account_text(current_user,
            "Wybrany sklep nie jest dostępny w kraju tego konta", "The selected shop is not available in this account's country."))

    # Nie odbieramy po cichu dostępu osobom, którym jedna z list została
    # udostępniona. Najpierw trzeba zakończyć udostępnienie źródła.
    shared_result = await db.execute(
        select(ShoppingListShare.id).where(
            ShoppingListShare.meal_plan_id.in_(ids),
            ShoppingListShare.status.in_(["pending", "accepted"]),
        ).limit(1)
    )
    if shared_result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail=account_text(current_user, "Najpierw usuń udostępnienie wybranych list, aby je połączyć.",
                "Stop sharing the selected lists before merging them."),
        )

    # To jedna lista wynikowa zamiast dwóch lub więcej; scalenie nie
    # zużywa dodatkowego tygodniowego limitu tworzenia list.
    plan = MealPlan(
        user_id=current_user.id,
        store_id=store_id,
        start_date=date.today(),
        duration_days=1,
        meals_per_day=0,
        status="archived",
        preferences={"shopping_list_merge": True},
    )
    db.add(plan)
    await db.flush()
    merged = ShoppingList(
        meal_plan_id=plan.id,
        store_id=store_id,
        status="pending",
    )
    db.add(merged)
    await db.flush()

    combined: dict[tuple, ShoppingListItem] = {}
    for source in lists:
        for item in list(source.items):
            key = shopping_item_merge_key(item)
            existing = combined.get(key)
            if existing is not None:
                existing.required_quantity += item.required_quantity
                if existing.estimated_price is not None and item.estimated_price is not None:
                    existing.estimated_price += item.estimated_price
                else:
                    existing.estimated_price = None
            else:
                # Zachowujemy źródłowe pozycje w ukrytych listach. Kopia
                # umożliwia odtworzenie danych i nie koliduje z relacją
                # ORM delete-orphan podczas przenoszenia między listami.
                copied = ShoppingListItem(
                    shopping_list_id=merged.id,
                    store_product_id=item.store_product_id,
                    custom_name=item.custom_name,
                    department_id=item.department_id,
                    required_quantity=item.required_quantity,
                    unit=item.unit,
                    estimated_price=item.estimated_price,
                    is_checked=item.is_checked,
                    is_from_pantry=item.is_from_pantry,
                    is_generated=False,
                    substituted_for=item.substituted_for,
                )
                db.add(copied)
                copy_regional_snapshot(item, copied)
                combined[key] = copied
        source.status = "merged"
        db.add(source)
    store = await db.get(Store, store_id)
    if store is not None and store.country_code == "GB":
        from types import SimpleNamespace
        await refresh_regional_items(db, SimpleNamespace(items=list(combined.values()), store_id=store_id))
        await refresh_regional_plan_budget(db, merged)
    await db.commit()

    loaded = await db.execute(
        select(ShoppingList)
        .execution_options(populate_existing=True)
        .options(
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product).selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(ShoppingList.id == merged.id)
    )
    return loaded.scalar_one()



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
    total_estimated_price: float | None
    checked_price: float | None
    remaining_price: float | None
    completion_percentage: float
    currency_code: str = "PLN"
    has_unpriced_items: bool = False


async def _get_shopping_list_or_404(
    list_id: UUID,
    current_user: User,
    db: AsyncSession,
    *,
    for_update: bool = False,
    refresh: bool = False,
) -> ShoppingList:
    """Pobiera listę zakupów z weryfikacją dostępu.

    UWAGA (rozszerzenie — udostępnianie): dostęp ma teraz WŁAŚCICIEL
    planu (jak dotychczas) ORAZ każdy, komu ten plan zostało
    UDOSTĘPNIONE i kto to udostępnienie ZAAKCEPTOWAŁ (status
    "accepted" w ShoppingListShare) — to JEDNO miejsce, z którego
    korzystają WSZYSTKIE inne endpointy w tym pliku (podgląd,
    odhaczanie, zamienniki), więc ta jedna zmiana automatycznie
    "odblokowuje" współdzieloną listę wszędzie, bez konieczności
    zmieniać każdego endpointu z osobna.

    Raises:
        NotFoundException: jeśli lista nie istnieje lub użytkownik nie ma do niej dostępu.
    """
    shared_access = exists().where(
        ShoppingListShare.meal_plan_id == MealPlan.id,
        ShoppingListShare.shared_with_user_id == current_user.id,
        ShoppingListShare.status == "accepted",
    )

    query = (
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
            or_(MealPlan.user_id == current_user.id, shared_access),
            ShoppingList.status != "merged",
        )
    )
    if for_update:
        query = query.with_for_update(of=ShoppingList).execution_options(populate_existing=True)
    elif refresh:
        query = query.execution_options(populate_existing=True)
    result = await db.execute(query)
    shopping_list = result.scalar_one_or_none()
    if shopping_list is None:
        raise NotFoundException(
            detail=account_text(current_user, f"Lista zakupów o ID {list_id} nie została znaleziona",
                f"Shopping list {list_id} was not found.")
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
    "/{list_id}/store",
    response_model=ShoppingListResponse,
    summary="Change the store for the current UK shopping list without rebuilding it",
)
async def update_shopping_list_store(
    list_id: UUID,
    payload: ShoppingListStoreRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingList:
    # Public list IDs are meal_plan_id throughout this API, including shares.
    shopping = await _get_shopping_list_or_404(list_id, current_user, db, for_update=True)
    if shopping.status not in {"pending", "in_progress"}:
        raise HTTPException(status_code=409, detail=account_text(current_user,
            "Sklep można zmienić tylko dla otwartej listy zakupów.",
            "Only an open shopping list can change store."))
    plan = (await db.execute(select(MealPlan).where(
        MealPlan.id == shopping.meal_plan_id,
    ).with_for_update())).scalar_one()
    owner = await db.get(User, plan.user_id)
    source = shopping.store
    if (owner is not None and account_country(owner) == "PL" and source is not None
            and source.country_code == "PL" and source.currency_code == "PLN"
            and plan.store_id == shopping.store_id):
        return await _switch_polish_list_store(db, shopping, plan, payload.store_id, current_user)
    if (owner is None or owner.country_code != "GB" or source is None
            or source.country_code != "GB" or source.currency_code != "GBP"
            or plan.store_id != shopping.store_id):
        raise HTTPException(status_code=409, detail=account_text(current_user,
            "Lista i jej właściciel muszą należeć do tego samego rynku UK.",
            "The list and its owner must belong to the same UK market."))
    # An accepted shared-list viewer can belong to PL. Target is constrained by
    # the LIST market, not silently substituted with the viewer's account market.
    target = (await db.execute(select(Store).where(
        Store.id == payload.store_id, Store.country_code == "GB", Store.currency_code == "GBP",
    ))).scalar_one_or_none()
    if target is None:
        raise NotFoundException(detail=account_text(current_user,
            "Wybrany sklep nie jest dostępny na rynku tej listy.",
            "The selected store is not available in this list's market."))

    as_of = regional_pricing_date()
    product_ids = {item.regional_snapshot.product_id for item in shopping.items if item.regional_snapshot is not None}
    offers = await load_regional_offers(db, product_ids - {None}, target.id)
    products = (await db.execute(select(Product).where(Product.id.in_(product_ids - {None})))).scalars().all()
    products = {product.id: product for product in products}
    prepared, unpriced = [], []
    for item in shopping.items:
        requirement = regional_snapshot_requirement(item)
        snapshot = item.regional_snapshot
        saved_unpriced = (snapshot is not None and snapshot.country_code == "GB"
            and snapshot.currency_code == "GBP" and snapshot.quote_status == "unpriced"
            and snapshot.quote_data is None and snapshot.offer_id is None
            and item.estimated_price is None and item.required_quantity > 0
            and (requirement is not None or (snapshot.required_quantity is None and snapshot.required_unit is None)))
        if item.is_from_pantry:
            if (requirement is None or item.regional_snapshot.quote_status != "pantry"
                    or not item.is_checked or item.estimated_price != Decimal(0)):
                raise HTTPException(status_code=409, detail=account_text(current_user,
                    "Najpierw popraw zapisaną ilość ze spiżarni.",
                    "The saved pantry quantity needs to be corrected first."))
            continue  # Proven coverage is already split; never subtract again.
        if item.is_checked:
            if saved_unpriced:
                continue  # A handwritten/unpriced purchase has no invented pack history.
            if frozen_regional_purchase_quote(item, as_of=as_of) is None:
                raise HTTPException(status_code=409, detail=account_text(current_user,
                    "Najpierw popraw zapisane dane zakupionego opakowania.",
                    "The saved purchased package needs to be corrected first."))
            continue  # Already bought: original store/package/price is history.
        if requirement is None:
            if saved_unpriced:
                unpriced.append(item)
                continue
            raise HTTPException(status_code=409, detail=account_text(current_user,
                "Nie można wycenić całej bieżącej listy zakupów w tym sklepie.",
                "This store cannot fully price the current shopping list."))
        product_id, quantity, unit = requirement
        product = products.get(product_id)
        if product is None:
            raise HTTPException(status_code=409, detail=account_text(current_user,
                "Nie można wycenić całej bieżącej listy zakupów w tym sklepie.",
                "This store cannot fully price the current shopping list."))
        prepared.append((item, product, quantity, unit))

    # Entire target basket is validated before mutation. A SAVEPOINT also rolls
    # back a later DB/flush failure without leaking an earlier repriced row.
    async with db.begin_nested():
        for item in unpriced:
            # No proven g/ml conversion or catalogue identity: move the
            # destination only, preserving the user's exact name and quantity.
            item.regional_snapshot.store_id = target.id
            item.regional_snapshot.pricing_as_of = as_of
        for item, product, quantity, unit in prepared:
            apply_regional_item_quote(item, product=product, store_id=target.id,
                quantity=quantity, unit=unit, offers=offers, as_of=as_of)
        shopping.store_id, shopping.store = target.id, target
        plan.store_id, plan.store = target.id, target
        await refresh_regional_plan_budget(db, shopping)
        await db.flush()
    await db.commit()
    return await _get_shopping_list_or_404(list_id, current_user, db)


async def _switch_polish_list_store(db, shopping, plan, target_id, user):
    from app.services.polish_list_prices import quote_polish_list
    target = (await db.execute(select(Store).where(
        Store.id == target_id, Store.country_code == "PL", Store.currency_code == "PLN",
    ))).scalar_one_or_none()
    if target is None:
        raise NotFoundException(detail=account_text(user,
            "Wybrany sklep nie jest dostępny na rynku tej listy.",
            "The selected store is not available in this list's market."))
    quoted = (await quote_polish_list(db, shopping, [target]))[target.id]
    async with db.begin_nested():
        for item, offer, quote in quoted:
            if item.is_checked or item.is_from_pantry:
                continue
            if offer is not None and quote is not None:
                item.store_product_id, item.store_product = offer.id, offer
                item.department_id, item.department = offer.department_id, offer.department
                item.estimated_price = Decimal(str(quote["price_in_store"]))
            else:
                # Retain the existing canonical identity (or handwritten name),
                # never borrow the former shop's price/department/own brand.
                item.department_id, item.department = None, None
                item.estimated_price = None
        shopping.store_id, shopping.store = target.id, target
        plan.store_id, plan.store = target.id, target
        plan.estimated_min_budget = (None if any(quote is None for _, _, quote in quoted) else
            sum((Decimal(str(quote["price_in_store"])) for _, _, quote in quoted), Decimal(0)))
        await db.flush()
    await db.commit()
    return await _get_shopping_list_or_404(shopping.meal_plan_id, user, db, refresh=True)


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
            detail=account_text(current_user, f"Pozycja o ID {item_id} nie została znaleziona na liście",
                f"Item {item_id} was not found on this shopping list.")
        )
    if item.is_from_pantry:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Produkt jest już w spiżarni, nie trzeba go kupować.", "This product is already in your pantry and does not need to be bought."))

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
            detail=account_text(current_user, f"Pozycja o ID {item_id} nie została znaleziona na liście",
                f"Item {item_id} was not found on this shopping list.")
        )
    if item.is_from_pantry:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nie można zamienić produktu ze spiżarni.", "A pantry item cannot be substituted."))

    substitution_service = ProductSubstitutionService(db)
    try:
        await substitution_service.substitute_shopping_list_item(
            item=item,
            substitute_product_id=payload.substitute_product_id,
            store_id=shopping_list.store_id,
        )
    except ProductUnavailableException as exc:
        raise HTTPException(status_code=409, detail=account_text(current_user,
            "Ten zamiennik nie jest już dostępny w wybranym sklepie lub nie pasuje do jednostki produktu. Odśwież zamienniki i wybierz inny. Lista nie została zmieniona.",
            "This alternative is no longer available in the selected store or has an incompatible unit. Refresh the alternatives and choose another. Your list has not been changed.")) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=account_text(current_user,
            "Nie można przeliczyć ilości tego produktu. Wybierz gramy, mililitry lub produkt ze znaną wielkością opakowania.",
            "This quantity cannot be converted safely. Choose grams, millilitres or a product with a known package size.")) from exc

    if getattr(shopping_list.store, "country_code", "PL") == "GB":
        await refresh_regional_plan_budget(db, shopping_list)

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

    items = [item for item in (shopping_list.items or []) if not item.is_from_pantry]
    total_items = len(items)
    checked_items = sum(1 for i in items if i.is_checked)
    unchecked_items = total_items - checked_items

    total_price = sum(float(i.estimated_price or 0) for i in items)
    checked_price = sum(float(i.estimated_price or 0) for i in items if i.is_checked)
    remaining_price = total_price - checked_price

    completion = (checked_items / total_items * 100) if total_items > 0 else 0.0
    gb = getattr(shopping_list.store, "country_code", "PL") == "GB"
    unpriced = gb and any(item.estimated_price is None for item in items)

    return ShoppingListSummary(
        total_items=total_items,
        checked_items=checked_items,
        unchecked_items=unchecked_items,
        total_estimated_price=None if unpriced else round(total_price, 2),
        checked_price=None if gb and any(item.is_checked and item.estimated_price is None for item in items) else round(checked_price, 2),
        remaining_price=None if gb and any(not item.is_checked and item.estimated_price is None for item in items) else round(remaining_price, 2),
        completion_percentage=round(completion, 1),
        currency_code="GBP" if gb else "PLN", has_unpriced_items=bool(unpriced),
    )


@router.delete(
    "/{list_id}",
    status_code=204,
    summary="Usuń listę zakupów (nie odnawia limitu tygodniowego)",
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
            MealPlan.id == list_id, MealPlan.user_id == current_user.id
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail=account_text(current_user,
            "Nie znaleziono listy zakupów do usunięcia.", "Shopping list to delete was not found."))

    if plan.status == "archived" and plan.archived_at is None:
        # Sztuczny plan utworzony WYŁĄCZNIE pod listę z pojedynczych dań
        # (/from-recipes) — nie ma innej treści, więc znika razem z listą.
        await db.delete(plan)
    else:
        # PRAWDZIWY plan posiłków. Usuwamy TYLKO listę zakupów, plan
        # zostaje. Skasowanie planu przy okazji "usuwania listy" byłoby
        # zniszczeniem tygodnia pracy użytkownika przez czynność, która
        # w interfejsie wygląda na dotyczącą wyłącznie zakupów.
        list_result = await db.execute(
            select(ShoppingList).where(ShoppingList.meal_plan_id == plan.id)
        )
        shopping_list = list_result.scalar_one_or_none()
        if shopping_list is None:
            raise NotFoundException(detail=account_text(current_user,
                "Ten plan nie ma listy zakupów.", "This meal plan has no shopping list."))
        await db.delete(shopping_list)

    await db.commit()


# ══════════════════════════════════════════════════════════════════
# UDOSTĘPNIANIE LIST ZAKUPÓW — dwuetapowe (zaproszenie -> akceptacja),
# żeby nikt nie mógł po cichu dodać kogoś do współdzielonej listy bez
# jego wiedzy. Po zaakceptowaniu, _get_shopping_list_or_404 (patrz
# wyżej) automatycznie daje odbiorcy dostęp do WSZYSTKICH istniejących
# operacji na tej liście (podgląd, odhaczanie, zamienniki).
# ══════════════════════════════════════════════════════════════════
class ShareShoppingListRequest(BaseModel):
    """Odbiorca wskazywany NAZWĄ UŻYTKOWNIKA, nie adresem e-mail.

    Zmiana z e-maila: nazwa jest widoczna publicznie w aplikacji (autor
    przepisu, komentarze, ranking konkursu), więc udostępnienie nie wymaga
    już znajomości czyjegoś prywatnego adresu ani jego ujawniania.

    Jednoznaczność jest zagwarantowana — nazwy są unikalne (bez
    rozróżniania wielkości liter), pilnuje tego validate_display_name
    w app/services/display_name.py, stosowane przy rejestracji, logowaniu
    Google/Apple i zmianie nicku. `email` zostaje jako pole opcjonalne
    wyłącznie dla starszych wersji aplikacji, które jeszcze go wysyłają.
    """

    display_name: str | None = None
    email: str | None = None


class ShoppingListShareResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    meal_plan_id: UUID
    status: str
    created_at: datetime
    # Nazwa drugiej strony — dla odbiorcy pokazujemy KTO udostępnił,
    # dla właściciela pokazujemy KOMU (frontend sam decyduje, które
    # pole akurat wyświetlić, w zależności od kontekstu ekranu).
    shared_by_name: str | None = None
    shared_with_name: str | None = None
    shared_with_email: str | None = None


@router.post(
    "/{list_id}/share",
    response_model=ShoppingListShareResponse,
    status_code=201,
    summary="Udostępnij listę zakupów innemu użytkownikowi (po nazwie)",
)
async def share_shopping_list(
    list_id: UUID,
    payload: ShareShoppingListRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListShare:
    """Tworzy ZAPROSZENIE (status "pending") dla użytkownika o podanym
    e-mailu — dostęp do listy dostaje dopiero PO zaakceptowaniu, nie
    natychmiast."""
    # Weryfikacja: tylko WŁAŚCICIEL planu może go udostępniać (nie
    # osoba, której ktoś inny już go udostępnił — bez tego można by
    # było "podudostępniać dalej" bez wiedzy/zgody oryginalnego
    # właściciela).
    # Starsze ekrany przekazywały publiczne ID planu, a część nowszych
    # operacji posługiwała się technicznym PK tabeli shopping_lists.
    # Udostępnianie akceptuje oba warianty i dalej używa jednego,
    # kanonicznego meal_plan_id. Zawartość listy (w tym pozycje „Inne”
    # bez product_id) nie bierze udziału w tworzeniu zaproszenia.
    plan_result = await db.execute(
        select(MealPlan)
        .join(ShoppingList, ShoppingList.meal_plan_id == MealPlan.id)
        .where(
            or_(MealPlan.id == list_id, ShoppingList.id == list_id),
            MealPlan.user_id == current_user.id,
        )
    )
    plan = plan_result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail=account_text(current_user,
            "Nie znaleziono Twojej listy zakupów do udostępnienia.", "Your shopping list to share was not found."))
    canonical_plan_id = plan.id

    if payload.display_name and payload.display_name.strip():
        # Porównanie bez rozróżniania wielkości liter — tak samo jak przy
        # sprawdzaniu zajętości nazwy, żeby "Kucharz" i "kucharz" trafiały
        # w to samo konto.
        needle = payload.display_name.strip().lower()
        # Akceptujemy także e-mail wpisany przez użytkowników starszej
        # wersji aplikacji, w której dialog udostępniania prosił o adres.
        target_result = await db.execute(
            select(User)
            .where(
                or_(
                    func.lower(User.display_name) == needle,
                    func.lower(User.email) == needle,
                )
            )
            .limit(2)
        )
        candidates = list(target_result.scalars().all())
        if len(candidates) > 1:
            email_match = [u for u in candidates if u.email.lower() == needle]
            if len(email_match) == 1:
                candidates = email_match
            else:
                raise HTTPException(
                    status_code=409,
                    detail=account_text(current_user, "Ta nazwa użytkownika nie jest jednoznaczna. Podaj jego adres e-mail.",
                        "More than one account uses this name. Enter the person's email address."),
                )
        target_user = candidates[0] if candidates else None
        not_found_detail = account_text(current_user, "Nie znaleziono użytkownika o takiej nazwie ani adresie e-mail.",
            "No user was found with that name or email address.")
    elif payload.email and payload.email.strip():
        # Ścieżka zgodności ze starszymi wersjami aplikacji.
        target_result = await db.execute(
            select(User).where(User.email == payload.email.strip().lower())
        )
        target_user = target_result.scalar_one_or_none()
        not_found_detail = account_text(current_user, "Nie znaleziono użytkownika o tym adresie e-mail.",
            "No user was found with that email address.")
    else:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Podaj nazwę użytkownika, któremu udostępniasz listę.", "Enter the name of the person you want to share the list with."))

    if target_user is None:
        raise HTTPException(status_code=404, detail=not_found_detail)
    if target_user.id == current_user.id:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nie możesz udostępnić listy samemu sobie.", "You cannot share a shopping list with yourself."))

    blocked_result = await db.execute(
        select(BlockedUser).where(
            or_(
                (
                    (BlockedUser.user_id == current_user.id)
                    & (BlockedUser.blocked_user_id == target_user.id)
                ),
                (
                    (BlockedUser.user_id == target_user.id)
                    & (BlockedUser.blocked_user_id == current_user.id)
                ),
            )
        )
    )
    if blocked_result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=403,
            detail=account_text(current_user, "Nie można udostępnić listy temu użytkownikowi.",
                "This shopping list cannot be shared with that user."),
        )

    # Jeśli zaproszenie już istnieje (pending lub accepted), nie
    # duplikujemy — po prostu zwracamy istniejący wpis.
    existing_result = await db.execute(
        select(ShoppingListShare).where(
            ShoppingListShare.meal_plan_id == canonical_plan_id,
            ShoppingListShare.shared_with_user_id == target_user.id,
        )
    )
    existing = existing_result.scalar_one_or_none()
    if existing is not None:
        return ShoppingListShareResponse(
            id=existing.id,
            meal_plan_id=existing.meal_plan_id,
            status=existing.status,
            created_at=existing.created_at,
            shared_with_name=target_user.display_name,
            shared_with_email=None,
        )
    else:
        from app.core.rate_limit import enforce_user_rate_limit, shopping_share_limiter

        enforce_user_rate_limit(shopping_share_limiter, current_user.id, "udostępnienie listy")
        share = ShoppingListShare(
            meal_plan_id=canonical_plan_id,
            shared_by_user_id=current_user.id,
            shared_with_user_id=target_user.id,
            status="pending",
        )
        db.add(share)
        await db.commit()
        await db.refresh(share)

    # Powiadomienie wysyłamy wyłącznie dla NOWEGO zaproszenia. Ponowne
    # kliknięcie „Udostępnij” nie może zasypywać odbiorcy duplikatami.
    # Bez niego zaproszenie byłoby całkowicie
    # niewidoczne: nic nie sygnalizowało, że ktoś udostępnił listę, więc
    # trafiało się na nie tylko przypadkiem, wchodząc w zaproszenia.
    from app.models.notification import Notification

    notification = Notification(
        user_id=target_user.id,
        notification_type="shopping_list_share",
        message=notification_text(target_user,
            f"{current_user.display_name or 'Ktoś'} udostępnił(a) Ci listę zakupów. "
            "Otwórz Zakupy → Zaproszenia, żeby ją przyjąć.",
            f"{current_user.display_name or 'Someone'} shared a shopping list with you. "
            "Open Shopping → Invitations to accept it.",
        ),
    )
    db.add(notification)
    await db.commit()

    try:
        from app.services.push import is_push_enabled, push_for_notification

        if is_push_enabled():
            await push_for_notification(db, notification)
    except Exception:
        # Push to dodatek — jego awaria nie może wywrócić udostępnienia.
        pass

    return ShoppingListShareResponse(
        id=share.id,
        meal_plan_id=share.meal_plan_id,
        status=share.status,
        created_at=share.created_at,
        shared_with_name=target_user.display_name,
        shared_with_email=None,
    )


@router.get(
    "/shares/pending",
    response_model=list[ShoppingListShareResponse],
    summary="Zaproszenia do współdzielonych list zakupów, oczekujące na Ciebie",
)
async def get_pending_shares(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ShoppingListShareResponse]:
    result = await db.execute(
        select(ShoppingListShare)
        .options(selectinload(ShoppingListShare.shared_by))
        .where(
            ShoppingListShare.shared_with_user_id == current_user.id,
            ShoppingListShare.status == "pending",
        )
        .order_by(ShoppingListShare.created_at.desc())
    )
    shares = result.scalars().all()
    return [
        ShoppingListShareResponse(
            id=s.id,
            meal_plan_id=s.meal_plan_id,
            status=s.status,
            created_at=s.created_at,
            shared_by_name=s.shared_by.display_name,
        )
        for s in shares
    ]


@router.get(
    "/shares/shared-with-me",
    response_model=list[ShoppingListShareResponse],
    summary="Listy zakupów, które ktoś Ci udostępnił i które zaakceptowałeś",
)
async def get_shared_with_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ShoppingListShareResponse]:
    result = await db.execute(
        select(ShoppingListShare)
        .options(selectinload(ShoppingListShare.shared_by))
        .where(
            ShoppingListShare.shared_with_user_id == current_user.id,
            ShoppingListShare.status == "accepted",
        )
        .order_by(ShoppingListShare.created_at.desc())
    )
    shares = result.scalars().all()
    return [
        ShoppingListShareResponse(
            id=s.id,
            meal_plan_id=s.meal_plan_id,
            status=s.status,
            created_at=s.created_at,
            shared_by_name=s.shared_by.display_name,
        )
        for s in shares
    ]


@router.post(
    "/shares/{share_id}/accept",
    response_model=ShoppingListShareResponse,
    summary="Zaakceptuj zaproszenie do współdzielonej listy",
)
async def accept_share(
    share_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ShoppingListShareResponse:
    result = await db.execute(
        select(ShoppingListShare)
        .options(selectinload(ShoppingListShare.shared_by))
        .where(ShoppingListShare.id == share_id, ShoppingListShare.shared_with_user_id == current_user.id)
    )
    share = result.scalar_one_or_none()
    if share is None:
        raise NotFoundException(detail=account_text(current_user,
            "Nie znaleziono tego zaproszenia.", "Shopping invitation not found."))

    if share.status == "accepted":
        return ShoppingListShareResponse(
            id=share.id,
            meal_plan_id=share.meal_plan_id,
            status=share.status,
            created_at=share.created_at,
            shared_by_name=share.shared_by.display_name,
        )

    share.status = "accepted"
    await db.commit()
    await db.refresh(share)

    # Powiadomienie dla NADAWCY — dotąd udostępniał listę i nigdy nie
    # dowiadywał się, czy druga osoba w ogóle przyjęła zaproszenie.
    from app.models.notification import Notification

    accept_notification = Notification(
        user_id=share.shared_by_user_id,
        # OSOBNY typ, nie "shopping_list_share": tamten ma tytuł
        # "Udostępniono Ci listę zakupów", co przy powiadomieniu
        # o PRZYJĘCIU zaproszenia brzmiałoby myląco — nikt wtedy
        # niczego nie udostępnia.
        notification_type="shopping_list_accepted",
        message=notification_text(share.shared_by,
            f"{current_user.display_name or 'Ktoś'} przyjął(-ęła) Twoje "
            "zaproszenie do listy zakupów.",
            f"{current_user.display_name or 'Someone'} accepted your shopping list invitation.",
        ),
    )
    db.add(accept_notification)
    await db.commit()

    try:
        from app.services.push import is_push_enabled, push_for_notification

        if is_push_enabled():
            await push_for_notification(db, accept_notification)
    except Exception:
        pass

    return ShoppingListShareResponse(
        id=share.id,
        meal_plan_id=share.meal_plan_id,
        status=share.status,
        created_at=share.created_at,
        shared_by_name=share.shared_by.display_name,
    )


@router.delete(
    "/shares/{share_id}",
    status_code=204,
    summary="Odrzuć zaproszenie / usuń udostępnienie / opuść współdzieloną listę",
)
async def delete_share(
    share_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Jeden endpoint na trzy sytuacje — bo to ta sama operacja z
    punktu widzenia bazy (usunięcie wiersza), różniąca się tylko
    KTO ją wywołuje: odbiorca odrzucający zaproszenie, odbiorca
    opuszczający już zaakceptowaną listę, albo właściciel odbierający
    komuś dostęp."""
    result = await db.execute(
        select(ShoppingListShare).where(
            ShoppingListShare.id == share_id,
            or_(
                ShoppingListShare.shared_with_user_id == current_user.id,
                ShoppingListShare.shared_by_user_id == current_user.id,
            ),
        )
    )
    share = result.scalar_one_or_none()
    if share is None:
        raise NotFoundException(detail=account_text(current_user,
            "Nie znaleziono tego udostępnienia.", "Shopping list share not found."))

    await db.delete(share)
    await db.commit()


# ══════════════════════════════════════════════════════════════════
# DOPISYWANIE POJEDYNCZEGO PRODUKTU
# Dotąd pozycje na liście mogły powstać WYŁĄCZNIE ze składników
# przepisów (/from-recipes). Nie dało się dorzucić zwykłego zakupu
# ("papier toaletowy", "mleko"), który nie należy do żadnego przepisu.
# ══════════════════════════════════════════════════════════════════
class AddItemRequest(BaseModel):
    product_id: UUID
    quantity: float = Field(default=1.0, gt=0, le=9999, allow_inf_nan=False)
    unit: str = Field(default="szt", min_length=1, max_length=20)


class AddCustomItemRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    quantity: float = Field(default=1.0, gt=0, le=9999)
    unit: str = Field(default="szt", min_length=1, max_length=20)


@router.post(
    "/{list_id}/items",
    status_code=201,
    summary="Dopisz pojedynczy produkt do listy zakupów",
)
async def add_item_to_shopping_list(
    list_id: UUID,
    payload: AddItemRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Dokłada produkt do istniejącej listy zakupów.

    Pozycja listy wskazuje na StoreProduct (produkt W KONKRETNYM
    SKLEPIE), nie na sam produkt — bo z tego biorą się cena i dział
    alejki. Dlatego szukamy produktu w sklepie przypisanym do TEJ listy.

    Jeśli produkt już na liście jest, sumujemy ilość zamiast tworzyć
    duplikat — inaczej dwukrotne dodanie tego samego dałoby dwie osobne
    pozycje do odhaczenia.
    """
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    product = await db.get(Product, payload.product_id)
    if product is None:
        raise NotFoundException(detail=account_text(current_user, "Produkt nie istnieje", "Product not found."))

    if payload.quantity <= 0:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Ilość musi być większa od zera", "Quantity must be greater than zero."))

    if getattr(shopping_list.store, "country_code", "PL") == "GB":
        if shopping_list.status == "completed":
            raise HTTPException(status_code=409, detail=account_text(current_user,
                "Ta lista zakupów jest już zakończona.", "This shopping list is completed."))
        if product.review_status != "approved" and product.created_by_user_id != current_user.id:
            raise NotFoundException(detail=account_text(current_user, "Produkt nie istnieje", "Product not found."))
        offers = await load_regional_offers(db, {product.id}, shopping_list.store_id)
        quantity, unit = resolve_manual_regional_quantity(
            product, Decimal(str(payload.quantity)), payload.unit, offers,
            shopping_list.store_id, regional_pricing_date(),
        )
        existing = next((item for item in shopping_list.items
            if item.regional_snapshot is not None
            and item.regional_snapshot.product_id == product.id
            and item.unit == unit and not item.is_from_pantry and not item.is_checked), None)
        item = existing or ShoppingListItem(id=uuid4(), shopping_list_id=shopping_list.id, is_checked=False, is_generated=False)
        if existing is not None:
            if existing.is_generated:
                existing.regional_snapshot.manual_extra_quantity = (
                    existing.regional_snapshot.manual_extra_quantity or Decimal(0)
                ) + quantity
            quantity += existing.required_quantity
            item.is_checked = False
        apply_regional_item_quote(
            item, product=product, store_id=shopping_list.store_id,
            quantity=quantity, unit=unit, offers=offers, as_of=regional_pricing_date(),
        )
        db.add(item)
        await refresh_regional_plan_budget(db, shopping_list)
        await db.commit()
        return {"detail": account_text(current_user, "Zaktualizowano ilość istniejącej pozycji", "Updated shopping quantity")
                if existing else account_text(current_user, "Dodano produkt do listy", "Product added"),
                "item_id": str(item.id)}

    store_product_result = await db.execute(
        select(StoreProduct).where(
            StoreProduct.store_id == shopping_list.store_id,
            StoreProduct.product_id == payload.product_id,
        )
    )
    store_product = store_product_result.scalar_one_or_none()
    if store_product is None:
        raise HTTPException(
            status_code=400,
            detail=account_text(current_user,
                f'Produkt "{product.name}" nie jest dostępny w wybranym sklepie',
                "This product is not available in the selected shop."),
        )

    existing = next(
        (i for i in shopping_list.items
         if i.store_product_id == store_product.id and not i.is_from_pantry),
        None,
    )
    if existing is not None:
        existing.required_quantity = existing.required_quantity + Decimal(str(payload.quantity))
        db.add(existing)
        await db.commit()
        return {"detail": account_text(current_user, "Zaktualizowano ilość istniejącej pozycji", "Item quantity updated."),
                "item_id": str(existing.id)}

    item = ShoppingListItem(
        shopping_list_id=shopping_list.id,
        store_product_id=store_product.id,
        department_id=store_product.department_id,
        required_quantity=Decimal(str(payload.quantity)),
        unit=payload.unit,
        estimated_price=store_product.price,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return {"detail": account_text(current_user, "Dodano produkt do listy", "Product added to shopping list."),
            "item_id": str(item.id)}


@router.post(
    "/{list_id}/items/custom",
    status_code=201,
    summary="Dopisz dowolną pozycję tekstową do listy zakupów",
)
async def add_custom_item_to_shopping_list(
    list_id: UUID,
    payload: AddCustomItemRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Dodaje rzecz spoza katalogu spożywczego, np. baterie lub chemię.

    Nazwa jest normalizowana z nadmiarowych spacji. Ponowne dodanie tej
    samej nazwy zwiększa ilość zamiast tworzyć drugi wiersz.
    """
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)
    name = " ".join(payload.name.split()).strip()
    unit = payload.unit.strip() or "szt"
    if not name:
        raise HTTPException(status_code=400, detail=account_text(current_user, "Wpisz nazwę pozycji", "Enter an item name."))

    existing = next(
        (
            item
            for item in shopping_list.items
            if item.custom_name is not None
            and (getattr(item, "regional_snapshot", None) is None or item.regional_snapshot.product_id is None)
            and not item.is_from_pantry
            and item.custom_name.casefold() == name.casefold()
            and item.unit.casefold() == unit.casefold()
        ),
        None,
    )
    if existing is not None:
        existing.required_quantity += Decimal(str(payload.quantity))
        db.add(existing)
        await db.commit()
        return {
            "detail": account_text(current_user, "Zaktualizowano ilość istniejącej pozycji", "Item quantity updated."),
            "item_id": str(existing.id),
        }

    item = ShoppingListItem(
        shopping_list_id=shopping_list.id,
        store_product_id=None,
        custom_name=name,
        department_id=None,
        required_quantity=Decimal(str(payload.quantity)),
        unit=unit,
        estimated_price=None,
    )
    db.add(item)
    if getattr(shopping_list.store, "country_code", "PL") == "GB":
        item.regional_snapshot = ShoppingListItemRegionalSnapshot(
            product_id=None, store_id=shopping_list.store_id, name_en=name,
            country_code="GB", currency_code="GBP", quote_status="unpriced",
            required_quantity=None, required_unit=None, pricing_as_of=regional_pricing_date(),
        )
        await refresh_regional_plan_budget(db, shopping_list)
    await db.commit()
    await db.refresh(item)
    return {"detail": account_text(current_user, "Dodano pozycję do listy", "Item added to shopping list."), "item_id": str(item.id)}


@router.delete(
    "/{list_id}/items/{item_id}",
    status_code=204,
    summary="Usuń pozycję z listy zakupów",
)
async def delete_shopping_list_item(
    list_id: UUID,
    item_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Usuwa pojedynczą pozycję — potrzebne, żeby dało się skasować
    ręcznie dopisany produkt (wcześniej pozycji nie dało się usunąć
    wcale, można było je tylko odhaczać)."""
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    item = next((i for i in shopping_list.items if i.id == item_id), None)
    if item is None:
        raise NotFoundException(detail=account_text(current_user,
            "Pozycja nie istnieje na tej liście", "Item not found on this shopping list."))

    await db.delete(item)
    if getattr(shopping_list.store, "country_code", "PL") == "GB":
        await refresh_regional_plan_budget(db, shopping_list)
    await db.commit()


@router.post(
    "/{list_id}/complete",
    summary="Zakończ listę zakupów, opcjonalnie przenosząc kupione do spiżarni",
)
async def complete_shopping_list(
    list_id: UUID,
    move_to_pantry: bool = Query(
        default=True,
        description="Czy odhaczone produkty mają trafić do spiżarni",
    ),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Domyka zakupy: oznacza listę jako zakończoną i (domyślnie)
    przenosi ODHACZONE produkty do spiżarni użytkownika.

    Przenosimy wyłącznie pozycje odhaczone — nieodhaczone to rzeczy,
    których użytkownik nie kupił, więc wrzucenie ich do spiżarni
    zafałszowałoby dopasowywanie przepisów ("co ugotować z tego, co mam").

    Produkt już obecny w spiżarni jest AKTUALIZOWANY (sumujemy ilość),
    a nie duplikowany — na tabeli jest ograniczenie unikalności pary
    (użytkownik, produkt), więc próba wstawienia duplikatu skończyłaby
    się błędem bazy.
    """
    from app.models.pantry import PantryItem

    # Serializuj przyrost spiżarni konta oraz zakończenie współdzielonej
    # listy. Ponowna próba po timeoutcie nie może przenieść zakupów drugi raz.
    await db.execute(select(User.id).where(User.id == current_user.id).with_for_update())
    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db, for_update=True)
    if shopping_list.status == "completed":
        return {"detail": account_text(current_user, "Lista zakończona", "Shopping list completed."), "moved_to_pantry": 0}

    moved = 0
    if move_to_pantry:
        gb = getattr(shopping_list.store, "country_code", "PL") == "GB"
        if gb:
            moved = await complete_regional_items_to_pantry(db, shopping_list, current_user.id)
        for item in ([] if gb else shopping_list.items):
            if not item.is_checked or item.is_from_pantry:
                continue
            store_product = item.store_product
            if store_product is None:
                continue
            product_id = store_product.product_id

            existing_result = await db.execute(
                select(PantryItem).where(
                    PantryItem.user_id == current_user.id,
                    PantryItem.product_id == product_id,
                )
            )
            existing = existing_result.scalar_one_or_none()
            if existing is not None:
                existing.quantity = (existing.quantity or Decimal(0)) + item.required_quantity
                existing.unit = existing.unit or item.unit
                db.add(existing)
            else:
                db.add(
                    PantryItem(
                        user_id=current_user.id,
                        product_id=product_id,
                        quantity=item.required_quantity,
                        unit=item.unit,
                    )
                )
            moved += 1

    shopping_list.status = "completed"
    db.add(shopping_list)
    await db.commit()

    return {"detail": account_text(current_user, "Lista zakończona", "Shopping list completed."), "moved_to_pantry": moved}
