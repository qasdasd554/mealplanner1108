"""Publish approved German price reports with their actual purchase units."""

from decimal import Decimal
from uuid import UUID

from sqlalchemy import select

from app.models import Store, StoreProduct
from app.services.uk_catalogue_import import canonical_base_unit


def _reported_pack(product):
    if product.serving_quantity is None:
        return (Decimal(1), "szt") if product.unit == "szt" else None
    try:
        amount = Decimal(str(product.serving_quantity))
        if amount.is_finite() and 0 < amount <= 100_000 and amount == amount.quantize(Decimal("0.001")):
            return amount, canonical_base_unit(product)
    except (ArithmeticError, ValueError):
        return None
    return None


async def sync_german_submission_prices(db, product) -> None:
    """Reconcile reports in the transaction that edits or moderates the product."""
    if product.created_by_user_id is None:
        return
    german_stores = select(Store.id).where(Store.country_code == "DE", Store.currency_code == "EUR")
    offers = (await db.scalars(select(StoreProduct).where(
        StoreProduct.product_id == product.id,
        StoreProduct.store_id.in_(german_stores),
    ))).all()
    price = product.submitted_price
    pack = _reported_pack(product)
    requested = set()
    store_ids = product.requested_store_ids
    if product.review_status == "approved" and price is not None and price > 0 and pack and isinstance(store_ids, list):
        for value in store_ids:
            try:
                requested.add(UUID(str(value)))
            except (ValueError, TypeError):
                continue
    valid_stores = set(await db.scalars(german_stores.where(Store.id.in_(requested)))) if requested else set()
    for offer in offers:
        active = offer.store_id in valid_stores
        valid_stores.discard(offer.store_id)
        # Preserve independent retailer observations and historical list links.
        if offer.last_verified is not None:
            continue
        offer.is_available = active
        if active:
            offer.price = price
            offer.package_quantity, offer.package_unit = pack
            offer.withdrawn_at = None

    for store_id in valid_stores:
        db.add(StoreProduct(
            store_id=store_id, product_id=product.id, price=price,
            package_quantity=pack[0], package_unit=pack[1],
        ))
