"""OFF-reported UK sales, never inferred retailer stock, prices or nutrition.

An exact GTIN or an explicit reviewed generic-ingredient link binds a canonical
app product to public OFF facts. Similar names or a translated label never
establish identity. A link conveys availability only, not another SKU's macros.
"""

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import exists, func, or_, select
from sqlalchemy.orm import aliased

from app.models.product import Product
from app.models.off_catalogue_product import OffCatalogueProduct
from app.models.off_ingredient_mapping import OffIngredientMapping


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
    exact_code = exists(select(1).select_from(candidate).join(
        OffCatalogueProduct, OffCatalogueProduct.barcode == candidate.barcode,
    ).where(candidate.id == product_id, *off_uk_evidence_conditions(as_of=as_of))
        .correlate_except(candidate, OffCatalogueProduct))
    reviewed_generic = exists(select(1).select_from(candidate).join(
        OffIngredientMapping, OffIngredientMapping.product_id == candidate.id,
    ).join(OffCatalogueProduct,
        OffCatalogueProduct.barcode == OffIngredientMapping.off_barcode,
    ).where(
        candidate.id == product_id,
        candidate.barcode.is_(None),
        candidate.created_by_user_id.is_(None),
        candidate.review_status == "approved",
        candidate.brand.is_not_distinct_from(OffIngredientMapping.product_brand),
        candidate.name == OffIngredientMapping.product_name,
        candidate.unit == OffIngredientMapping.product_unit,
        OffIngredientMapping.country_code == "GB",
        OffIngredientMapping.base_unit == OffCatalogueProduct.base_unit,
        OffIngredientMapping.off_fingerprint == OffCatalogueProduct.fingerprint,
        OffIngredientMapping.reviewed_at < datetime.combine(
            as_of + timedelta(days=1), time.min, timezone.utc),
        *off_uk_evidence_conditions(as_of=as_of),
    ).correlate_except(candidate, OffIngredientMapping, OffCatalogueProduct))
    return or_(exact_code, reviewed_generic)


async def off_available_product_ids(db, product_ids, *, as_of: date):
    """One batched local query after recipe filtering; no external fan-out."""
    if not product_ids:
        return set()
    rows = await db.execute(select(Product.id).where(
        Product.id.in_(product_ids), product_has_off_uk_evidence(Product.id, as_of=as_of)))
    return set(rows.scalars().all())


def community_offer_has_current_off_evidence(offer, *, as_of: date):
    """A live community price still needs its exact reviewed OFF identity.

    This is for new quotes/catalogue filtering only. Bought shopping snapshots
    keep their separately validated historical source and never use this gate.
    Do not refresh mappings or infer replacements when OFF facts change.
    """
    candidate = aliased(Product)
    return exists(select(1).select_from(candidate).join(
        OffIngredientMapping, OffIngredientMapping.product_id == candidate.id,
    ).join(OffCatalogueProduct,
        OffCatalogueProduct.barcode == OffIngredientMapping.off_barcode,
    ).where(
        candidate.id == offer.product_id,
        candidate.barcode.is_(None),
        candidate.created_by_user_id.is_(None),
        candidate.review_status == "approved",
        candidate.name == OffIngredientMapping.product_name,
        candidate.unit == OffIngredientMapping.product_unit,
        candidate.brand.is_not_distinct_from(OffIngredientMapping.product_brand),
        OffIngredientMapping.country_code == "GB",
        OffIngredientMapping.base_unit == OffCatalogueProduct.base_unit,
        OffIngredientMapping.off_fingerprint == OffCatalogueProduct.fingerprint,
        OffIngredientMapping.reviewed_at < datetime.combine(
            as_of + timedelta(days=1), time.min, timezone.utc),
        offer.price_source["provider"].as_string() == "open_prices",
        offer.price_source["package_basis"].as_string() == "as_sold",
        OffCatalogueProduct.barcode == offer.price_source["product_code"].as_string(),
        OffCatalogueProduct.fingerprint == offer.price_source["off_fingerprint"].as_string(),
        OffCatalogueProduct.name == offer.name_en,
        OffCatalogueProduct.base_unit == offer.package_unit,
        OffCatalogueProduct.package_quantity == offer.package_quantity,
        *off_uk_evidence_conditions(as_of=as_of),
    ).correlate_except(candidate, OffIngredientMapping, OffCatalogueProduct))
