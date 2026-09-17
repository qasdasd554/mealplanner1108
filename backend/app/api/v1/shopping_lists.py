"""Endpointy list zakupów — przeglądanie, oznaczanie, zamienniki."""

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import exists, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.core.premium import is_premium_active
from app.db.session import get_db
from app.models import (
    MealPlan,
    MealPlanEntry,
    BlockedUser,
    Product,
    Recipe,
    ShoppingList,
    ShoppingListItem,
    ShoppingListShare,
    Store,
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


class EmptyShoppingListRequest(BaseModel):
    """Pierwsza, pusta lista tworzona przyciskiem „+” w Zakupach."""

    store_id: UUID


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
            ShoppingList.status != "completed",
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
    store = await db.get(Store, payload.store_id)
    if store is None:
        raise NotFoundException(detail="Wybrany sklep nie istnieje")

    count_result = await db.execute(
        select(func.count(ShoppingList.id))
        .join(MealPlan, MealPlan.id == ShoppingList.meal_plan_id)
        .where(
            MealPlan.user_id == current_user.id,
            MealPlan.status == "archived",
            ShoppingList.status != "completed",
        )
    )
    current_count = count_result.scalar() or 0
    limit = (
        MAX_SHOPPING_LISTS_PREMIUM
        if is_premium_active(current_user)
        else MAX_SHOPPING_LISTS_STANDARD
    )
    if current_count >= limit:
        raise HTTPException(
            status_code=403,
            detail=f"Osiągnięto limit aktywnych list zakupów ({limit}).",
        )

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
            or_(MealPlan.user_id == current_user.id, shared_access),
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
            MealPlan.id == list_id, MealPlan.user_id == current_user.id
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail="Nie znaleziono listy zakupów do usunięcia.")

    if plan.status == "archived":
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
            raise NotFoundException(detail="Ten plan nie ma listy zakupów.")
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
        raise NotFoundException(detail="Nie znaleziono Twojej listy zakupów do udostępnienia.")
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
                    detail="Ta nazwa użytkownika nie jest jednoznaczna. Podaj jego adres e-mail.",
                )
        target_user = candidates[0] if candidates else None
        not_found_detail = "Nie znaleziono użytkownika o takiej nazwie ani adresie e-mail."
    elif payload.email and payload.email.strip():
        # Ścieżka zgodności ze starszymi wersjami aplikacji.
        target_result = await db.execute(
            select(User).where(User.email == payload.email.strip().lower())
        )
        target_user = target_result.scalar_one_or_none()
        not_found_detail = "Nie znaleziono użytkownika o tym adresie e-mail."
    else:
        raise HTTPException(status_code=400, detail="Podaj nazwę użytkownika, któremu udostępniasz listę.")

    if target_user is None:
        raise HTTPException(status_code=404, detail=not_found_detail)
    if target_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Nie możesz udostępnić listy samemu sobie.")

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
            detail="Nie można udostępnić listy temu użytkownikowi.",
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
            shared_with_email=target_user.email,
        )
    else:
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
        message=(
            f"{current_user.display_name or 'Ktoś'} udostępnił(a) Ci listę zakupów. "
            "Otwórz Zakupy → Zaproszenia, żeby ją przyjąć."
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
        shared_with_email=target_user.email,
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
        raise NotFoundException(detail="Nie znaleziono tego zaproszenia.")

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
        message=(
            f"{current_user.display_name or 'Ktoś'} przyjął(-ęła) Twoje "
            "zaproszenie do listy zakupów."
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
        raise NotFoundException(detail="Nie znaleziono tego udostępnienia.")

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
    quantity: float = 1.0
    unit: str = "szt"


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
        raise NotFoundException(detail="Produkt nie istnieje")

    if payload.quantity <= 0:
        raise HTTPException(status_code=400, detail="Ilość musi być większa od zera")

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
            detail=f'Produkt "{product.name}" nie jest dostępny w wybranym sklepie',
        )

    existing = next(
        (i for i in shopping_list.items if i.store_product_id == store_product.id),
        None,
    )
    if existing is not None:
        existing.required_quantity = existing.required_quantity + Decimal(str(payload.quantity))
        db.add(existing)
        await db.commit()
        return {"detail": "Zaktualizowano ilość istniejącej pozycji", "item_id": str(existing.id)}

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
    return {"detail": "Dodano produkt do listy", "item_id": str(item.id)}


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
        raise HTTPException(status_code=400, detail="Wpisz nazwę pozycji")

    existing = next(
        (
            item
            for item in shopping_list.items
            if item.custom_name is not None
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
            "detail": "Zaktualizowano ilość istniejącej pozycji",
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
    await db.commit()
    await db.refresh(item)
    return {"detail": "Dodano pozycję do listy", "item_id": str(item.id)}


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
        raise NotFoundException(detail="Pozycja nie istnieje na tej liście")

    await db.delete(item)
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

    shopping_list = await _get_shopping_list_or_404(list_id, current_user, db)

    moved = 0
    if move_to_pantry:
        for item in shopping_list.items:
            if not item.is_checked:
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

    return {"detail": "Lista zakończona", "moved_to_pantry": moved}
