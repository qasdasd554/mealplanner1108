"""Moderation and exact-SKU price updates for official retailer leaflets."""

import asyncio
import hashlib
from dataclasses import dataclass
from decimal import Decimal
from typing import Awaitable, Callable

import httpx
from fastapi import HTTPException
from sqlalchemy import and_, func, select

from app.core.market_clock import market_today
from app.core.markets import MARKET_CURRENCIES
from app.models import Product, Store, StoreProduct
from app.models.promotion import Promotion
from app.services.de_leaflet_promotions import (
    ALDI_NORD_LEAFLET_URL,
    ALDI_SUED_LEAFLET_URL,
    fetch_aldi_nord_promotions,
    fetch_aldi_sued_promotions,
)
from app.services.retailer_leaflet import LeafletOffer
from app.services.system_content_language import ingredient_display_name
from app.services.uk_leaflet_promotions import LIDL_GB_HOME, fetch_lidl_gb_promotions


@dataclass(frozen=True)
class LeafletSource:
    name: str
    url: str
    fetch: Callable[[set[str]], Awaitable[list[LeafletOffer]]]


RETAILER_LEAFLETS = {
    ("DE", "ALDI Nord"): LeafletSource("aldi_nord_leaflet", ALDI_NORD_LEAFLET_URL, fetch_aldi_nord_promotions),
    ("DE", "ALDI SÜD"): LeafletSource("aldi_sued_leaflet", ALDI_SUED_LEAFLET_URL, fetch_aldi_sued_promotions),
    ("GB", "Lidl"): LeafletSource("lidl_gb_leaflet", LIDL_GB_HOME, fetch_lidl_gb_promotions),
}


async def scan_retailer_leaflet(store_name, db, *, country: str) -> dict:
    source = RETAILER_LEAFLETS[country, store_name]
    store_id = await db.scalar(select(Store.id).where(
        Store.name == store_name, Store.country_code == country, Store.currency_code == MARKET_CURRENCIES[country],
    ))
    if store_id is None:
        raise HTTPException(404, "Der Supermarkt wurde nicht gefunden." if country == "DE" else "Shop not found.")
    skus = set(await db.scalars(select(StoreProduct.retailer_sku).where(
        StoreProduct.store_id == store_id, StoreProduct.retailer_sku.is_not(None),
    )))
    await db.commit()
    try:
        async with asyncio.timeout(35):
            offers = await source.fetch(skus)
    except (ValueError, TimeoutError, httpx.HTTPError) as exc:
        message = ("Der aktuelle Prospekt konnte nicht gelesen werden." if country == "DE"
                   else "The shop's current leaflet could not be read.")
        raise HTTPException(502, message) from exc

    # The worker and the legacy synchronous route share this deduplication lock.
    lock_key = int.from_bytes(
        hashlib.sha256(f"{country.lower()}-leaflet:{store_id}".encode()).digest()[:8], "big", signed=True,
    )
    await db.execute(select(func.pg_advisory_xact_lock(lock_key)))
    existing = (await db.scalars(select(Promotion).where(
        Promotion.country_code == country, Promotion.store_name == store_name,
        Promotion.review_status.in_(("pending", "approved")),
        Promotion.valid_until >= market_today(country),
    ))).all()
    keys = {((row.promo_details or {}).get("leaflet_sku"), row.valid_from, row.valid_until,
             row.regular_price, row.promo_price) for row in existing}
    products = (await db.execute(select(StoreProduct, Product).join(
        Product, Product.id == StoreProduct.product_id,
    ).where(
        StoreProduct.store_id == store_id,
        StoreProduct.retailer_sku.in_(skus),
        StoreProduct.is_available.is_(True), StoreProduct.withdrawn_at.is_(None),
        StoreProduct.last_verified.is_not(None), Product.review_status == "approved",
    ))).all() if skus else []
    by_sku = {}
    for row, product in products:
        sku = row.retailer_sku
        by_sku[sku] = None if sku in by_sku else (row, product)
    queued = 0
    for offer in offers:
        key = (offer.sku, offer.start, offer.end, offer.regular, offer.discount)
        if key in keys:
            continue
        match = by_sku.get(offer.catalogue_sku)
        attached = None
        display_name = offer.name
        if match:
            item, product = match
            if (item.package_quantity, item.package_unit, item.store_brand_name) == (offer.quantity, offer.unit, offer.brand):
                attached = item.id
                display_name = ingredient_display_name(product, country_code=country)
        pack = "je kg" if offer.pack == "kg-Preis" else offer.pack
        db.add(Promotion(
            country_code=country, store_name=store_name, product_name=display_name,
            store_product_id=attached, regular_price=offer.regular, promo_price=offer.discount,
            promo_description=f"{offer.name} · {pack} · {store_name}",
            promo_details={
                "leaflet_sku": offer.sku, "catalogue_sku": offer.catalogue_sku,
                "source_url": offer.source_url or source.url, "package_quantity": str(offer.quantity),
                "package_unit": offer.unit, "brand": offer.brand,
            },
            source=source.name, promo_type="price_cut",
            valid_from=offer.start, valid_until=offer.end,
            review_status="pending", is_active=True,
        ))
        queued += 1
        keys.add(key)
    await db.commit()
    return {"store_name": store_name, "found": len(offers), "queued_for_review": queued,
            "skipped_duplicates": len(offers) - queued}


