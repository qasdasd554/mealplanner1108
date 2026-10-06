"""Endpointy spiżarni — produkty, które użytkownik ma faktycznie w domu."""

import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import PantryItem, Product, User
from app.schemas.product import ProductResponse
from app.services.pantry_shopping_sync import sync_product_in_shopping_lists

router = APIRouter()


class PantryItemResponse(BaseModel):
    """Pojedynczy produkt w spiżarni, z pełnymi danymi produktu (nazwa,
    jednostka domyślna itd.) — żeby frontend nie musiał robić osobnego
    zapytania o każdy produkt."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product: ProductResponse
    quantity: float | None = None
    unit: str | None = None


class AddPantryItemsRequest(BaseModel):
    """Żądanie dodania jednego lub wielu produktów do spiżarni naraz —
    np. po odhaczeniu pozycji na liście zakupów jako kupionych."""

    product_ids: list[uuid.UUID]
    quantity: float | None = None
    unit: str | None = None


class AddPantryBarcodeRequest(BaseModel):
    barcode: str
    quantity: float
    unit: str
    batch: bool = False
    name: str | None = Field(None, min_length=2, max_length=300)
    brand: str | None = Field(None, max_length=200)
    kcal_per_100: float | None = Field(None, ge=0, le=2_000)
    protein_per_100: float | None = Field(None, ge=0, le=200)
    fat_per_100: float | None = Field(None, ge=0, le=200)
    carbs_per_100: float | None = Field(None, ge=0, le=200)


class UpdatePantryItemQuantityRequest(BaseModel):
    """Żądanie ustawienia/zmiany ilości JUŻ istniejącego produktu w
    spiżarni — osobny, mały endpoint (nie część dodawania), bo to
    typowy przepływ: najpierw dodajesz produkt jednym dotknięciem,
    potem, jeśli chcesz, doprecyzowujesz ile go dokładnie masz."""

    quantity: float | None = None
    unit: str | None = None


def merge_scanned_nutrition(
    current: dict | None,
    scanned: dict[str, float | None],
) -> tuple[dict, bool]:
    """Uzupełnia makro ze skanera bez nadpisywania poprawnych danych.

    W starszych wersjach brakujące wartości były materializowane jako cztery
    zera. Taki komplet jest traktowany jako placeholder i może zostać
    zastąpiony rozpoznanymi wartościami z etykiety/Open Food Facts.
    """
    merged = dict(current or {})
    keys = ("kcal", "protein", "fat", "carbs")
    stored_values = [merged.get(key) for key in keys]
    placeholder_zeros = all(
        value is None or float(value) == 0 for value in stored_values
    )
    changed = False
    for key, value in scanned.items():
        if value is not None and (merged.get(key) is None or placeholder_zeros):
            merged[key] = value
            changed = True
    if changed:
        merged.setdefault("fiber", 0)
    return merged, changed


def barcode_package_amount() -> tuple[float, str]:
    """Każdy skan zapisujemy jako jeden cały produkt, nie jako 100 g/ml."""
    return 1.0, "opak"


@router.get("/", response_model=list[PantryItemResponse], summary="Twoja spiżarnia")
async def get_pantry(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PantryItem]:
    """Zwraca wszystkie produkty aktualnie zapisane w spiżarni
    użytkownika, posortowane od najnowiej dodanych."""
    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.user_id == current_user.id)
        .order_by(PantryItem.added_at.desc())
    )
    return list(result.scalars().all())


@router.post(
    "/",
    response_model=list[PantryItemResponse],
    status_code=201,
    summary="Dodaj produkty do spiżarni",
)
async def add_pantry_items(
    payload: AddPantryItemsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PantryItem]:
    """Dodaje jeden lub wiele produktów do spiżarni. Jeśli dany produkt
    JUŻ jest w spiżarni tego użytkownika (unikalność user_id+product_id
    w bazie), po prostu nie dubluje wpisu — cicho pomija, bez błędu,
    żeby dało się bezpiecznie wysłać całą listę zakupów naraz bez
    martwienia się, czy coś już tam jest."""
    if not payload.product_ids:
        raise HTTPException(status_code=400, detail="Podaj przynajmniej jeden produkt")

    # Sprawdź, które z podanych produktów faktycznie istnieją w katalogu.
    existing_products = await db.execute(
        select(Product.id).where(Product.id.in_(payload.product_ids))
    )
    valid_ids = set(existing_products.scalars().all())

    # Sprawdź, co JUŻ jest w spiżarni tego użytkownika, żeby nie
    # naruszyć unikalności (user_id, product_id) przy próbie dodania
    # czegoś, co już tam jest.
    already_have = await db.execute(
        select(PantryItem.product_id).where(
            PantryItem.user_id == current_user.id,
            PantryItem.product_id.in_(valid_ids),
        )
    )
    already_have_ids = set(already_have.scalars().all())

    to_add = valid_ids - already_have_ids
    for product_id in to_add:
        db.add(PantryItem(
            user_id=current_user.id,
            product_id=product_id,
            quantity=payload.quantity,
            unit=payload.unit,
        ))
    if payload.quantity is not None and already_have_ids:
        existing_items = await db.execute(
            select(PantryItem).where(
                PantryItem.user_id == current_user.id,
                PantryItem.product_id.in_(already_have_ids),
            )
        )
        for item in existing_items.scalars().all():
            item.quantity = payload.quantity
            if payload.unit is not None:
                item.unit = payload.unit
    await db.flush()
    for product_id in valid_ids:
        await sync_product_in_shopping_lists(db, current_user.id, product_id)
    await db.commit()

    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.user_id == current_user.id)
        .order_by(PantryItem.added_at.desc())
    )
    return list(result.scalars().all())


@router.post(
    "/from-barcode",
    response_model=PantryItemResponse,
    status_code=201,
    summary="Zeskanuj produkt i dodaj go do spiżarni",
)
async def add_pantry_item_from_barcode(
    payload: AddPantryBarcodeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PantryItem:
    """Rozpoznaje kod, materializuje wynik OFF/cache jako produkt użytkownika
    i od razu zapisuje go w spiżarni wraz z ilością.
    """
    if payload.batch:
        from app.core.premium import is_premium_active

        if not is_premium_active(current_user):
            raise HTTPException(
                status_code=403,
                detail="Skanowanie seryjne jest dostępne w Premium.",
            )

    if payload.quantity <= 0:
        raise HTTPException(status_code=400, detail="Ilość musi być większa od zera")
    if payload.unit not in {
        "g", "kg", "ml", "l", "szt", "opak", "porcja", "lyzeczka", "szklanka"
    }:
        raise HTTPException(status_code=400, detail="Nieprawidłowa jednostka")

    from app.api.v1.products import lookup_barcode
    from app.services.barcode_lookup import barcode_variants, normalize_barcode

    barcode = normalize_barcode(payload.barcode)
    if barcode is None:
        raise HTTPException(status_code=400, detail="Nieprawidłowy kod EAN/UPC")
    lookup = await lookup_barcode(
        barcode=barcode,
        background_tasks=BackgroundTasks(),
        current_user=current_user,
        db=db,
    )
    lookup_found = bool(lookup.found and lookup.name)
    client_values = (
        payload.kcal_per_100,
        payload.protein_per_100,
        payload.fat_per_100,
        payload.carbs_per_100,
    )
    client_fallback = bool(
        payload.name
        and all(value is not None for value in client_values)
        and any((value or 0) > 0 for value in client_values)
    )
    if not lookup_found and not client_fallback:
        raise NotFoundException(detail="Nie znaleziono produktu o tym kodzie kreskowym.")

    # Skaner seryjny może uzupełnić starszy, niepełny rekord Neon danymi
    # pobranymi bezpośrednio z Open Food Facts. Nie tracimy ich podczas
    # drugiego żądania wykonywanego przy zapisie do spiżarni.
    # Dane zweryfikowane przez backend mają pierwszeństwo. Wartości z
    # telefonu tylko uzupełniają braki (np. gdy telefon zdążył pobrać OFF
    # bezpośrednio po limicie 429 na wspólnym adresie Rendera). Zapobiega to
    # nadpisaniu poprawnego makro dowolnymi wartościami przesłanymi ręcznie.
    resolved_nutrition = {
        "kcal": lookup.kcal_per_100 if lookup_found and lookup.kcal_per_100 is not None else payload.kcal_per_100,
        "protein": (
            lookup.protein_per_100
            if lookup_found and lookup.protein_per_100 is not None
            else payload.protein_per_100
        ),
        "fat": lookup.fat_per_100 if lookup_found and lookup.fat_per_100 is not None else payload.fat_per_100,
        "carbs": (
            lookup.carbs_per_100
            if lookup_found and lookup.carbs_per_100 is not None
            else payload.carbs_per_100
        ),
    }

    # Skan seryjny przesyła 1 opakowanie, natomiast po skanie pojedynczym
    # użytkownik może od razu wybrać opakowanie, g/ml, sztukę, łyżeczkę lub
    # szklankę. Nie nadpisujemy już świadomego wyboru stałą wartością.
    item_quantity, item_unit = payload.quantity, payload.unit

    product = None
    if lookup_found and lookup.existing_product_id is not None:
        product = await db.get(Product, lookup.existing_product_id)
    if product is None:
        product_result = await db.execute(
            select(Product).where(Product.barcode.in_(barcode_variants(barcode))).limit(1)
        )
        product = product_result.scalar_one_or_none()
    if product is None:
        from app.services.product_measures import build_measure_options

        lookup_unit = lookup.unit if lookup_found else "g"
        package_size = lookup.serving_quantity if lookup_found else None
        nutrition = {
            "kcal": resolved_nutrition["kcal"] or 0,
            "protein": resolved_nutrition["protein"] or 0,
            "fat": resolved_nutrition["fat"] or 0,
            "carbs": resolved_nutrition["carbs"] or 0,
            "fiber": 0,
        }
        product = Product(
            name=(lookup.name if lookup_found else None) or payload.name,
            brand=(lookup.brand if lookup_found else None) or payload.brand,
            unit="opak",
            default_quantity=1,
            serving_quantity=package_size,
            measure_options=build_measure_options(
                (lookup.name if lookup_found else None) or payload.name or "Produkt",
                lookup_unit,
                1,
                package_size,
            ),
            barcode=barcode,
            nutrition_per_100=nutrition,
            # Dane zostały już rozpoznane przez ten sam zweryfikowany
            # mechanizm skanera (katalog/Neon/OFF), więc nie wrzucamy ich
            # ponownie do kolejki ręcznych zgłoszeń administratora.
            created_by_user_id=None if lookup_found else current_user.id,
            review_status="approved" if lookup_found else "pending",
        )
        db.add(product)
        await db.flush()
    else:
        # Starsze produkty utworzone przez skaner mogły być zapisane jako
        # 100 g/ml. Normalizujemy je również przy kolejnym użyciu.
        product.unit = "opak"
        product.default_quantity = 1
        if not product.measure_options:
            from app.services.product_measures import build_measure_options

            product.measure_options = build_measure_options(
                product.name,
                lookup.unit if lookup_found else product.unit,
                float(product.default_quantity or 1),
                product.serving_quantity,
            )
        current_nutrition, nutrition_changed = merge_scanned_nutrition(
            product.nutrition_per_100,
            resolved_nutrition,
        )
        if nutrition_changed:
            product.nutrition_per_100 = current_nutrition

    pantry_result = await db.execute(
        select(PantryItem).where(
            PantryItem.user_id == current_user.id,
            PantryItem.product_id == product.id,
        )
    )
    item = pantry_result.scalar_one_or_none()
    if item is None:
        item = PantryItem(user_id=current_user.id, product_id=product.id)
        db.add(item)
    item.quantity = item_quantity
    item.unit = item_unit
    await db.flush()
    await sync_product_in_shopping_lists(db, current_user.id, product.id)
    await db.commit()

    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.id == item.id)
    )
    return result.scalar_one()


@router.patch(
    "/{item_id}",
    response_model=PantryItemResponse,
    summary="Ustaw ilość produktu w spiżarni",
)
async def update_pantry_item_quantity(
    item_id: uuid.UUID,
    payload: UpdatePantryItemQuantityRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PantryItem:
    """Ustawia/zmienia ilość (i opcjonalnie jednostkę) już istniejącej
    pozycji w spiżarni. Ilość jest CELOWO opcjonalna i informacyjna —
    dopasowywanie przepisów sprawdza tylko OBECNOŚĆ produktu, nie ilość
    (patrz komentarz przy modelu PantryItem)."""
    result = await db.execute(
        select(PantryItem)
        .options(selectinload(PantryItem.product))
        .where(PantryItem.id == item_id, PantryItem.user_id == current_user.id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(detail="Nie znaleziono tego produktu w Twojej spiżarni.")

    item.quantity = payload.quantity
    if payload.unit is not None:
        if payload.unit not in {
            "g", "kg", "ml", "l", "szt", "opak", "porcja", "lyzeczka", "szklanka"
        }:
            raise HTTPException(status_code=400, detail="Nieprawidłowa jednostka")
        item.unit = payload.unit
    await db.flush()
    await sync_product_in_shopping_lists(db, current_user.id, item.product_id)
    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204, summary="Usuń produkt ze spiżarni")
async def delete_pantry_item(
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(PantryItem).where(PantryItem.id == item_id, PantryItem.user_id == current_user.id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise NotFoundException(detail="Nie znaleziono tego produktu w Twojej spiżarni.")

    product_id = item.product_id
    await db.delete(item)
    await db.flush()
    await sync_product_in_shopping_lists(db, current_user.id, product_id)
    await db.commit()
