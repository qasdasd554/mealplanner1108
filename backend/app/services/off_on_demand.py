"""Best-effort UK facts refresh for one used GTIN, after the scan response.

No crawl, fuzzy identity review, nutrition overwrite or price/admin import.
Per-process limits are deliberately conservative; they are not a distributed
rate-limit guarantee across multiple Render instances.
"""

import asyncio
from collections import OrderedDict, deque
from datetime import datetime, timedelta, timezone
import json
import logging
import time

import httpx
from sqlalchemy import and_, exists, func, or_, select

from app.models import OffIngredientMapping, Product, Recipe, RecipeIngredient
from app.models.off_catalogue_product import OffCatalogueProduct
from app.services.barcode_lookup import (
    OFF_API_URLS, USER_AGENT, barcode_variants, normalize_barcode, _product_from_off_response,
)
from app.services.off_catalogue import catalogue_values, import_off_catalogue


logger = logging.getLogger(__name__)
_active: set[str] = set()
_attempts: OrderedDict[str, float] = OrderedDict()
_window: deque[float] = deque()
_backoff_until = 0.0
_catalogue_next_check = 0.0
_catalogue_refresh_running = False
_client_factory = httpx.AsyncClient
_FIELDS = (
    "code,product_name_en,product_name,product_name_pl,generic_name_en,generic_name,"
    "brands,nutriments,nutrition_data_per,quantity,product_quantity,product_quantity_unit,"
    "serving_quantity,serving_quantity_unit,countries_tags,stores,last_modified_t,obsolete"
)


def _session_factory():
    from app.db.session import async_session_factory
    return async_session_factory()


