"""Read-only, validated UK SKU pages; no legacy price/package substitution."""

from datetime import date
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import or_, select
from sqlalchemy.orm import raiseload

from app.models import Product, RegionalProductOffer
from app.schemas.product import ProductResponse, StoreProductResponse
from app.services.regional_offer_pricing import reviewed_uk_offer
from app.services.uk_catalogue_import import canonical_base_unit
from app.services.product_market_presentation import is_uk_generic_seed, product_for_market
from app.services.market_catalog import regional_offer_available_condition
from app.services.system_content_language import (
    english_system_name_match, english_system_name_order,
    generic_system_ingredient_condition, ingredient_display_name,
)
from app.services.uk_ons_pricing import quote_national_requirement


async def list_reviewed_store_products(db, store_id, *, skip: int, limit: int,
                                       search: str | None, department_id, as_of: date,
                                       include_generic_foods: bool = False):
    # A Polish department association is not evidence for a UK SKU. No reviewed
    # UK department mapping exists yet; never silently return another department.
    if department_id is not None:
        return []
    query = select(RegionalProductOffer, Product).options(raiseload(Product.allergens)).join(
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
            english_system_name_match(Product, search, kind="ingredients"),
        ))
    query = query.order_by(RegionalProductOffer.name_en, RegionalProductOffer.id)
    # Invalid/stale JSON evidence must be excluded BEFORE public pagination.
    # Fetch in bounded chunks, not one query per product or an unbounded .all().
    offset, valid_seen, output = 0, 0, []
    covered_products = set()
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
            if is_uk_generic_seed(product, country_code="GB"):
                covered_products.add(product.id)  # bounded by 390 seed identities
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
    if include_generic_foods and len(output) < limit:
        # No extra catalogue copies or per-shop fake inventory rows. Reuse the
        # same 390 immutable system identities and reviewed English labels.
        generic = select(Product).options(raiseload(Product.allergens)).where(
            generic_system_ingredient_condition(Product))
        if covered_products:
            generic = generic.where(Product.id.not_in(covered_products))
        if search:
            generic = generic.where(or_(
                Product.name.ilike(f"%{escaped}%", escape="\\"),
                english_system_name_match(Product, search, kind="ingredients"),
            ))
        generic = generic.order_by(
            english_system_name_order(Product, kind="ingredients"), Product.id,
        ).offset(max(0, skip - valid_seen)).limit(limit - len(output))
        for product in (await db.execute(generic)).scalars():
            try:
                unit = canonical_base_unit(product)
            except ValueError:
                unit = None
            quote = quote_national_requirement(product, 100, unit,
                store_id=store_id, as_of=as_of)
            output.append(StoreProductResponse(
                id=uuid5(NAMESPACE_URL, f"generic-shop-food:{store_id}:{product.id}"),
                store_id=store_id, product_id=product.id,
                product=ProductResponse.model_validate(product_for_market(product, country_code="GB")),
                name_en=ingredient_display_name(product, country_code="GB"),
                currency_code="GBP", catalogue_kind="generic_food",
                availability_scope="generic_food_reference", is_available=None,
                price=float(quote.total_price) if quote else None,
                price_basis="national_quantity_reference" if quote else "unknown",
                price_quantity=100 if quote else None, price_unit=unit if quote else None,
                price_is_estimated=True, price_source=quote.price_source if quote else None,
            ))
    return output
