"""Read-only, validated UK SKU pages; no legacy price/package substitution."""

from datetime import date

from sqlalchemy import or_, select

from app.models import Product, RegionalProductOffer
from app.schemas.product import ProductResponse, StoreProductResponse
from app.services.regional_offer_pricing import reviewed_uk_offer
from app.services.uk_catalogue_import import canonical_base_unit
from app.services.product_market_presentation import product_for_market
from app.services.market_catalog import regional_offer_available_condition


async def list_reviewed_store_products(db, store_id, *, skip: int, limit: int,
                                       search: str | None, department_id, as_of: date):
    # A Polish department association is not evidence for a UK SKU. No reviewed
    # UK department mapping exists yet; never silently return another department.
    if department_id is not None:
        return []
    query = select(RegionalProductOffer, Product).join(
        Product, Product.id == RegionalProductOffer.product_id,
    ).where(
        RegionalProductOffer.store_id == store_id,
        RegionalProductOffer.country_code == "GB",
        RegionalProductOffer.currency_code == "GBP",
        regional_offer_available_condition(as_of=as_of),
        Product.review_status == "approved",
    )
    if search:
        escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        query = query.where(or_(
            RegionalProductOffer.name_en.ilike(f"%{escaped}%", escape="\\"),
            Product.name.ilike(f"%{escaped}%", escape="\\"),
        ))
    query = query.order_by(RegionalProductOffer.name_en, RegionalProductOffer.id)
    # Invalid/stale JSON evidence must be excluded BEFORE public pagination.
    # Fetch in bounded chunks, not one query per product or an unbounded .all().
    offset, valid_seen, output = 0, 0, []
    while len(output) < limit:
        batch = (await db.execute(query.offset(offset).limit(200))).all()
        if not batch:
            break
        offset += len(batch)
        for offer, product in batch:
            proposal = reviewed_uk_offer(offer, as_of=as_of)
            if proposal is None:
                continue
            try:
                if canonical_base_unit(product) != proposal.package.unit:
                    continue
            except ValueError:
                continue
            valid_seen += 1
            if valid_seen <= skip:
                continue
            output.append(StoreProductResponse(
                id=offer.id, store_id=store_id, product_id=product.id,
                price=float(proposal.price.amount), currency_code="GBP",
                is_available=True, product=ProductResponse.model_validate(
                    product_for_market(product, country_code="GB")),
                name_en=proposal.name_en, package_quantity=float(proposal.package.quantity),
                package_unit=proposal.package.unit,
                price_is_estimated=proposal.price.kind == "estimate",
                estimate_reason=proposal.price.estimate_reason,
                last_verified=proposal.price.source.checked_on if proposal.price.kind == "observed" else None,
                price_source=proposal.price.source.model_dump(mode="json"),
                availability_scope=proposal.availability_scope,
            ))
            if len(output) == limit:
                break
        if len(batch) < 200:
            break
    return output
