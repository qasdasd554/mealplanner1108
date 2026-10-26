"""Endpointy produktów i zamienników."""

import hashlib
import logging
import math
import re
import unicodedata
import uuid
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_admin, get_current_user
from app.core.exceptions import NotFoundException
from app.core.language import account_text
from app.core.markets import account_country, MarketCode
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
    ProductNameSuggestion,
    ProductSubmissionResponse,
    StoreProductResponse,
    SubstituteResponse,
)
from app.services import ProductSubstitutionService
from app.services.store_market_access import get_store_in_account_market
from app.services.barcode_lookup import (
    BarcodeLookupResult,
    EXPLICIT_NUTRITION_SOURCES,
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


def _external_lookup_context(user: object) -> dict[str, str]:
    """Only the persisted account market controls external lookup language."""
    return {"country_code": "GB"} if account_country(user) == "GB" else {}


def _product_for_account(product, user):
    from app.services.product_market_presentation import product_for_market
    return product_for_market(product, country_code=account_country(user))


def _gb_catalogue_product_filter(user):
    """Same country evidence in catalogue and name suggestions; no new I/O."""
    from app.services.off_availability import product_has_off_uk_evidence
    from app.services.market_catalog import utc_market_date
    from app.services.system_content_language import generic_system_ingredient_condition
    return or_(Product.created_by_user_id == user.id,
        Product.submitted_country_code == "GB",
        generic_system_ingredient_condition(Product),
        product_has_off_uk_evidence(Product.id, as_of=utc_market_date()))


def _without_legacy_prices(response, user: object):
    """These old ranges are PLN estimates, never a reviewed UK offer."""
    if account_country(user) == "GB":
        response.price_min = None
        response.price_max = None
    return response


async def _validate_submission_stores(db, store_ids, user) -> None:
    """Submitted store IDs cannot turn a PL price into GBP availability."""
    for store_id in dict.fromkeys(store_ids):
        if await get_store_in_account_market(db, store_id, user) is None:
            raise HTTPException(
                status_code=400,
                detail=account_text(user, "Wybierz sklep dostępny w kraju przypisanym do konta.",
                    "Choose a shop available in your account's country."),
            )


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
    return all(
        value is not None and math.isfinite(value) and value >= 0 for value in values
    ) and (response.source in EXPLICIT_NUTRITION_SOURCES or any(value > 0 for value in values))


def _merge_local_barcode_response(
    local: BarcodeLookupResponse,
    external: BarcodeLookupResult,
    *,
    include_package: bool = True,
) -> BarcodeLookupResponse:
    """Zachowuje zweryfikowaną nazwę lokalną, ale wymienia stare 0/0/0/0."""
    local_nutrition = (
        local.kcal_per_100,
        local.protein_per_100,
        local.fat_per_100,
        local.carbs_per_100,
    )
    placeholders = not _response_has_complete_nutrition(local) and all(value == 0 for value in local_nutrition)

    def nutrition(
        local_value: float | None,
        external_value: float | None,
    ) -> float | None:
        if placeholders:
            return external_value
        return local_value if local_value is not None else external_value

    def physical_package(unit, quantity) -> bool:
        return (
            unit in {"g", "ml"} and quantity is not None
            and math.isfinite(quantity) and 0 < quantity <= 100_000
        )

    take_external_package = (
        include_package
        and not physical_package(local.unit, local.serving_quantity)
        and physical_package(external.unit, external.serving_quantity)
    )

    return BarcodeLookupResponse(
        found=True,
        source=f"{local.source}_enriched" if local.source else external.source,
        name=local.name or external.name,
        brand=local.brand or external.brand,
        unit=external.unit if take_external_package else local.unit or external.unit,
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
            external.serving_quantity if take_external_package else local.serving_quantity
        ),
    )


class RecipeIngredientProductCreate(BaseModel):
    """Wybrany wynik wyszukiwania po nazwie użyty w prywatnym przepisie."""

    model_config = ConfigDict(str_strip_whitespace=True)

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
    if any(value is None for value in values):
        return False
    try:
        return any(float(value) > 0 for value in values)
    except (TypeError, ValueError):
        return False


