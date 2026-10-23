"""OFF-reported UK sales, never inferred retailer stock, prices or nutrition.

An exact GTIN binds a canonical app product to public OFF facts. Similar names
or a country phone setting are not evidence. Generic ingredient mappings need
separate review; this module deliberately does not guess them.
"""

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import exists, func, select
from sqlalchemy.orm import aliased

from app.models.product import Product
from app.models.off_catalogue_product import OffCatalogueProduct


def off_uk_evidence_conditions(*, as_of: date):
    if type(as_of) is not date:
        raise ValueError("An explicit calendar date is required")
    return (
        OffCatalogueProduct.country_code == "GB",
        OffCatalogueProduct.licence == "ODbL-1.0",
        OffCatalogueProduct.retrieved_at >= datetime.combine(
            as_of - timedelta(days=30), time.min, timezone.utc),
        OffCatalogueProduct.retrieved_at < datetime.combine(
            as_of + timedelta(days=1), time.min, timezone.utc),
        OffCatalogueProduct.source_url ==
            "https://world.openfoodfacts.org/product/" + OffCatalogueProduct.barcode,
        func.length(func.trim(OffCatalogueProduct.name)) > 0,
        func.length(OffCatalogueProduct.fingerprint) == 64,
    )


def product_has_off_uk_evidence(product_id, *, as_of: date):
    candidate = aliased(Product)
    return exists(select(1).select_from(candidate).join(
        OffCatalogueProduct, OffCatalogueProduct.barcode == candidate.barcode,
    ).where(candidate.id == product_id, *off_uk_evidence_conditions(as_of=as_of)))


async def off_available_product_ids(db, product_ids, *, as_of: date):
    """One batched local query after recipe filtering; no external fan-out."""
    if not product_ids:
        return set()
    rows = await db.execute(select(Product.id).join(
        OffCatalogueProduct, OffCatalogueProduct.barcode == Product.barcode,
    ).where(Product.id.in_(product_ids), *off_uk_evidence_conditions(as_of=as_of)))
    return set(rows.scalars().all())
