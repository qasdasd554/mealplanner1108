"""Endpointy produktów i zamienników."""

import hashlib
import logging
import re
import unicodedata
import uuid
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_admin, get_current_user
from app.core.exceptions import NotFoundException
from app.db.session import get_db
from app.models import (
    BarcodeProductCache,
    Product,
    ProductContributionReward,
    ProductSubstitute,
    StoreProduct,
)
from app.models.user import User
from app.schemas.product import (
    ProductResponse,
    ProductSubmissionResponse,
    StoreProductResponse,
    SubstituteResponse,
)
from app.services import ProductSubstitutionService
from app.services.barcode_lookup import (
    BarcodeLookupResult,
    has_complete_nutrition,
    lookup_barcode_external,
    find_nutrition_by_name,
    merge_lookup_results,
    price_range_for_product,
)


# UWAGA (naprawa bezpieczeństwa): endpointy w tym pliku były CAŁKOWICIE
# otwarte — bez tokenu każdy mógł pobrać pełny katalog produktów, sklepów
# i cen (a więc też zeskrobać całą bazę jednym skryptem). To dane, na
# których opiera się aplikacja, i nie ma powodu udostępniać ich anonimowo.
# Router chroniony JEDNĄ zależnością na poziomie całego routera, zamiast
# dopisywania Depends do każdej funkcji z osobna — trudniej o pominięcie
# przy dodawaniu kolejnego endpointu w przyszłości.
router = APIRouter(dependencies=[Depends(get_current_user)])
logger = logging.getLogger(__name__)


def _visible_product_filter(user_id: UUID):
    """Jeden warunek widoczności używany przez wszystkie odczyty produktu.

    Bez tego szczegóły po UUID i zamienniki omijały filtr z listy produktów,
    więc znając identyfikator można było podejrzeć cudze zgłoszenie przed
    akceptacją administratora.
    """
    return or_(
        Product.review_status == "approved",
        Product.created_by_user_id == user_id,
    )


class BarcodeLookupResponse(BaseModel):
    """Wynik wyszukiwania po kodzie kreskowym — gotowy do wypełnienia
    formularza zgłoszenia, albo (gdy `existing_product_id` ustawione)
    do bezpośredniego wybrania istniejącego produktu bez zgłaszania
    niczego od nowa."""

    found: bool
    source: str | None = None
    name: str | None = None
    brand: str | None = None
    unit: str = "g"
    kcal_per_100: float | None = None
    protein_per_100: float | None = None
    fat_per_100: float | None = None
    carbs_per_100: float | None = None
    existing_product_id: uuid.UUID | None = None
    price_min: float | None = None
    price_max: float | None = None
    barcode: str | None = None
    serving_quantity: float | None = None


def _response_has_complete_nutrition(response: BarcodeLookupResponse) -> bool:
    values = (
        response.kcal_per_100,
        response.protein_per_100,
        response.fat_per_100,
        response.carbs_per_100,
    )
    return all(value is not None for value in values) and any(
        value > 0 for value in values if value is not None
    )


def _merge_local_barcode_response(
    local: BarcodeLookupResponse,
    external: BarcodeLookupResult,
) -> BarcodeLookupResponse:
    """Zachowuje zweryfikowaną nazwę lokalną, ale wymienia stare 0/0/0/0."""
    local_nutrition = (
        local.kcal_per_100,
        local.protein_per_100,
        local.fat_per_100,
        local.carbs_per_100,
    )
    placeholders = all(value == 0 for value in local_nutrition)

    def nutrition(
        local_value: float | None,
        external_value: float | None,
    ) -> float | None:
        if placeholders:
            return external_value
        return local_value if local_value is not None else external_value

    return BarcodeLookupResponse(
        found=True,
        source=f"{local.source}_enriched" if local.source else external.source,
        name=local.name or external.name,
        brand=local.brand or external.brand,
        unit=(
            external.unit
            if local.unit == "opak"
            and external.serving_quantity is not None
            and external.unit in {"g", "ml"}
            else local.unit or external.unit
        ),
        kcal_per_100=nutrition(local.kcal_per_100, external.kcal_per_100),
        protein_per_100=nutrition(
            local.protein_per_100, external.protein_per_100,
        ),
        fat_per_100=nutrition(local.fat_per_100, external.fat_per_100),
        carbs_per_100=nutrition(local.carbs_per_100, external.carbs_per_100),
        existing_product_id=local.existing_product_id,
        price_min=local.price_min if local.price_min is not None else external.price_min,
        price_max=local.price_max if local.price_max is not None else external.price_max,
        barcode=local.barcode or external.barcode,
        serving_quantity=(
            local.serving_quantity
            if local.serving_quantity is not None
            else external.serving_quantity
        ),
    )


class ProductNameSuggestion(BaseModel):
    found: bool = True
    source: str
    name: str
    brand: str | None = None
    unit: str = "g"
    barcode: str | None = None
    existing_product_id: uuid.UUID | None = None
    kcal_per_100: float | None = None
    protein_per_100: float | None = None
    fat_per_100: float | None = None
    carbs_per_100: float | None = None
    price_min: float | None = None
    price_max: float | None = None
    serving_quantity: float | None = None


class RecipeIngredientProductCreate(BaseModel):
    """Wybrany wynik wyszukiwania po nazwie użyty w prywatnym przepisie."""

    name: str = Field(..., min_length=2, max_length=300)
    brand: str | None = Field(None, max_length=200)
    unit: str = Field("g", max_length=20)
    barcode: str | None = Field(None, max_length=14)
    existing_product_id: uuid.UUID | None = None
    kcal_per_100: float | None = Field(None, ge=0, le=2_000)
    protein_per_100: float | None = Field(None, ge=0, le=200)
    fat_per_100: float | None = Field(None, ge=0, le=200)
    carbs_per_100: float | None = Field(None, ge=0, le=200)
    serving_quantity: float | None = Field(None, gt=0, le=100_000)


def _nutrition_values_are_complete(nutrition: dict | None) -> bool:
    values = [
        (nutrition or {}).get("kcal"),
        (nutrition or {}).get("protein"),
        (nutrition or {}).get("fat"),
        (nutrition or {}).get("carbs"),
    ]
    return all(value is not None for value in values) and any(
        float(value) > 0 for value in values if value is not None
    )