def _matches_retailer_pack(row, promotion) -> bool:
    details = promotion.promo_details or {}
    sku = details.get("catalogue_sku")
    try:
        quantity = Decimal(details["package_quantity"])
    except (KeyError, TypeError, ArithmeticError, ValueError):
        return False
    return bool(sku and row.retailer_sku == sku and quantity.is_finite()
                and row.package_quantity == quantity and row.package_unit == details.get("package_unit")
                and (row.store_brand_name or "") == details.get("brand"))


def _still_has_applied_price(row, promotion) -> bool:
    return (_matches_retailer_pack(row, promotion) and row.price == promotion.promo_price
            and row.last_verified is not None
            and row.last_verified.isoformat() == (promotion.promo_details or {}).get("price_verified_at"))


async def german_retailer_prices(db, offers) -> dict:
    """Use the regular price after local midnight, including before cleanup runs."""
    ids = {row.id for row in offers if row.retailer_sku and row.last_verified}
    if not ids:
        return {}

    # Read the current catalogue price and expiry marker in the same snapshot.
    # Cleanup can commit between the caller's catalogue query and this one.
    current = await db.execute(select(
        StoreProduct.id, StoreProduct.price, StoreProduct.retailer_sku, StoreProduct.package_quantity,
        StoreProduct.package_unit, StoreProduct.store_brand_name, StoreProduct.last_verified,
        Store.name.label("store_name"), Promotion,
    ).join(
        Store, Store.id == StoreProduct.store_id,
    ).outerjoin(Promotion, and_(
        Promotion.store_product_id == StoreProduct.id, Promotion.country_code == "DE",
        Promotion.store_name == Store.name, Promotion.price_applied.is_(True),
        Promotion.valid_until < market_today("DE"),
    )).where(
        StoreProduct.id.in_(ids), Store.country_code == "DE", Store.currency_code == "EUR",
    ).order_by(Promotion.valid_until.desc(), Promotion.created_at.desc(), Promotion.id.desc()))
    prices = {}
    restored = set()
    for row in current:
        prices.setdefault(row.id, row.price)
        promotion = row[-1]
        leaflet = RETAILER_LEAFLETS.get(("DE", row.store_name))
        if (row.id not in restored and promotion is not None and leaflet is not None
                and promotion.source == leaflet.name and _still_has_applied_price(row, promotion)):
            prices[row.id] = promotion.regular_price
            restored.add(row.id)
    return prices


async def _exact_retailer_offer(db, promotion):
    country = promotion.country_code
    leaflet = RETAILER_LEAFLETS.get((country, promotion.store_name))
    if promotion.store_product_id is None or leaflet is None or promotion.source != leaflet.name:
        return None
    row = await db.scalar(select(StoreProduct).join(Store).where(
        StoreProduct.id == promotion.store_product_id,
        Store.name == promotion.store_name, Store.country_code == country, Store.currency_code == MARKET_CURRENCIES[country],
    ).with_for_update(of=StoreProduct))
    if row is None or not _matches_retailer_pack(row, promotion):
        return None
    return row


async def apply_retailer_promotion_price(db, promotion) -> None:
    if promotion.promo_type != "price_cut" or promotion.requires_loyalty_card:
        return
    row = await _exact_retailer_offer(db, promotion)
    if (row is not None and row.is_available and row.withdrawn_at is None and row.last_verified
            and row.price == promotion.regular_price and promotion.promo_price < row.price):
        row.price = promotion.promo_price
        promotion.promo_details = {**promotion.promo_details, "price_verified_at": row.last_verified.isoformat()}
        promotion.price_applied = True


async def restore_retailer_promotion_price(db, promotion) -> bool:
    row = await _exact_retailer_offer(db, promotion)
    if row is None or not _still_has_applied_price(row, promotion):
        return False
    row.price = promotion.regular_price
    return True
