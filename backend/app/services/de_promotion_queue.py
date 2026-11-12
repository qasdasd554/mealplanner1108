"""Moderation and exact-SKU price updates for the German leaflet."""

import hashlib
from decimal import Decimal

import httpx
from fastapi import HTTPException
from sqlalchemy import func, select

from app.core.market_clock import market_today
from app.models import Product, Store, StoreProduct
from app.models.promotion import Promotion
from app.services.de_leaflet_promotions import ALDI_NORD_LEAFLET_URL, fetch_aldi_nord_promotions
from app.services.system_content_language import ingredient_display_name


async def scan_de_leaflet(store_name, db) -> dict:
    store_id = await db.scalar(select(Store.id).where(
        Store.name == store_name, Store.country_code == "DE", Store.currency_code == "EUR",
    ))
    if store_id is None:
        raise HTTPException(404, "Der Supermarkt wurde nicht gefunden.")
    skus = set(await db.scalars(select(StoreProduct.retailer_sku).where(
        StoreProduct.store_id == store_id, StoreProduct.retailer_sku.is_not(None),
    )))
    await db.commit()
    try:
        offers = await fetch_aldi_nord_promotions(skus)
    except (ValueError, httpx.HTTPError) as exc:
        raise HTTPException(502, "Der aktuelle Prospekt konnte nicht gelesen werden.") from exc

    # The worker and the legacy synchronous route share this deduplication lock.
    lock_key = int.from_bytes(hashlib.sha256(f"de-leaflet:{store_id}".encode()).digest()[:8], "big", signed=True)
    await db.execute(select(func.pg_advisory_xact_lock(lock_key)))
    existing = (await db.scalars(select(Promotion).where(
        Promotion.country_code == "DE", Promotion.store_name == store_name,
        Promotion.review_status.in_(("pending", "approved")),
        Promotion.valid_until >= market_today("DE"),
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
    by_sku = {row.retailer_sku: (row, product) for row, product in products}
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
                display_name = ingredient_display_name(product, country_code="DE")
        pack = "je kg" if offer.pack == "kg-Preis" else offer.pack
        db.add(Promotion(
            country_code="DE", store_name=store_name, product_name=display_name,
            store_product_id=attached, regular_price=offer.regular, promo_price=offer.discount,
            promo_description=f"{offer.name} · {pack} · ALDI Nord",
            promo_details={
                "leaflet_sku": offer.sku, "catalogue_sku": offer.catalogue_sku,
                "source_url": ALDI_NORD_LEAFLET_URL, "package_quantity": str(offer.quantity),
                "package_unit": offer.unit, "brand": offer.brand,
            },
            source="aldi_nord_leaflet", promo_type="price_cut",
            valid_from=offer.start, valid_until=offer.end,
            review_status="pending", is_active=True,
        ))
        queued += 1
        keys.add(key)
    await db.commit()
    return {"store_name": store_name, "found": len(offers), "queued_for_review": queued,
            "skipped_duplicates": len(offers) - queued}


async def _exact_german_offer(db, promotion):
    if promotion.store_product_id is None or promotion.source != "aldi_nord_leaflet":
        return None
    details = promotion.promo_details or {}
    row = await db.scalar(select(StoreProduct).join(Store).where(
        StoreProduct.id == promotion.store_product_id,
        Store.name == promotion.store_name, Store.country_code == "DE", Store.currency_code == "EUR",
    ).with_for_update(of=StoreProduct))
    if (row is None or row.retailer_sku != details.get("catalogue_sku")
            or row.package_unit != details.get("package_unit") or row.store_brand_name != details.get("brand")
            or row.package_quantity != Decimal(details["package_quantity"])):
        return None
    return row


async def apply_de_promotion_price(db, promotion) -> None:
    if promotion.promo_type != "price_cut" or promotion.requires_loyalty_card:
        return
    row = await _exact_german_offer(db, promotion)
    if (row is not None and row.is_available and row.withdrawn_at is None and row.last_verified
            and row.price == promotion.regular_price and promotion.promo_price < row.price):
        row.price = promotion.promo_price
        promotion.promo_details = {**promotion.promo_details, "price_verified_at": row.last_verified.isoformat()}
        promotion.price_applied = True


async def restore_de_promotion_price(db, promotion) -> bool:
    row = await _exact_german_offer(db, promotion)
    if (row is None or row.price != promotion.promo_price or row.last_verified is None
            or row.last_verified.isoformat() != promotion.promo_details.get("price_verified_at")):
        return False
    row.price = promotion.regular_price
    return True