async def _enrich_recipe_ingredient_product(
    product: Product,
    payload: RecipeIngredientProductCreate,
    db: AsyncSession,
) -> Product:
    """Uzupełnia makro i gramaturę przed zapisaniem składnika przepisu."""
    changed = False
    incoming = {
        "kcal": payload.kcal_per_100,
        "protein": payload.protein_per_100,
        "fat": payload.fat_per_100,
        "carbs": payload.carbs_per_100,
        "fiber": (product.nutrition_per_100 or {}).get("fiber"),
    }
    if (
        not _nutrition_values_are_complete(product.nutrition_per_100)
        and _nutrition_values_are_complete(incoming)
    ):
        product.nutrition_per_100 = incoming
        changed = True
    if product.serving_quantity is None and payload.serving_quantity is not None:
        product.serving_quantity = payload.serving_quantity
        changed = True
    barcode = product.barcode or payload.barcode
    if barcode:
        from app.services.barcode_lookup import barcode_variants

        cached = (
            await db.execute(
                select(BarcodeProductCache)
                .where(BarcodeProductCache.barcode.in_(barcode_variants(barcode)))
                .limit(1)
            )
        ).scalar_one_or_none()
        if cached is not None:
            if (
                not _nutrition_values_are_complete(product.nutrition_per_100)
                and _nutrition_values_are_complete(cached.nutrition_per_100)
            ):
                product.nutrition_per_100 = dict(cached.nutrition_per_100 or {})
                changed = True
            if product.serving_quantity is None and cached.serving_quantity is not None:
                product.serving_quantity = cached.serving_quantity
                changed = True

    if not _nutrition_values_are_complete(product.nutrition_per_100):
        external = await lookup_barcode_external(barcode) if barcode else None
        if external is None or not has_complete_nutrition(external):
            by_name = await find_nutrition_by_name(product.name, product.brand)
            if by_name is not None:
                external = (
                    merge_lookup_results(external, by_name)
                    if external is not None
                    else by_name
                )
        if external is not None and has_complete_nutrition(external):
            product.nutrition_per_100 = {
                "kcal": external.kcal_per_100,
                "protein": external.protein_per_100,
                "fat": external.fat_per_100,
                "carbs": external.carbs_per_100,
                "fiber": (product.nutrition_per_100 or {}).get("fiber"),
            }
            if product.serving_quantity is None and external.serving_quantity is not None:
                product.serving_quantity = external.serving_quantity
            changed = True

    # Budujemy opcje dopiero po wzbogaceniu produktu, aby świeżo pobrana
    # gramatura opakowania od razu pojawiła się jako poprawny przelicznik.
    if not product.measure_options:
        from app.services.product_measures import build_measure_options

        product.measure_options = build_measure_options(
            product.name,
            product.unit,
            float(product.default_quantity or 0),
            product.serving_quantity,
        )
        changed = True

    if changed:
        await db.commit()
        await db.refresh(product)
    return product


async def _upsert_barcode_cache(
    db: AsyncSession,
    *,
    barcode: str,
    name: str,
    brand: str | None,
    unit: str,
    kcal_per_100: float | None,
    protein_per_100: float | None,
    fat_per_100: float | None,
    carbs_per_100: float | None,
    price_min: float,
    price_max: float,
    source: str,
    serving_quantity: float | None = None,
) -> None:
    """Zapisuje trafienie bez wyścigu między równoczesnymi skanami."""
    nutrition = {
        "kcal": kcal_per_100,
        "protein": protein_per_100,
        "fat": fat_per_100,
        "carbs": carbs_per_100,
    }
    values = {
        "barcode": barcode,
        "name": name,
        "brand": brand,
        "unit": unit,
        "nutrition_per_100": nutrition,
        "price_min": price_min,
        "price_max": price_max,
        "source": source,
        "serving_quantity": serving_quantity,
    }
    statement = insert(BarcodeProductCache).values(**values)
    statement = statement.on_conflict_do_update(
        index_elements=[BarcodeProductCache.barcode],
        set_={key: value for key, value in values.items() if key != "barcode"},
    )
    await db.execute(statement)
    await db.commit()


async def _persist_barcode_cache_in_background(**values) -> None:
    """Zapisuje trafienie po wysłaniu odpowiedzi do telefonu.

    Użytkownik dostaje wynik z OFF/USDA bez czekania na dodatkowy zapis
    w Neon. Następny skan korzysta już z lokalnego cache.
    """
    from app.db.session import async_session_factory

    try:
        async with async_session_factory() as session:
            await _upsert_barcode_cache(session, **values)
    except Exception:
        logger.exception("Nie udało się zapisać produktu w cache kodów kreskowych")


