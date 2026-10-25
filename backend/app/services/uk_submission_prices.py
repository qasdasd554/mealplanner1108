"""Adapt the existing approved-product form to UK estimated shop prices.

No extra form, HTTP, worker or new source of invented price/package data.
The internal key is not a merchant SKU; availability stays a user report.
"""

from datetime import date, datetime, timezone
from decimal import Decimal

from app.db.uk_product_catalog import UKProductProposal
from app.db.uk_store_catalog import UK_STORES
from app.services.uk_catalogue_import import canonical_base_unit


def submission_offer_has_current_product_evidence(offer):
    """Hide stale app reports after the submitted food/price/pack changes."""
    from sqlalchemy import Float, String, cast, exists, func, select
    from sqlalchemy.orm import aliased
    from app.models import Product

    product = aliased(Product)
    source = offer.price_source
    return exists(select(1).select_from(product).where(
        product.id == offer.product_id, product.submitted_country_code == "GB",
        product.review_status == "approved", product.created_by_user_id.is_not(None),
        source["provider"].as_string() == "product_submission",
        func.replace(cast(product.id, String), "-", "") == func.replace(source["submission_id"].as_string(), "-", ""),
        product.name == source["product_name"].as_string(),
        product.unit == source["product_unit"].as_string(),
        product.brand.is_not_distinct_from(source["product_brand"].as_string()),
        product.barcode.is_not_distinct_from(source["product_barcode"].as_string()),
        product.name == offer.name_en, product.submitted_price == offer.price,
        product.serving_quantity == cast(offer.package_quantity, Float),
    ).correlate_except(product))


def submitted_price_proposal(product, store_id, *, as_of: date):
    store = next((value for value in UK_STORES if value.id == store_id), None)
    reported = getattr(product, "created_at", None)
    if (store is None or getattr(product, "review_status", None) != "approved"
            or getattr(product, "submitted_country_code", None) != "GB"
            or getattr(product, "created_by_user_id", None) is None
            or not isinstance(reported, datetime)):
        return None
    # SQLite strips the timezone; persisted server timestamps represent UTC.
    observed = reported.astimezone(timezone.utc).date() if reported.tzinfo else reported.date()
    if not 0 <= (as_of - observed).days <= 30:
        return None
    try:
        pack = Decimal(str(product.serving_quantity))
        price = Decimal(str(product.submitted_price))
        if (not pack.is_finite() or not 0 < pack <= Decimal("999999.999")
                or pack != pack.quantize(Decimal("0.001"))
                or not price.is_finite() or not 0 < price <= Decimal("99999999.99")
                or price != price.quantize(Decimal("0.01"))):
            return None
        source = dict(url="https://mealplannerpolska.pl/", publisher="Meal Planner Polska — user submission",
            checked_on=observed, provider="product_submission", submission_id=product.id,
            product_name=product.name, product_unit=product.unit,
            product_brand=product.brand, product_barcode=product.barcode)
        return UKProductProposal.model_validate(dict(retailer_slug=store.slug,
            retailer_sku=f"submission-{product.id.hex}", canonical_product_id=product.id,
            name_en=product.name, package=dict(quantity=pack, unit=canonical_base_unit(product),
                source={key: source[key] for key in ("url", "publisher", "checked_on")}),
            price=dict(amount=price, kind="estimate", source=source,
                estimate_reason="User-reported GBP price for this package, approved by an administrator; confirm the current price and availability in the shop."),
            availability_scope="user_submission", availability_status="reported_available",
            availability_source=source))
    except (ValueError, TypeError, ArithmeticError, AttributeError):
        return None


async def import_submitted_price(db, product, store_id, reviewer_id):
    from app.services.uk_catalogue_import import import_reviewed_uk_catalogue

    now = datetime.now(timezone.utc)
    proposal = submitted_price_proposal(product, store_id, as_of=now.date())
    if proposal is None:
        return False
    await import_reviewed_uk_catalogue(db, [proposal], reviewer_user_id=reviewer_id,
        reviewed_at=now, as_of=now.date())
    return True