def _utc(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _public_recipe_refresh_query(*, now: datetime, excluded_keys=()):
    """Only existing, attributable facts actually used in public recipes.

    No new identity discovery. A stale fact may be refreshed, but a changed
    generic mapping cannot be silently reapproved by this path.
    """
    used = exists(select(1).select_from(RecipeIngredient).join(Recipe,
        Recipe.id == RecipeIngredient.recipe_id).where(
            RecipeIngredient.product_id == Product.id,
            RecipeIngredient.is_optional.is_(False), Recipe.is_active.is_(True),
            or_(Recipe.created_by_user_id.is_(None), Recipe.visibility == "public"),
        ).correlate(Product))
    mapped = exists(select(1).select_from(OffIngredientMapping).where(
        OffIngredientMapping.product_id == Product.id,
        OffIngredientMapping.off_barcode == OffCatalogueProduct.barcode,
        OffIngredientMapping.country_code == "GB",
        OffIngredientMapping.product_name == Product.name,
        OffIngredientMapping.product_brand.is_not_distinct_from(Product.brand),
        OffIngredientMapping.product_unit == Product.unit,
        OffIngredientMapping.base_unit == OffCatalogueProduct.base_unit,
        OffIngredientMapping.off_fingerprint == OffCatalogueProduct.fingerprint,
        OffIngredientMapping.reviewed_at <= now,
    ).correlate(Product, OffCatalogueProduct))
    eligible = exists(select(1).select_from(Product).where(
        Product.review_status == "approved", used,
        or_(Product.barcode == OffCatalogueProduct.barcode,
            and_(Product.barcode.is_(None), Product.created_by_user_id.is_(None), mapped)),
    ).correlate(OffCatalogueProduct))
    return select(OffCatalogueProduct.barcode).where(
        OffCatalogueProduct.country_code == "GB",
        OffCatalogueProduct.licence == "ODbL-1.0",
        OffCatalogueProduct.source_url == "https://world.openfoodfacts.org/product/" + OffCatalogueProduct.barcode,
        OffCatalogueProduct.retrieved_at < now - timedelta(days=7),
        func.length(OffCatalogueProduct.fingerprint) == 64,
        # At most 256 keys, also safe under the older SQLite parameter limit.
        # Strip padding exactly as the shared in-flight GTIN key does, so a
        # failing EAN/UPC alias cannot monopolize the two available slots.
        func.ltrim(OffCatalogueProduct.barcode, "0").not_in(tuple(excluded_keys)),
        eligible,
    ).order_by(OffCatalogueProduct.retrieved_at, OffCatalogueProduct.barcode).limit(8)


async def refresh_public_recipe_evidence(*, now: datetime | None = None) -> str:
    """After a UK catalogue response, refresh at most two known used codes.

    One bounded local selection per process/minute; share scan HTTP budgets
    and cooldowns. No permanent worker, crawl, new mapping or open DB session
    during HTTP. The caller must already have released its read transaction.
    """
    global _catalogue_next_check, _catalogue_refresh_running
    tick = time.monotonic()
    if _catalogue_refresh_running or tick < _catalogue_next_check or len(_active) >= 2:
        return "busy"
    while _window and tick - _window[0] >= 60:
        _window.popleft()
    if tick < _backoff_until or len(_window) >= 6:
        return "backoff"
    _catalogue_refresh_running = True
    _catalogue_next_check = tick + 60
    try:
        async with asyncio.timeout(13):
            clock = now or datetime.now(timezone.utc)
            if clock.tzinfo is None or clock.utcoffset() != timedelta(0):
                raise ValueError("An aware UTC refresh time is required")
            excluded = {key.lstrip("0") for key in _active}
            excluded.update(key.lstrip("0") for key, stamp in _attempts.items() if tick - stamp < 300)
            async with _session_factory() as session:
                rows = (await session.execute(_public_recipe_refresh_query(
                    now=clock, excluded_keys=sorted(excluded)))).scalars().all()
                codes = tuple(code for code in rows if normalize_barcode(code) == code)[:2]
            # Selection has closed its session before either exact-code fetch.
            for code in codes:
                await refresh_requested_off_product(code, now=clock)
            return "checked" if codes else "fresh"
    except Exception as error:
        logger.warning("UK recipe OFF refresh skipped (%s)", type(error).__name__)
        return "unavailable"
    finally:
        _catalogue_refresh_running = False


async def refresh_requested_off_product(barcode: str, *, now: datetime | None = None) -> str:
    """Bounded best-effort work; its result never replaces the scan response.

    Fresh evidence makes no HTTP request. Duplicate/busy jobs skip rather than
    queue. No DB transaction/connection is held during the external request.
    A failed/mismatched/non-UK response never renews old country evidence.
    """
    global _backoff_until
    code = normalize_barcode(barcode)
    if code is None:
        return "invalid"
    key = code.zfill(14)  # UPC/EAN/GTIN aliases share one in-flight/cooldown key.
    tick = time.monotonic()
    if key in _active or tick - _attempts.get(key, -1e12) < 300:
        return "cooldown"
    if tick < _backoff_until:
        return "backoff"
    if len(_active) >= 2:
        return "busy"
    _active.add(key)
    _attempts[key] = tick
    while len(_attempts) > 256:
        _attempts.popitem(last=False)
    try:
        async with asyncio.timeout(6):
            clock = now or datetime.now(timezone.utc)
            if clock.tzinfo is None or clock.utcoffset() != timedelta(0):
                raise ValueError("An aware UTC refresh time is required")
            aliases = barcode_variants(code)
            async with _session_factory() as session:
                records = (await session.execute(select(OffCatalogueProduct).where(
                    OffCatalogueProduct.barcode.in_(aliases),
                    OffCatalogueProduct.country_code == "GB",
                    OffCatalogueProduct.licence == "ODbL-1.0",
                    OffCatalogueProduct.source_url == "https://world.openfoodfacts.org/product/" + OffCatalogueProduct.barcode,
                ))).scalars().all()
                if any(clock - timedelta(days=7) <= _utc(row.retrieved_at) <= clock for row in records):
                    return "fresh"
            # Reserve only actual network work; foreground lookups have priority.
            tick = time.monotonic()
            while _window and tick - _window[0] >= 60:
                _window.popleft()
            if len(_window) >= 6 or tick < _backoff_until:
                return "backoff"
            _window.append(tick)
            version, template = OFF_API_URLS[0]
            async with _client_factory(timeout=4, follow_redirects=False,
                headers={"User-Agent": USER_AGENT, "Accept": "application/json"}) as client:
                async with client.stream("GET", template.format(barcode=code),
                    params={"cc": "uk", "lc": "en", "fields": _FIELDS}) as response:
                    if response.status_code in (429, 503):
                        _backoff_until = time.monotonic() + 300
                    response.raise_for_status()
                    payload = bytearray()
                    async for chunk in response.aiter_bytes(chunk_size=65_536):
                        payload.extend(chunk)
                        if len(payload) > 1_000_000:
                            raise ValueError("OFF response exceeded the bounded product projection")
            raw = _product_from_off_response(json.loads(payload), version)
            if (not isinstance(raw, dict) or raw.get("code") not in aliases
                    or catalogue_values(raw, retrieved_at=clock) is None):
                return "unavailable"
            async with _session_factory() as session:
                await import_off_catalogue(session, [raw], retrieved_at=clock)
                await session.commit()
            return "checked"  # A racing newer revision may legitimately win the upsert.
    except Exception as error:
        # No DSN, private rows, raw provider body or query values in this log.
        logger.warning("UK OFF background refresh skipped (%s)", type(error).__name__)
        return "unavailable"
    finally:
        _active.discard(key)