@router.get(
    "/",
    response_model=list[ProductResponse],
    summary="Lista produktów",
)
async def list_products(
    skip: int = Query(0, ge=0, description="Liczba rekordów do pominięcia"),
    limit: int = Query(50, ge=1, le=200, description="Maksymalna liczba wyników"),
    search: str | None = Query(None, description="Szukaj po nazwie produktu"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Product]:
    """Zwraca listę produktów z opcjonalnym wyszukiwaniem.

    Widoczne są produkty ZAAKCEPTOWANE oraz WŁASNE zgłoszenia bieżącego
    użytkownika — te ostatnie jeszcze przed decyzją administratora, żeby
    dało się ich od razu użyć w dzienniku kalorii. Cudze zgłoszenia
    oczekujące pozostają ukryte, dopóki nie zostaną zatwierdzone.
    """
    query = select(Product).where(_visible_product_filter(current_user.id))

    if search:
        query = query.where(Product.name.ilike(f"%{search}%"))

    query = query.order_by(Product.name).offset(skip).limit(limit)

    result = await db.execute(query)
    return list(result.scalars().all())


@router.get(
    "/barcode/{barcode}",
    response_model=BarcodeLookupResponse,
    summary="Wyszukaj produkt po kodzie kreskowym",
)
async def lookup_barcode(
    barcode: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BarcodeLookupResponse:
    """Najpierw przeszukuje dane w Neon, potem trzy zewnętrzne bazy.

    Każdy wynik zewnętrzny jest zapisywany w cache w Neon, dlatego następny
    skan tego samego kodu jest szybki i nie zużywa limitów publicznych API.

    Gdy nic nie znaleziono w żadnym źródle, frontend pokazuje wtedy
    pusty formularz zgłoszenia z już wpisanym kodem kreskowym, zamiast
    blokować użytkownika.
    """
    from app.services.barcode_lookup import barcode_variants, normalize_barcode

    normalized_barcode = normalize_barcode(barcode)
    if normalized_barcode is None:
        raise HTTPException(status_code=400, detail="Nieprawidłowy kod EAN/UPC")

    # 1. Własny katalog — widoczne to, co widziałby zwykły GET /products
    # (zaakceptowane PLUS własne zgłoszenia), żeby nie pokazywać komuś
    # cudzego jeszcze niezatwierdzonego zgłoszenia jako "gotowy produkt".
    local_response: BarcodeLookupResponse | None = None
    result = await db.execute(
        select(Product).where(
            Product.barcode.in_(barcode_variants(normalized_barcode)),
            or_(
                Product.review_status == "approved",
                Product.created_by_user_id == current_user.id,
            ),
        ).limit(1)
    )
    existing = result.scalar_one_or_none()
    if existing is not None:
        price_min, price_max = price_range_for_product(existing.name)
        local_response = BarcodeLookupResponse(
            found=True,
            source="catalog",
            name=existing.name,
            brand=existing.brand,
            unit=existing.unit,
            kcal_per_100=(existing.nutrition_per_100 or {}).get("kcal"),
            protein_per_100=(existing.nutrition_per_100 or {}).get("protein"),
            fat_per_100=(existing.nutrition_per_100 or {}).get("fat"),
            carbs_per_100=(existing.nutrition_per_100 or {}).get("carbs"),
            existing_product_id=existing.id,
            price_min=price_min,
            price_max=price_max,
            barcode=normalized_barcode,
            # Dla produktu zapisanego jako „1 opakowanie” fizycznej masy
            # szukamy niżej w cache skanera. Wartość 1 nie oznacza 1 grama.
            serving_quantity=(
                None
                if existing.unit == "opak"
                else (float(existing.default_quantity or 0) or None)
            ),
        )

    if local_response is not None and _response_has_complete_nutrition(
        local_response
    ):
        cached_result = await db.execute(
            select(BarcodeProductCache).where(
                BarcodeProductCache.barcode.in_(
                    barcode_variants(normalized_barcode)
                )
            ).limit(1)
        )
        cached = cached_result.scalar_one_or_none()
        if cached is not None and cached.serving_quantity is not None:
            local_response.serving_quantity = cached.serving_quantity
            # Jednostka opisuje podstawę masy opakowania, podczas gdy sam
            # zapis do katalogu/spiżarni pozostaje zawsze „1 opakowanie”.
            local_response.unit = cached.unit
        return local_response

    # 2. Cache Neon — wspólny dla wszystkich użytkowników.
    if local_response is None:
        cached_result = await db.execute(
            select(BarcodeProductCache).where(
                BarcodeProductCache.barcode.in_(
                    barcode_variants(normalized_barcode)
                )
            ).limit(1)
        )
        cached = cached_result.scalar_one_or_none()
        if cached is not None:
            nutrition = cached.nutrition_per_100 or {}
            local_response = BarcodeLookupResponse(
                found=True,
                source="neon_cache",
                name=cached.name,
                brand=cached.brand,
                unit=cached.unit,
                kcal_per_100=nutrition.get("kcal"),
                protein_per_100=nutrition.get("protein"),
                fat_per_100=nutrition.get("fat"),
                carbs_per_100=nutrition.get("carbs"),
                price_min=cached.price_min,
                price_max=cached.price_max,
                barcode=cached.barcode,
                serving_quantity=cached.serving_quantity,
            )
            if _response_has_complete_nutrition(local_response):
                return local_response

    # 3. Open Food Facts v3 oraz USDA FoodData Central. UPCitemdb zostało
    # usunięte z aktywnej ścieżki: często zwracało 429 i nie zawiera makro.
    external = await lookup_barcode_external(normalized_barcode)
    if external is not None:
        if not has_complete_nutrition(external):
            internet_nutrition = await find_nutrition_by_name(
                external.name,
                external.brand,
            )
            if internet_nutrition is not None:
                external = merge_lookup_results(external, internet_nutrition)
        response = (
            _merge_local_barcode_response(local_response, external)
            if local_response is not None
            else BarcodeLookupResponse(
                found=True,
                source=external.source,
                name=external.name,
                brand=external.brand,
                unit=external.unit,
                kcal_per_100=external.kcal_per_100,
                protein_per_100=external.protein_per_100,
                fat_per_100=external.fat_per_100,
                carbs_per_100=external.carbs_per_100,
                existing_product_id=None,
                price_min=external.price_min,
                price_max=external.price_max,
                barcode=normalized_barcode,
                serving_quantity=external.serving_quantity,
            )
        )
        if existing is not None and _response_has_complete_nutrition(response):
            existing.nutrition_per_100 = {
                "kcal": response.kcal_per_100,
                "protein": response.protein_per_100,
                "fat": response.fat_per_100,
                "carbs": response.carbs_per_100,
                "fiber": (existing.nutrition_per_100 or {}).get("fiber", 0),
            }
            await db.commit()
        # Zapis nie blokuje odpowiedzi. Po zakończeniu tego żądania FastAPI
        # otwiera osobną sesję i utrwala wynik dla kolejnych użytkowników.
        background_tasks.add_task(
            _persist_barcode_cache_in_background,
            barcode=normalized_barcode,
            name=response.name or external.name,
            brand=response.brand,
            unit=response.unit,
            kcal_per_100=response.kcal_per_100,
            protein_per_100=response.protein_per_100,
            fat_per_100=response.fat_per_100,
            carbs_per_100=response.carbs_per_100,
            price_min=response.price_min or external.price_min,
            price_max=response.price_max or external.price_max,
            source=response.source or external.source,
            serving_quantity=response.serving_quantity,
        )
        return response

    if local_response is not None:
        internet_nutrition = await find_nutrition_by_name(
            local_response.name or "",
            local_response.brand,
        )
        if internet_nutrition is not None:
            local_response = _merge_local_barcode_response(
                local_response,
                internet_nutrition,
            )
            if existing is not None and _response_has_complete_nutrition(
                local_response
            ):
                existing.nutrition_per_100 = {
                    "kcal": local_response.kcal_per_100,
                    "protein": local_response.protein_per_100,
                    "fat": local_response.fat_per_100,
                    "carbs": local_response.carbs_per_100,
                    "fiber": (existing.nutrition_per_100 or {}).get("fiber", 0),
                }
                await db.commit()
            background_tasks.add_task(
                _persist_barcode_cache_in_background,
                barcode=normalized_barcode,
                name=local_response.name or internet_nutrition.name,
                brand=local_response.brand,
                unit=internet_nutrition.unit,
                kcal_per_100=local_response.kcal_per_100,
                protein_per_100=local_response.protein_per_100,
                fat_per_100=local_response.fat_per_100,
                carbs_per_100=local_response.carbs_per_100,
                price_min=local_response.price_min or internet_nutrition.price_min,
                price_max=local_response.price_max or internet_nutrition.price_max,
                source="name_search_enriched",
                serving_quantity=local_response.serving_quantity,
            )
        return local_response

    return BarcodeLookupResponse(found=False, source=None, name=None)


class ProductLabelRecognitionRequest(BaseModel):
    barcode: str = Field(..., min_length=8, max_length=50)
    front_photo_base64: str
    nutrition_photo_base64: str

    @field_validator("front_photo_base64", "nutrition_photo_base64")
    @classmethod
    def validate_photo(cls, value: str) -> str:
        from app.core.photo_validation import validate_and_check_photo_base64

        return validate_and_check_photo_base64(value, 3 * 1024 * 1024)


class ProductLabelConfirmation(BaseModel):
    barcode: str = Field(..., min_length=8, max_length=50)
    name: str = Field(..., min_length=2, max_length=300)
    brand: str | None = Field(None, max_length=200)
    unit: str = Field("g", pattern="^(g|ml|szt)$")
    serving_quantity: float | None = Field(None, gt=0, le=100_000)
    kcal_per_100: float | None = Field(None, ge=0, le=2_000)
    protein_per_100: float | None = Field(None, ge=0, le=200)
    fat_per_100: float | None = Field(None, ge=0, le=200)
    carbs_per_100: float | None = Field(None, ge=0, le=200)


@router.post(
    "/barcode/recognize-label",
    response_model=BarcodeLookupResponse,
    summary="Rozpoznaj brakujący produkt z przodu opakowania i tabeli",
)
async def recognize_product_from_label(
    payload: ProductLabelRecognitionRequest,
    current_user: User = Depends(get_current_user),
) -> BarcodeLookupResponse:
    """Awaryjny OCR/AI uruchamiany wyłącznie po braku w bezpłatnych bazach."""
    from app.services.barcode_lookup import normalize_barcode
    from app.services.product_label_ai import (
        ProductLabelRecognitionError,
        recognize_product_label,
    )

    barcode = normalize_barcode(payload.barcode)
    if barcode is None:
        raise HTTPException(status_code=400, detail="Nieprawidłowy kod EAN/UPC")
    from app.core.rate_limit import enforce_user_rate_limit, product_label_ai_limiter

    enforce_user_rate_limit(
        product_label_ai_limiter,
        current_user.id,
        "rozpoznawanie etykiet produktów",
    )
    try:
        result = await recognize_product_label(
            barcode=barcode,
            front_photo_base64=payload.front_photo_base64,
            nutrition_photo_base64=payload.nutrition_photo_base64,
        )
    except ProductLabelRecognitionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    price_min, price_max = price_range_for_product(result["name"])
    result["price_min"] = price_min
    result["price_max"] = price_max
    return BarcodeLookupResponse(**result)


@router.post(
    "/barcode/confirm-label",
    response_model=BarcodeLookupResponse,
    summary="Potwierdź dane etykiety i zapisz produkt w Neon",
)
async def confirm_product_label(
    payload: ProductLabelConfirmation,
    db: AsyncSession = Depends(get_db),
) -> BarcodeLookupResponse:
    """Dopiero świadome potwierdzenie użytkownika zasila wspólny cache."""
    from app.services.barcode_lookup import normalize_barcode

    barcode = normalize_barcode(payload.barcode)
    if barcode is None:
        raise HTTPException(status_code=400, detail="Nieprawidłowy kod EAN/UPC")
    name = payload.name.strip()
    brand = (payload.brand or "").strip() or None
    price_min, price_max = price_range_for_product(name)
    await _upsert_barcode_cache(
        db,
        barcode=barcode,
        name=name,
        brand=brand,
        unit=payload.unit,
        kcal_per_100=payload.kcal_per_100,
        protein_per_100=payload.protein_per_100,
        fat_per_100=payload.fat_per_100,
        carbs_per_100=payload.carbs_per_100,
        price_min=price_min,
        price_max=price_max,
        source="product_label_ai_confirmed",
        serving_quantity=payload.serving_quantity,
    )
    return BarcodeLookupResponse(
        found=True,
        source="neon_cache",
        barcode=barcode,
        name=name,
        brand=brand,
        unit=payload.unit,
        serving_quantity=payload.serving_quantity,
        kcal_per_100=payload.kcal_per_100,
        protein_per_100=payload.protein_per_100,
        fat_per_100=payload.fat_per_100,
        carbs_per_100=payload.carbs_per_100,
        price_min=price_min,
        price_max=price_max,
    )


@router.get(
    "/scanned",
    response_model=list[ProductResponse],
    summary="Produkty zapamiętane po skanowaniu kodów kreskowych",
)
async def list_scanned_products(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Udostępnia cache Neon na liście produktów w Śledzeniu.

    Wcześniej rekord dało się znaleźć wyłącznie przez ponowne
    zeskanowanie tego samego kodu. Teraz można wyszukać go po nazwie,
    marce lub kodzie i dodać do dziennika bez ponownego skanowania.
    """
    query = select(BarcodeProductCache)
    if search and search.strip():
        pattern = f"%{search.strip()}%"
        query = query.where(
            or_(
                BarcodeProductCache.name.ilike(pattern),
                BarcodeProductCache.brand.ilike(pattern),
                BarcodeProductCache.barcode.ilike(pattern),
            )
        )
    result = await db.execute(
        query.order_by(BarcodeProductCache.updated_at.desc()).offset(skip).limit(limit)
    )
    return [
        {
            "id": entry.id,
            "name": entry.name,
            "brand": entry.brand,
            "unit": "opak",
            "default_quantity": 1,
            "serving_quantity": entry.serving_quantity,
            "barcode": entry.barcode,
            "nutrition_per_100": entry.nutrition_per_100 or {},
            "image_url": None,
            "created_at": entry.created_at,
            "review_status": "approved",
            "source": "scan",
        }
        for entry in result.scalars().all()
    ]


@router.get(
    "/search-by-name",
    response_model=list[ProductNameSuggestion],
    summary="Podpowiedzi produktów po nazwie z katalogu, skanów i Open Food Facts",
)
async def search_products_by_name(
    query: str = Query(..., min_length=2, max_length=120),
    limit: int = Query(10, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ProductNameSuggestion]:
    """Zwraca podpowiedzi bez odbierania możliwości ręcznego wpisania.

    Kolejność źródeł jest celowa: własny katalog, zapamiętane skany w Neon,
    a dopiero potem Open Food Facts — ta sama zewnętrzna baza, z której
    korzysta skanowanie kodów kreskowych.
    """
    normalized = " ".join(query.strip().split())
    pattern = f"%{normalized}%"

    catalog_result = await db.execute(
        select(Product)
        .where(
            _visible_product_filter(current_user.id),
            or_(Product.name.ilike(pattern), Product.brand.ilike(pattern)),
        )
        .order_by(Product.name)
        .limit(limit)
    )
    cache_result = await db.execute(
        select(BarcodeProductCache)
        .where(
            or_(
                BarcodeProductCache.name.ilike(pattern),
                BarcodeProductCache.brand.ilike(pattern),
            )
        )
        .order_by(BarcodeProductCache.updated_at.desc())
        .limit(limit)
    )

    suggestions: list[ProductNameSuggestion] = []
    suggestion_indexes: dict[tuple[str, str], int] = {}

    def suggestion_has_nutrition(suggestion: ProductNameSuggestion) -> bool:
        return _nutrition_values_are_complete({
            "kcal": suggestion.kcal_per_100,
            "protein": suggestion.protein_per_100,
            "fat": suggestion.fat_per_100,
            "carbs": suggestion.carbs_per_100,
        })

    def add_suggestion(suggestion: ProductNameSuggestion) -> None:
        key = (suggestion.name.casefold(), (suggestion.brand or "").casefold())
        existing_index = suggestion_indexes.get(key)
        if existing_index is not None:
            existing = suggestions[existing_index]
            if (
                not suggestion_has_nutrition(existing)
                and suggestion_has_nutrition(suggestion)
            ):
                existing.kcal_per_100 = suggestion.kcal_per_100
                existing.protein_per_100 = suggestion.protein_per_100
                existing.fat_per_100 = suggestion.fat_per_100
                existing.carbs_per_100 = suggestion.carbs_per_100
            if existing.serving_quantity is None:
                existing.serving_quantity = suggestion.serving_quantity
            if existing.barcode is None:
                existing.barcode = suggestion.barcode
            return
        if len(suggestions) < limit:
            suggestion_indexes[key] = len(suggestions)
            suggestions.append(suggestion)

    catalog_suggestions: list[ProductNameSuggestion] = []
    for product in catalog_result.scalars().all():
        nutrition = product.nutrition_per_100 or {}
        price_min, price_max = price_range_for_product(product.name)
        catalog_suggestions.append(ProductNameSuggestion(
            source="catalog",
            name=product.name,
            brand=product.brand,
            unit=product.unit,
            barcode=product.barcode,
            existing_product_id=product.id,
            kcal_per_100=nutrition.get("kcal"),
            protein_per_100=nutrition.get("protein"),
            fat_per_100=nutrition.get("fat"),
            carbs_per_100=nutrition.get("carbs"),
            price_min=price_min,
            price_max=price_max,
            serving_quantity=product.serving_quantity,
        ))

    cache_suggestions: list[ProductNameSuggestion] = []
    for cached in cache_result.scalars().all():
        nutrition = cached.nutrition_per_100 or {}
        cache_suggestions.append(ProductNameSuggestion(
            source="neon_cache",
            name=cached.name,
            brand=cached.brand,
            unit=cached.unit,
            barcode=cached.barcode,
            kcal_per_100=nutrition.get("kcal"),
            protein_per_100=nutrition.get("protein"),
            fat_per_100=nutrition.get("fat"),
            carbs_per_100=nutrition.get("carbs"),
            price_min=cached.price_min,
            price_max=cached.price_max,
            serving_quantity=cached.serving_quantity,
        ))

    # Bez rezerwacji katalog potrafi zapełnić cały limit, więc wyszukiwanie
    # zewnętrzne nigdy nie jest wywoływane dla popularnych składników.
    catalog_quota = max(1, limit // 2)
    cache_quota = max(0, limit // 5)
    for suggestion in catalog_suggestions[:catalog_quota]:
        add_suggestion(suggestion)
    for suggestion in cache_suggestions[:cache_quota]:
        add_suggestion(suggestion)

    if len(suggestions) < limit:
        from app.services.barcode_lookup import search_products_external

        external_results = await search_products_external(
            normalized,
            limit=limit - len(suggestions),
        )
        for external in external_results:
            add_suggestion(ProductNameSuggestion(
                source=external.source,
                name=external.name,
                brand=external.brand,
                unit=external.unit,
                barcode=external.barcode,
                kcal_per_100=external.kcal_per_100,
                protein_per_100=external.protein_per_100,
                fat_per_100=external.fat_per_100,
                carbs_per_100=external.carbs_per_100,
                price_min=external.price_min,
                price_max=external.price_max,
                serving_quantity=external.serving_quantity,
            ))

    # Gdy OFF jest niedostępne albo nie ma dopasowań, wykorzystaj pełny
    # limit wyników lokalnych zamiast zostawiać pustą część listy.
    for suggestion in catalog_suggestions[catalog_quota:]:
        add_suggestion(suggestion)
    for suggestion in cache_suggestions[cache_quota:]:
        add_suggestion(suggestion)

    return suggestions


@router.post(
    "/recipe-ingredient",
    response_model=ProductResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Użyj produktu z zewnętrznej bazy jako składnika przepisu",
)
async def resolve_recipe_ingredient_product(
    payload: RecipeIngredientProductCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Product:
    """Zwraca istniejący produkt albo tworzy prywatną kopię wyniku OFF.

    Składnik przepisu wymaga klucza obcego do products. Kopia nie trafia do
    publicznego katalogu ani kolejki moderacji i nie zajmuje unikalnego EAN-u.
    """
    if payload.existing_product_id is not None:
        result = await db.execute(select(Product).where(
            Product.id == payload.existing_product_id,
            _visible_product_filter(current_user.id),
        ))
        existing = result.scalar_one_or_none()
        if existing is None:
            raise HTTPException(status_code=404, detail="Nie znaleziono produktu")
        return await _enrich_recipe_ingredient_product(existing, payload, db)

    name = " ".join(payload.name.split())
    brand = (payload.brand or "").strip() or None
    unit = (
        payload.unit.strip()
        if payload.unit in {"g", "kg", "ml", "l", "szt", "opak"}
        else "g"
    )
    if payload.barcode:
        from app.services.barcode_lookup import barcode_variants

        result = await db.execute(select(Product).where(
            Product.barcode.in_(barcode_variants(payload.barcode)),
            _visible_product_filter(current_user.id),
        ).limit(1))
        existing = result.scalar_one_or_none()
        same_dimension = (
            existing is not None and (
                existing.unit == unit
                or {existing.unit, unit} <= {"g", "kg"}
                or {existing.unit, unit} <= {"ml", "l"}
            )
        )
        if same_dimension:
            return await _enrich_recipe_ingredient_product(existing, payload, db)
    result = await db.execute(select(Product).where(
        Product.created_by_user_id == current_user.id,
        Product.review_status == "private",
        Product.name == name,
        Product.brand == brand,
        Product.unit == unit,
    ).limit(1))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return await _enrich_recipe_ingredient_product(existing, payload, db)

    from app.core.rate_limit import enforce_user_rate_limit, recipe_ingredient_limiter

    enforce_user_rate_limit(
        recipe_ingredient_limiter, current_user.id, "dodawanie składników do przepisu"
    )
    nutrition = None
    if any(value is not None for value in (
        payload.kcal_per_100, payload.protein_per_100,
        payload.fat_per_100, payload.carbs_per_100,
    )):
        nutrition = {
            "kcal": payload.kcal_per_100,
            "protein": payload.protein_per_100,
            "fat": payload.fat_per_100,
            "carbs": payload.carbs_per_100,
            "fiber": None,
        }
    from app.services.product_measures import build_measure_options

    product = Product(
        name=name, brand=brand, unit=unit,
        default_quantity=Decimal(1 if unit in {"opak", "szt", "kg", "l"} else 100),
        serving_quantity=payload.serving_quantity,
        measure_options=build_measure_options(
            name,
            unit,
            1 if unit in {"opak", "szt", "kg", "l"} else 100,
            payload.serving_quantity,
        ),
        nutrition_per_100=nutrition,
        created_by_user_id=current_user.id, review_status="private",
        barcode=None,
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product


@router.get(
    "/mine",
    response_model=list[ProductResponse],
    summary="Produkty zgłoszone przeze mnie — dowolny status",
)
async def list_my_products(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Product]:
    """Wszystkie WŁASNE zgłoszenia użytkownika, niezależnie od statusu.

    NAPRAWA BRAKUJĄCEJ FUNKCJI: zgłoszony produkt zapisywał się
    w bazie (endpoint /submit działał), ale nigdzie w aplikacji nie było
    miejsca, które by go pokazało — ekran katalogu (`ProductsScreen`)
    wyświetla wyłącznie produkty POWIĄZANE ZE SKLEPEM (StoreProduct),
    a zgłoszenie świadomie nie tworzy takiego powiązania (patrz
    komentarz w submit_product). Efekt: produkt istniał w bazie, ale dla
    użytkownika wyglądało to tak, jakby zniknął bez śladu.
    """
    result = await db.execute(
        select(Product)
        .where(
            Product.created_by_user_id == current_user.id,
            Product.review_status != "private",
        )
        .order_by(Product.created_at.desc())
    )
    return list(result.scalars().all())


# Trasy statyczne GET muszą być przed /{product_id}. Inaczej FastAPI
# odczytuje "admin" jako identyfikator produktu i zwraca błąd UUID.
@router.get(
    "/admin/pending",
    response_model=list[ProductResponse],
    summary="Produkty zgłoszone przez użytkowników (admin)",
)
async def list_pending_products(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> list[Product]:
    result = await db.execute(
        select(Product)
        .where(Product.review_status == "pending")
        .order_by(Product.created_at.desc())
    )
    return list(result.scalars().all())


@router.get(
    "/{product_id}",
    response_model=ProductResponse,
    summary="Szczegóły produktu",
)
async def get_product(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Product:
    """Zwraca szczegóły produktu wraz z dostępnością w sklepach."""
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.store_products))
        .where(
            Product.id == product_id,
            _visible_product_filter(current_user.id),
        )
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise NotFoundException(
            detail=f"Produkt o ID {product_id} nie został znaleziony"
        )
    return product


@router.get(
    "/{product_id}/substitutes",
    response_model=list[SubstituteResponse],
    summary="Zamienniki produktu",
)
async def get_product_substitutes(
    product_id: UUID,
    store_id: UUID | None = Query(
        None, description="ID sklepu do filtrowania dostępnych zamienników"
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    """Zwraca listę zamienników dla danego produktu.

    Opcjonalnie filtruje zamienniki po dostępności w wybranym sklepie.
    """
    # Sprawdź czy produkt istnieje
    product_result = await db.execute(
        select(Product).where(
            Product.id == product_id,
            _visible_product_filter(current_user.id),
        )
    )
    if product_result.scalar_one_or_none() is None:
        raise NotFoundException(
            detail=f"Produkt o ID {product_id} nie został znaleziony"
        )

    if store_id is None:
        result = await db.execute(
            select(Product)
            .join(ProductSubstitute, ProductSubstitute.substitute_product_id == Product.id)
            .where(
                ProductSubstitute.original_product_id == product_id,
                _visible_product_filter(current_user.id),
            )
        )
        return [
            {
                "id": p.id,
                "name": p.name,
                "brand": p.brand,
                "price": None,
                "similarity_score": None,
            }
            for p in result.scalars().all()
        ]

    substitution_service = ProductSubstitutionService(db)
    results = await substitution_service.find_substitutes(
        product_id=product_id, store_id=store_id, limit=10
    )
    if not results:
        # Brak predefiniowanych zamienników (tabela product_substitutes) —
        # użyj wyszukiwania po podobieństwie wartości odżywczych w tym samym
        # dziale sklepu, tak jak robi to automatyczna obsługa wycofania produktu.
        results = await substitution_service.auto_find_similar(
            product_id=product_id, store_id=store_id, limit=10
        )
    response_list = []
    for r in results:
        prod = r["product"]
        if not (
            prod.review_status == "approved"
            or prod.created_by_user_id == current_user.id
        ):
            continue
        store_prod = r.get("store_product")
        kcal = None
        if prod.nutrition_per_100 and "kcal" in prod.nutrition_per_100:
            try:
                kcal = int(prod.nutrition_per_100["kcal"])
            except:
                pass
        response_list.append({
            "id": prod.id,
            "name": prod.name,
            "brand": prod.brand,
            "price": store_prod.price if store_prod else None,
            "kcal": kcal,
            "similarity_score": r.get("similarity_score")
        })
    return response_list


# ══════════════════════════════════════════════════════════════════
# PRODUKTY ZGŁASZANE PRZEZ UŻYTKOWNIKÓW
# ══════════════════════════════════════════════════════════════════
class ProductSubmission(BaseModel):
    """Zgłoszenie własnego produktu do katalogu.

    Wymagana jest tylko nazwa — cena i makroskładniki są opcjonalne, bo
    użytkownik nie zawsze ma etykietę pod ręką, a produkt bez nich i tak
    jest przydatny na liście zakupów. Przy braku danych odżywczych wpis
    w dzienniku kalorii doda po prostu 0 kcal.
    """

    name: str = Field(..., min_length=2, max_length=300)
    price: Decimal | None = Field(None, gt=0, le=10_000)
    unit: str = Field("szt", max_length=20)
    brand: str | None = Field(None, max_length=200)
    kcal_per_100: float | None = Field(None, ge=0, le=2_000)
    protein_per_100: float | None = Field(None, ge=0, le=200)
    fat_per_100: float | None = Field(None, ge=0, le=200)
    carbs_per_100: float | None = Field(None, ge=0, le=200)
    # OPCJONALNE — sklepy, w których zgłaszający chciałby widzieć ten
    # produkt. Sama lista niczego jeszcze nie tworzy; dopiero akceptacja
    # administratora zamienia każdy wskazany sklep na prawdziwy wiersz
    # StoreProduct z podaną ceną (patrz review_product niżej).
    store_ids: list[uuid.UUID] = Field(default_factory=list)
    # OPCJONALNE — jeśli produkt zgłoszono po zeskanowaniu kodu, zapisujemy
    # go, żeby KOLEJNE skanowanie tego samego produktu (przez kogokolwiek)
    # trafiało od razu w "własny katalog" (najszybsza, pierwsza gałąź
    # w lookup_barcode), zamiast za każdym razem pytać Open Food Facts.
    barcode: str | None = Field(None, max_length=50)
    serving_quantity: float | None = Field(None, gt=0, le=100_000)
    serving_unit: str | None = Field(None, pattern="^(g|ml|szt)$")


def _normalized_contribution_text(value: str | None) -> str:
    """Normalizuje tekst używany wyłącznie do ochrony przed duplikatami."""
    normalized = unicodedata.normalize("NFKC", value or "").casefold().strip()
    return re.sub(r"\s+", " ", normalized)


def _product_contribution_key(
    *, barcode: str | None, name: str, brand: str | None,
) -> str:
    """Stabilny, nieujawniający nazwy klucz jednorazowej nagrody."""
    if barcode:
        return f"barcode:{barcode}"
    identity = (
        f"{_normalized_contribution_text(name)}|"
        f"{_normalized_contribution_text(brand)}"
    )
    return f"manual:{hashlib.sha256(identity.encode('utf-8')).hexdigest()}"


@router.post(
    "/submit",
    response_model=ProductSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Zgłoś własny produkt do katalogu",
)
async def submit_product(
    payload: ProductSubmission,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProductSubmissionResponse:
    """Dodaje produkt oczekujący na akceptację administratora.

    Produkt jest od razu widoczny dla ZGŁASZAJĄCEGO (patrz filtr
    w list_products), więc może go użyć w dzienniku kalorii bez czekania.
    Dla pozostałych pojawi się dopiero po zatwierdzeniu.

    ŚWIADOMIE nie trafia do generatora przepisów ani planów posiłków:
    tamte korzystają z produktów powiązanych ze sklepami (StoreProduct),
    a zgłoszenie takiego powiązania nie ma. Dopiero administrator może
    je utworzyć przy akceptacji.
    """
    from app.core.rate_limit import enforce_user_rate_limit, product_submission_limiter

    enforce_user_rate_limit(
        product_submission_limiter, current_user.id, "zgłaszanie produktów"
    )

    normalized_barcode = None
    if payload.barcode:
        from app.services.barcode_lookup import normalize_barcode

        normalized_barcode = normalize_barcode(payload.barcode)
        if normalized_barcode is None:
            raise HTTPException(status_code=400, detail="Nieprawidłowy kod EAN/UPC")

    contribution_key = _product_contribution_key(
        barcode=normalized_barcode,
        name=payload.name,
        brand=payload.brand,
    )
    previous_reward = await db.scalar(
        select(ProductContributionReward.id).where(
            ProductContributionReward.user_id == current_user.id,
            ProductContributionReward.contribution_key == contribution_key,
        )
    )
    if previous_reward is not None:
        raise HTTPException(
            status_code=409,
            detail="Ten produkt został już przez Ciebie dodany i nagrodzony.",
        )

    nutrition = None
    if any(
        value is not None
        for value in (
            payload.kcal_per_100,
            payload.protein_per_100,
            payload.fat_per_100,
            payload.carbs_per_100,
        )
    ):
        nutrition = {
            "kcal": payload.kcal_per_100 or 0,
            "protein": payload.protein_per_100 or 0,
            "fat": payload.fat_per_100 or 0,
            "carbs": payload.carbs_per_100 or 0,
            "fiber": 0,
        }

    from app.services.product_measures import build_measure_options

    product_unit = "opak" if normalized_barcode else (payload.unit.strip() or "szt")
    product = Product(
        name=payload.name.strip(),
        brand=(payload.brand or "").strip() or None,
        unit=product_unit,
        default_quantity=Decimal(1),
        serving_quantity=payload.serving_quantity,
        measure_options=build_measure_options(
            payload.name,
            payload.serving_unit or product_unit,
            1,
            payload.serving_quantity,
        ),
        nutrition_per_100=nutrition,
        created_by_user_id=current_user.id,
        review_status="pending",
        submitted_price=payload.price,
        requested_store_ids=[str(sid) for sid in payload.store_ids] or None,
        barcode=normalized_barcode,
    )
    db.add(product)
    try:
        # Flush nadaje produktowi UUID, ale niczego jeszcze nie zatwierdza.
        # Produkt, zapis nagrody i zwiększenie salda są dzięki temu jedną
        # niepodzielną transakcją.
        await db.flush()
        locked_user = await db.scalar(
            select(User).where(User.id == current_user.id).with_for_update()
        )
        if locked_user is None:
            raise HTTPException(status_code=401, detail="Użytkownik nie istnieje")
        db.add(
            ProductContributionReward(
                user_id=locked_user.id,
                product_id=product.id,
                contribution_key=contribution_key,
                points_awarded=1,
            )
        )
        locked_user.premium_points = (locked_user.premium_points or 0) + 1
        await db.commit()
    except IntegrityError:
        # Ktoś inny zdążył zgłosić produkt z tym samym kodem kreskowym
        # (kolumna ma ograniczenie unikalności) — nie jest to prawdziwy
        # błąd użytkownika, tylko wyścig dwóch zgłoszeń naraz.
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail=(
                "Produkt z tym kodem kreskowym został już zgłoszony przez kogoś "
                "innego albo ten produkt został już przez Ciebie nagrodzony."
            ),
        )
    await db.refresh(product)
    await db.refresh(locked_user)

    if normalized_barcode and payload.serving_quantity is not None:
        price_min, price_max = price_range_for_product(product.name)
        await _upsert_barcode_cache(
            db,
            barcode=normalized_barcode,
            name=product.name,
            brand=product.brand,
            unit=payload.serving_unit or "g",
            kcal_per_100=payload.kcal_per_100,
            protein_per_100=payload.protein_per_100,
            fat_per_100=payload.fat_per_100,
            carbs_per_100=payload.carbs_per_100,
            price_min=price_min,
            price_max=price_max,
            source="user_confirmed_package",
            serving_quantity=payload.serving_quantity,
        )

    from app.services.admin_notifications import notify_admins_pending_review

    await notify_admins_pending_review(
        db,
        notification_type="product_pending_approval",
        message=(
            f'{current_user.display_name or "Użytkownik"} zgłosił(a) produkt '
            f'"{product.name}" — wymaga akceptacji.'
        ),
    )
    product_response = ProductResponse.model_validate(product)
    return ProductSubmissionResponse(
        **product_response.model_dump(),
        points_awarded=1,
        premium_points=locked_user.premium_points,
    )


@router.put(
    "/{product_id}",
    response_model=ProductResponse,
    summary="Edytuj własny zgłoszony produkt",
)
async def update_own_product(
    product_id: uuid.UUID,
    payload: ProductSubmission,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Product:
    """Edytuje WŁASNE zgłoszenie — nie działa na produktach oficjalnych
    (created_by_user_id puste) ani na cudzych zgłoszeniach.

    Edycja cofa produkt do statusu "pending", nawet jeśli był już
    zatwierdzony — inaczej użytkownik mógłby podmienić dane zatwierdzonego
    produktu (np. na coś nieodpowiedniego) bez ponownej moderacji.
    """
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono produktu")
    if product.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Możesz edytować tylko własne zgłoszenia."
        )

    was_pending = product.review_status == "pending"

    nutrition = None
    if payload.kcal_per_100 is not None:
        nutrition = {
            "kcal": payload.kcal_per_100,
            "protein": payload.protein_per_100 or 0,
            "fat": payload.fat_per_100 or 0,
            "carbs": payload.carbs_per_100 or 0,
            "fiber": 0,
        }

    product.name = payload.name.strip()
    product.brand = (payload.brand or "").strip() or None
    product.unit = payload.unit.strip() or "szt"
    product.nutrition_per_100 = nutrition
    product.submitted_price = payload.price
    product.requested_store_ids = [str(sid) for sid in payload.store_ids] or None
    # Tylko gdy jawnie podane — formularz edycji nie zawsze wysyła kod
    # kreskowy (np. gdy edytujący nie skanował ponownie), więc pusta
    # wartość NIE MA kasować już zapisanego kodu.
    if payload.barcode:
        product.barcode = payload.barcode.strip()
    # Patrz docstring — każda edycja wraca do kolejki moderacji.
    product.review_status = "pending"

    db.add(product)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Ten kod kreskowy jest już przypisany do innego produktu.",
        )
    await db.refresh(product)

    if not was_pending:
        from app.services.admin_notifications import notify_admins_pending_review

        await notify_admins_pending_review(
            db,
            notification_type="product_pending_approval",
            message=(
                f'{current_user.display_name or "Użytkownik"} ponownie zgłosił(a) '
                f'produkt "{product.name}" po edycji — wymaga akceptacji.'
            ),
        )
    return product


@router.delete(
    "/{product_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Usuń własny zgłoszony produkt",
)
async def delete_own_product(
    product_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    """Usuwa WŁASNE zgłoszenie. Nie działa na produktach oficjalnych ani
    cudzych zgłoszeniach — te może usunąć wyłącznie administrator
    (patrz osobny endpoint admina niżej, jeśli dodany)."""
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono produktu")
    if product.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Możesz usunąć tylko własne zgłoszenia."
        )
    await db.delete(product)
    await db.commit()


@router.post(
    "/admin/{product_id}/review",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Zatwierdź lub odrzuć zgłoszony produkt (admin)",
)
async def review_product(
    product_id: uuid.UUID,
    approve: bool = Query(..., description="true = zatwierdź, false = odrzuć"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_admin),
) -> None:
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Nie znaleziono produktu")

    product.review_status = "approved" if approve else "rejected"
    db.add(product)
    # Samą decyzję zapisujemy przed operacjami dodatkowymi. Błędny sklep
    # lub awaria powiadomienia nie może cofnąć akceptacji.
    await db.commit()

    # Przy akceptacji: każdy sklep zaproponowany przez zgłaszającego
    # zamieniamy na prawdziwy wiersz StoreProduct z podaną ceną — dopiero
    # to sprawia, że produkt faktycznie pojawia się w bazie danego sklepu
    # (a nie tylko w ogólnym katalogu). Pomijamy sklepy, które już mają
    # jakiś wpis dla tego produktu (ograniczenie unikalności store+product
    # i tak by to odrzuciło, ale sprawdzamy jawnie, żeby dać się temu
    # wykonać bezpiecznie również przy PONOWNEJ akceptacji po edycji).
    if (approve and isinstance(product.requested_store_ids, list)
            and product.submitted_price is not None
            and product.submitted_price > 0):
        from app.models.product import StoreProduct
        from app.models.store import Store

        for store_id_str in product.requested_store_ids:
            try:
                store_id = uuid.UUID(str(store_id_str))
            except (ValueError, TypeError):
                continue

            try:
                async with db.begin_nested():
                    store = await db.get(Store, store_id)
                    if store is None:
                        continue
                    existing = await db.execute(
                        select(StoreProduct).where(
                            StoreProduct.store_id == store_id,
                            StoreProduct.product_id == product.id,
                        )
                    )
                    if existing.scalar_one_or_none() is not None:
                        continue
                    db.add(StoreProduct(
                        store_id=store_id,
                        product_id=product.id,
                        price=product.submitted_price,
                    ))
                    await db.flush()
            except Exception as exc:
                logger.warning(
                    "Nie dodano produktu %s do sklepu %s: %s",
                    product.id, store_id, exc,
                )

        try:
            await db.commit()
        except Exception as exc:
            await db.rollback()
            logger.warning(
                "Produkt %s zaakceptowany, ale nie zapisano przypisań sklepów: %s",
                product.id, exc,
            )

    if product.created_by_user_id:
        from app.models.notification import Notification

        n = Notification(
            user_id=product.created_by_user_id,
            notification_type="product_reviewed",
            message=(
                f'Twój produkt "{product.name}" został '
                + ("dodany do katalogu." if approve else "odrzucony.")
            ),
        )
        db.add(n)
        try:
            await db.commit()
            from app.services.push import is_push_enabled, push_for_notification

            if is_push_enabled():
                await push_for_notification(db, n)
        except Exception as exc:
            await db.rollback()
            logger.warning(
                "Produkt %s oceniony, ale powiadomienie nie zostało wysłane: %s",
                product_id, exc,
            )