def _require_complete_recipe_nutrition(nutrition: dict | None, *, country_code: str = "PL") -> None:
    """Nie pozwala utrwalić składnika, którego nie da się poprawnie policzyć."""
    if _nutrition_values_are_complete(nutrition):
        return
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        detail=("Complete nutrition information was not found. Add the label values before using this product in a recipe."
            if country_code == "GB" else
            "Nie odnaleziono pełnych wartości odżywczych produktu. "
            "Uzupełnij dane z etykiety przed dodaniem go do przepisu."
        ),
    )


async def _enrich_recipe_ingredient_product(
    product: Product,
    payload: RecipeIngredientProductCreate,
    db: AsyncSession,
    user_id: UUID,
    *,
    country_code: str = "PL",
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
    owns_product = product.created_by_user_id == user_id
    if (
        owns_product
        and
        not _nutrition_values_are_complete(product.nutrition_per_100)
        and _nutrition_values_are_complete(incoming)
    ):
        product.nutrition_per_100 = incoming
        changed = True
    if owns_product and product.serving_quantity is None and payload.serving_quantity is not None:
        product.serving_quantity = payload.serving_quantity
        changed = True
    # A client's barcode for a shared product is not a trusted identity.
    barcode = product.barcode or (payload.barcode if owns_product else None)
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
        context = {"country_code": "GB"} if country_code == "GB" else {}
        external = await lookup_barcode_external(barcode, **context) if barcode else None
        if external is None or not has_complete_nutrition(external):
            by_name = await find_nutrition_by_name(product.name, product.brand, barcode=barcode, **context)
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

    _require_complete_recipe_nutrition(product.nutrition_per_100, country_code=country_code)

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


def _off_snapshot_time(value: str | None):
    """Use the original fetch clock, not time spent in memory/background queues."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    if value is None:
        return now  # Legacy direct callers that pass an immediately fetched record.
    moment = datetime.fromisoformat(value)
    if moment.tzinfo is None or moment > now:
        raise ValueError("OFF snapshot time must be aware and not future-dated")
    return moment.astimezone(timezone.utc)


async def _persist_barcode_cache_in_background(
    off_product: dict | None = None, off_retrieved_at: str | None = None, **values,
) -> None:
    """Zapisuje trafienie po wysłaniu odpowiedzi do telefonu.

    Użytkownik dostaje wynik z OFF/USDA bez czekania na dodatkowy zapis
    w Neon. Następny skan korzysta już z lokalnego cache.
    """
    from app.db.session import async_session_factory

    try:
        async with async_session_factory() as session:
            await _upsert_barcode_cache(session, **values)
            # Country availability is a separate OFF fact, not retailer stock.
            # Save only the product actually requested, after sending the result.
            if isinstance(off_product, dict):
                from app.services.barcode_lookup import barcode_variants
                from app.services.off_catalogue import import_off_catalogue

                if off_product.get("code") in barcode_variants(values["barcode"]):
                    await import_off_catalogue(
                        session, [off_product], retrieved_at=_off_snapshot_time(off_retrieved_at),
                    )
                    await session.commit()
    except Exception:
        logger.exception("Nie udało się zapisać produktu w cache kodów kreskowych")


async def _finish_cached_barcode(response, user, db, background_tasks, barcode, *, release_read_transaction=True):
    result = _without_legacy_prices(response, user)
    if account_country(user) == "GB":
        from app.services.off_on_demand import refresh_requested_off_product
        # Only SELECTs occurred in either early cache path. Auth activity writes
        # have already committed. Materialize the response before rollback:
        # it expires ORM objects, which must not be accessed implicitly later.
        # FastAPI's request-scoped dependency otherwise keeps its connection
        # checked out until AFTER BackgroundTasks, including external HTTP.
        if release_read_transaction:
            await db.rollback()
        background_tasks.add_task(refresh_requested_off_product, barcode)
    return result


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
    if account_country(current_user) == "GB":
        query = query.where(_gb_catalogue_product_filter(current_user))

    normalized_search = search.strip() if search else ""
    if normalized_search:
        pattern = f"%{normalized_search}%"
        matches = [Product.name.ilike(pattern), Product.brand.ilike(pattern)]
        if account_country(current_user) == "GB":
            from app.services.system_content_language import english_system_name_match
            matches.append(english_system_name_match(Product, normalized_search, kind="ingredients"))
        query = query.where(or_(*matches))

    display_name = Product.name
    if account_country(current_user) == "GB":
        from app.services.system_content_language import english_system_name_order
        display_name = english_system_name_order(Product, kind="ingredients")
    query = query.order_by(display_name)
    if account_country(current_user) == "GB":
        query = query.order_by(Product.id)
    query = query.offset(skip).limit(limit)

    result = await db.execute(query)
    return [_product_for_account(product, current_user) for product in result.scalars().all()]


@router.get(
    "/barcode/{barcode}",
    response_model=BarcodeLookupResponse,
    summary="Wyszukaj produkt po kodzie kreskowym",
)
async def lookup_barcode_endpoint(
    barcode: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BarcodeLookupResponse:
    return await lookup_barcode(barcode, background_tasks, db, current_user)


async def lookup_barcode(
    barcode: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    *,
    release_read_transaction: bool = True,
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
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nieprawidłowy kod EAN/UPC", "Invalid EAN/UPC barcode."))

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
            # serving_quantity jest jedyną wiarygodną masą całego
            # opakowania. default_quantity może być tylko porcją startową.
            serving_quantity=existing.serving_quantity,
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
            if local_response.serving_quantity is None:
                local_response.serving_quantity = cached.serving_quantity
            # Jednostka opisuje podstawę masy opakowania, podczas gdy sam
            # zapis do katalogu/spiżarni pozostaje zawsze „1 opakowanie”.
            local_response.unit = cached.unit
        if local_response.serving_quantity is not None:
            return await _finish_cached_barcode(local_response, current_user, db, background_tasks, normalized_barcode,
                                                release_read_transaction=release_read_transaction)
        # Nazwa i makro są już lokalne, ale brak gramatury opakowania.
        # Jedno zapytanie do źródła zewnętrznego może ją zweryfikować;
        # jeśli jej tam nie ma, wynik nadal wróci bez opcji „opakowanie”.

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
                source=(
                    cached.source
                    if cached.source in EXPLICIT_NUTRITION_SOURCES
                    and all(nutrition.get(key) == 0 for key in ("kcal", "protein", "fat", "carbs"))
                    else "neon_cache"
                ),
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
                return await _finish_cached_barcode(local_response, current_user, db, background_tasks, normalized_barcode,
                                                    release_read_transaction=release_read_transaction)

    # 3. Open Food Facts v3 oraz USDA FoodData Central. UPCitemdb zostało
    # usunięte z aktywnej ścieżki: często zwracało 429 i nie zawiera makro.
    context = _external_lookup_context(current_user)
    external = await lookup_barcode_external(normalized_barcode, **context)
    if external is not None:
        if not has_complete_nutrition(external):
            internet_nutrition = await find_nutrition_by_name(
                external.name,
                external.brand,
                barcode=normalized_barcode,
                **context,
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
            if release_read_transaction:
                await db.commit()
            else:
                await db.flush()
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
            **({"off_product": external.off_product,
                "off_retrieved_at": external.off_retrieved_at} if account_country(current_user) == "GB" else {}),
        )
        return _without_legacy_prices(response, current_user)

    if local_response is not None:
        internet_nutrition = await find_nutrition_by_name(
            local_response.name or "",
            local_response.brand,
            barcode=normalized_barcode,
            **context,
        )
        if internet_nutrition is not None:
            local_response = _merge_local_barcode_response(
                local_response,
                internet_nutrition,
                include_package=False,
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
                if release_read_transaction:
                    await db.commit()
                else:
                    await db.flush()
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
                **({"off_product": internet_nutrition.off_product} if account_country(current_user) == "GB" else {}),
            )
        return _without_legacy_prices(local_response, current_user)

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
    model_config = ConfigDict(str_strip_whitespace=True)

    barcode: str = Field(..., min_length=8, max_length=50)
    name: str = Field(..., min_length=2, max_length=300)
    brand: str | None = Field(None, max_length=200)
    unit: str = Field("g", pattern="^(g|ml)$")
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
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nieprawidłowy kod EAN/UPC", "Invalid EAN/UPC barcode."))
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
            **_external_lookup_context(current_user),
        )
    except ProductLabelRecognitionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    price_min, price_max = price_range_for_product(result["name"])
    result["price_min"] = price_min
    result["price_max"] = price_max
    return _without_legacy_prices(BarcodeLookupResponse(**result), current_user)


@router.post(
    "/barcode/confirm-label",
    response_model=BarcodeLookupResponse,
    summary="Potwierdź dane etykiety i zapisz produkt w Neon",
)
async def confirm_product_label(
    payload: ProductLabelConfirmation,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BarcodeLookupResponse:
    """Dopiero świadome potwierdzenie użytkownika zasila wspólny cache."""
    from app.services.barcode_lookup import normalize_barcode

    barcode = normalize_barcode(payload.barcode)
    if barcode is None:
        raise HTTPException(status_code=400, detail=account_text(current_user,
            "Nieprawidłowy kod EAN/UPC", "Invalid EAN/UPC barcode."))
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
    return _without_legacy_prices(BarcodeLookupResponse(
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
    ), current_user)


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
            "unit": (
                "opak"
                if entry.serving_quantity is not None
                else (entry.unit if entry.unit in {"g", "ml"} else "g")
            ),
            "default_quantity": 1 if entry.serving_quantity is not None else 100,
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
    background_tasks: BackgroundTasks = None,
) -> list[ProductNameSuggestion]:
    """Zwraca podpowiedzi bez odbierania możliwości ręcznego wpisania.

    Kolejność źródeł jest celowa: własny katalog, zapamiętane skany w Neon,
    a dopiero potem Open Food Facts — ta sama zewnętrzna baza, z której
    korzysta skanowanie kodów kreskowych.
    """
    normalized = " ".join(query.strip().split())
    pattern = f"%{normalized}%"
    matches = [Product.name.ilike(pattern), Product.brand.ilike(pattern)]
    catalog_query = select(Product).where(_visible_product_filter(current_user.id))
    ordering = Product.name
    if account_country(current_user) == "GB":
        from app.services.system_content_language import english_system_name_match, english_system_name_order
        catalog_query = catalog_query.where(_gb_catalogue_product_filter(current_user))
        matches.append(english_system_name_match(Product, normalized, kind="ingredients"))
        ordering = english_system_name_order(Product, kind="ingredients")
    catalog_query = catalog_query.where(or_(*matches)).order_by(ordering)
    if account_country(current_user) == "GB":
        catalog_query = catalog_query.order_by(Product.id)
    catalog_result = await db.execute(catalog_query.limit(limit))
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
    suggestion_indexes: dict[tuple[str, str, str], int] = {}

    def suggestion_has_nutrition(suggestion: ProductNameSuggestion) -> bool:
        return _nutrition_values_are_complete({
            "kcal": suggestion.kcal_per_100,
            "protein": suggestion.protein_per_100,
            "fat": suggestion.fat_per_100,
            "carbs": suggestion.carbs_per_100,
        })

    def add_suggestion(suggestion: ProductNameSuggestion) -> None:
        suggestion = _without_legacy_prices(suggestion, current_user)
        # Equal names/brands can still be different flavours or pack sizes.
        # Merge catalog/cache fields only when the GTIN identity also agrees.
        key = (
            suggestion.name.casefold(), (suggestion.brand or "").casefold(),
            suggestion.barcode.zfill(14) if suggestion.barcode else "",
        )
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
    from app.services.system_content_language import ingredient_display_name
    for product in catalog_result.scalars().all():
        nutrition = product.nutrition_per_100 or {}
        presented = _product_for_account(product, current_user)
        price_min, price_max = price_range_for_product(product.name)
        catalog_suggestions.append(ProductNameSuggestion(
            source="catalog",
            name=ingredient_display_name(product, country_code=account_country(current_user)),
            brand=presented.brand,
            unit=product.unit,
            barcode=product.barcode,
            existing_product_id=product.id,
            kcal_per_100=nutrition.get("kcal"),
            protein_per_100=nutrition.get("protein"),
            fat_per_100=nutrition.get("fat"),
            carbs_per_100=nutrition.get("carbs"),
            price_min=price_min,
            price_max=price_max,
            serving_quantity=presented.serving_quantity,
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

    if account_country(current_user) == "GB" and len(suggestions) < limit:
        from app.services.off_catalogue import search_off_catalogue

        for suggestion in await search_off_catalogue(
            db, normalized, country_code="GB", limit=limit - len(suggestions),
        ):
            add_suggestion(suggestion)

    if len(suggestions) < limit:
        from app.services.barcode_lookup import search_products_external

        external_results = await search_products_external(
            normalized,
            limit=limit - len(suggestions),
            **_external_lookup_context(current_user),
        )
        if account_country(current_user) == "GB" and background_tasks is not None:
            source_records = [value.off_product for value in external_results if getattr(value, "off_product", None)]
            if source_records:
                clocks = [value.off_retrieved_at for value in external_results
                    if getattr(value, "off_product", None) and getattr(value, "off_retrieved_at", None)]
                background_tasks.add_task(_persist_off_catalogue_in_background, source_records,
                    retrieved_at=min(clocks) if clocks else None)
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


async def _persist_off_catalogue_in_background(records: list[dict], *, retrieved_at: str | None = None) -> None:
    """OFF-only cache write after the HTTP response; no user or shop writes."""
    from app.db.session import async_session_factory
    from app.services.off_catalogue import import_off_catalogue

    try:
        async with async_session_factory() as session:
            await import_off_catalogue(session, records, retrieved_at=_off_snapshot_time(retrieved_at))
            await session.commit()
    except Exception:
        logger.warning("OFF catalogue cache write failed; the live result was retained")


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
            raise HTTPException(status_code=404, detail=account_text(current_user,
                "Nie znaleziono produktu", "Product not found."))
        return await _enrich_recipe_ingredient_product(existing, payload, db, current_user.id, country_code=account_country(current_user))

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
            return await _enrich_recipe_ingredient_product(existing, payload, db, current_user.id, country_code=account_country(current_user))
    result = await db.execute(select(Product).where(
        Product.created_by_user_id == current_user.id,
        Product.review_status == "private",
        Product.name == name,
        Product.brand == brand,
        Product.unit == unit,
    ).limit(1))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return await _enrich_recipe_ingredient_product(existing, payload, db, current_user.id, country_code=account_country(current_user))

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
    _require_complete_recipe_nutrition(nutrition, country_code=account_country(current_user))
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
    market: MarketCode | None = None,
) -> list[Product]:
    result = await db.execute(
        select(Product)
        .where(Product.review_status == "pending")
        .where(Product.submitted_country_code == market if market else True)
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
            detail=account_text(current_user,
                f"Produkt o ID {product_id} nie został znaleziony", f"Product {product_id} was not found.")
        )
    return _product_for_account(product, current_user)


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
    if store_id is not None:
        if await get_store_in_account_market(db, store_id, current_user) is None:
            raise NotFoundException(detail=account_text(current_user, "Sklep nie został znaleziony", "Shop not found."))
    # Sprawdź czy produkt istnieje
    product_result = await db.execute(
        select(Product).where(
            Product.id == product_id,
            _visible_product_filter(current_user.id),
        )
    )
    if product_result.scalar_one_or_none() is None:
        raise NotFoundException(
            detail=account_text(current_user,
                f"Produkt o ID {product_id} nie został znaleziony", f"Product {product_id} was not found.")
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
                "currency_code": "GBP" if account_country(current_user) == "GB" else "PLN",
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
    from app.services.product_market_presentation import product_brand_for_market
    for r in results:
        prod = r["product"]
        if not (
            prod.review_status == "approved"
            or prod.created_by_user_id == current_user.id
        ):
            continue
        store_prod = r.get("store_product")
        regional_quote = r.get("regional_quote") if account_country(current_user) == "GB" else None
        if account_country(current_user) == "GB":
            # A legacy StoreProduct is not a reviewed British price/pack.
            if (regional_quote is None or regional_quote.store_id != store_id
                    or regional_quote.product_id != prod.id
                    or regional_quote.currency_code != "GBP"):
                continue
        kcal = None
        if prod.nutrition_per_100 and "kcal" in prod.nutrition_per_100:
            try:
                kcal = int(prod.nutrition_per_100["kcal"])
            except:
                pass
        response_list.append({
            "id": prod.id,
            "name": regional_quote.name_en if regional_quote else prod.name,
            "brand": product_brand_for_market(prod, country_code=account_country(current_user)),
            "price": regional_quote.price_per_package if regional_quote else (store_prod.price if store_prod else None),
            "kcal": kcal,
            "similarity_score": r.get("similarity_score"),
            "currency_code": "GBP" if regional_quote else "PLN",
            "price_basis": "package",
            "package_quantity": regional_quote.package_quantity if regional_quote else None,
            "package_unit": regional_quote.unit if regional_quote else None,
            "price_is_estimated": regional_quote.price_is_estimated if regional_quote else getattr(store_prod, "last_verified", None) is None,
            "last_verified": regional_quote.last_verified if regional_quote else getattr(store_prod, "last_verified", None),
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

    model_config = ConfigDict(str_strip_whitespace=True)

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
    serving_unit: str | None = Field(None, pattern="^(g|ml)$")


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
    await _validate_submission_stores(db, payload.store_ids, current_user)

    normalized_barcode = None
    if payload.barcode:
        from app.services.barcode_lookup import normalize_barcode

        normalized_barcode = normalize_barcode(payload.barcode)
        if normalized_barcode is None:
            raise HTTPException(status_code=400, detail=account_text(current_user,
                "Nieprawidłowy kod EAN/UPC", "Invalid EAN/UPC barcode."))

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
            detail=account_text(current_user, "Ten produkt został już przez Ciebie dodany i nagrodzony.",
                "You have already added this product and received its reward."),
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
            "kcal": payload.kcal_per_100,
            "protein": payload.protein_per_100,
            "fat": payload.fat_per_100,
            "carbs": payload.carbs_per_100,
            "fiber": None,
        }

    from app.services.product_measures import build_measure_options

    requested_unit = payload.unit.strip() or "szt"
    # Sam kod kreskowy nie określa masy opakowania. Produkt staje się
    # „opakowaniem” dopiero po odczytaniu całkowitej masy/objętości netto.
    product_unit = (
        "opak"
        if normalized_barcode and payload.serving_quantity is not None
        else requested_unit if requested_unit != "opak" else payload.serving_unit or "g"
    )
    default_quantity = 1 if product_unit in {"opak", "szt", "kg", "l"} else 100
    product = Product(
        name=payload.name.strip(),
        brand=(payload.brand or "").strip() or None,
        unit=product_unit,
        default_quantity=Decimal(default_quantity),
        serving_quantity=payload.serving_quantity,
        measure_options=build_measure_options(
            payload.name,
            payload.serving_unit or product_unit,
            default_quantity,
            payload.serving_quantity,
        ),
        nutrition_per_100=nutrition,
        created_by_user_id=current_user.id,
        review_status="pending",
        submitted_price=payload.price,
        submitted_country_code=account_country(current_user),
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
            .execution_options(populate_existing=True)
        )
        if locked_user is None:
            raise HTTPException(status_code=401, detail=account_text(current_user, "Użytkownik nie istnieje", "User not found."))
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
            detail=account_text(current_user,
                "Produkt z tym kodem kreskowym został już zgłoszony przez kogoś "
                "innego albo ten produkt został już przez Ciebie nagrodzony.",
                "Someone has already submitted a product with this barcode, or you have already received a reward for this product.",
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
        english_message=f'{current_user.display_name or "A user"} submitted product "{product.name}" — approval required.',
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
        raise HTTPException(status_code=404, detail=account_text(current_user, "Nie znaleziono produktu", "Product not found."))
    if product.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail=account_text(current_user,
                "Możesz edytować tylko własne zgłoszenia.", "You can only edit your own submissions.")
        )

    await _validate_submission_stores(db, payload.store_ids, current_user)

    was_pending = product.review_status == "pending"
    previous_source = (getattr(product, "nutrition_per_100", None) or {}).get("_source", {})
    was_recipe_placeholder = (isinstance(previous_source, dict)
        and previous_source.get("provider") == "unresolved_recipe_ingredient")

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

    normalized_barcode = product.barcode
    if payload.barcode:
        from app.services.barcode_lookup import normalize_barcode

        normalized_barcode = normalize_barcode(payload.barcode)
        if normalized_barcode is None:
            raise HTTPException(status_code=400, detail=account_text(current_user,
                "Nieprawidłowy kod EAN/UPC", "Invalid EAN/UPC barcode."))

    from app.services.product_measures import build_measure_options

    if "serving_quantity" in payload.model_fields_set:
        product.serving_quantity = payload.serving_quantity
    requested_unit = payload.unit.strip() or "szt"
    product_unit = (
        "opak"
        if normalized_barcode and product.serving_quantity is not None
        else requested_unit if requested_unit != "opak" else payload.serving_unit or "g"
    )
    default_quantity = 1 if product_unit in {"opak", "szt", "kg", "l"} else 100

    product.name = payload.name.strip()
    product.brand = (payload.brand or "").strip() or None
    product.unit = product_unit
    product.default_quantity = Decimal(default_quantity)
    product.measure_options = build_measure_options(
        product.name, payload.serving_unit or product_unit,
        default_quantity, product.serving_quantity,
    )
    product.nutrition_per_100 = nutrition
    product.submitted_price = payload.price
    product.submitted_country_code = account_country(current_user)
    product.requested_store_ids = [str(sid) for sid in payload.store_ids] or None
    # Tylko gdy jawnie podane — formularz edycji nie zawsze wysyła kod
    # kreskowy (np. gdy edytujący nie skanował ponownie), więc pusta
    # wartość NIE MA kasować już zapisanego kodu.
    if payload.barcode:
        product.barcode = normalized_barcode
    # Patrz docstring — każda edycja wraca do kolejki moderacji.
    product.review_status = "pending"

    db.add(product)
    try:
        if was_recipe_placeholder:
            from app.services.recipe_ingredient_catalogue import refresh_incomplete_recipes_for_product
            await refresh_incomplete_recipes_for_product(db, product.id)
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail=account_text(current_user, "Ten kod kreskowy jest już przypisany do innego produktu.",
                "This barcode is already assigned to another product."),
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
            english_message=f'{current_user.display_name or "A user"} resubmitted product "{product.name}" after editing — approval required.',
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
        raise HTTPException(status_code=404, detail=account_text(current_user, "Nie znaleziono produktu", "Product not found."))
    if product.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail=account_text(current_user,
                "Możesz usunąć tylko własne zgłoszenia.", "You can only delete your own submissions.")
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
        raise HTTPException(status_code=404, detail=account_text(current_user, "Nie znaleziono produktu", "Product not found."))

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
                    submitted_market = getattr(product, "submitted_country_code", None) or "PL"
                    if account_country(store) != submitted_market:
                        # Also protects older submissions containing forged IDs.
                        continue
                    if submitted_market == "GB":
                        from app.services.uk_submission_prices import import_submitted_price

                        await import_submitted_price(db, product, store_id, current_user.id)
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
        from app.services.notification_language import recipient_text

        try:
            n = Notification(
                user_id=product.created_by_user_id,
                notification_type="product_reviewed",
                message=await recipient_text(db, product.created_by_user_id,
                    f'Twój produkt "{product.name}" został '
                    + ("dodany do katalogu." if approve else "odrzucony."),
                    f'Your product "{product.name}" has been '
                    + ("added to the catalogue." if approve else "rejected."),
                ),
            )
            db.add(n)
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
