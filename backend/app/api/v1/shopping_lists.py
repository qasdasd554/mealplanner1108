"""Endpointy list zakupów — przeglądanie, oznaczanie, zamienniki."""

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict
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
    Product,
    Recipe,
    ShoppingList,
    ShoppingListItem,
    ShoppingListShare,
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
            MealPlan.id == list_id, MealPlan.user_id == current_user.id, MealPlan.status == "archived"
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail="Nie znaleziono listy zakupów do usunięcia.")

    await db.delete(plan)
    await db.commit()


# ══════════════════════════════════════════════════════════════════
# UDOSTĘPNIANIE LIST ZAKUPÓW — dwuetapowe (zaproszenie -> akceptacja),
# żeby nikt nie mógł po cichu dodać kogoś do współdzielonej listy bez
# jego wiedzy. Po zaakceptowaniu, _get_shopping_list_or_404 (patrz
# wyżej) automatycznie daje odbiorcy dostęp do WSZYSTKICH istniejących
# operacji na tej liście (podgląd, odhaczanie, zamienniki).
# ══════════════════════════════════════════════════════════════════
class ShareShoppingListRequest(BaseModel):
    email: str


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
    summary="Udostępnij listę zakupów innemu użytkownikowi (po e-mailu)",
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
    plan_result = await db.execute(
        select(MealPlan).where(MealPlan.id == list_id, MealPlan.user_id == current_user.id)
    )
    plan = plan_result.scalar_one_or_none()
    if plan is None:
        raise NotFoundException(detail="Nie znaleziono Twojej listy zakupów do udostępnienia.")

    target_result = await db.execute(select(User).where(User.email == payload.email.strip().lower()))
    target_user = target_result.scalar_one_or_none()
    if target_user is None:
        raise HTTPException(
            status_code=404,
            detail="Nie znaleziono użytkownika Meal Planner Polska o tym adresie e-mail.",
        )
    if target_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Nie możesz udostępnić listy samemu sobie.")

    # Jeśli zaproszenie już istnieje (pending lub accepted), nie
    # duplikujemy — po prostu zwracamy istniejący wpis.
    existing_result = await db.execute(
        select(ShoppingListShare).where(
            ShoppingListShare.meal_plan_id == list_id,
            ShoppingListShare.shared_with_user_id == target_user.id,
        )
    )
    existing = existing_result.scalar_one_or_none()
    if existing is not None:
        share = existing
    else:
        share = ShoppingListShare(
            meal_plan_id=list_id,
            shared_by_user_id=current_user.id,
            shared_with_user_id=target_user.id,
            status="pending",
        )
        db.add(share)
        await db.commit()
        await db.refresh(share)

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

    share.status = "accepted"
    await db.commit()
    await db.refresh(share)

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
