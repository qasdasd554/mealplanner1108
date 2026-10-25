"""Database-side market availability checks without inventing local stock.

These predicates intentionally make no ownership/moderation decisions. Callers
must first enforce the existing recipe permissions and choose whether their
endpoint is a public catalogue or the owner's editing/recovery workspace.
"""

from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import String, and_, exists, func, or_, select, true
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.sql.functions import FunctionElement

from app.core.markets import account_country
from app.core.exceptions import NotFoundException
from app.models import Recipe, RecipeIngredient, Store
from app.models.regional_product_offer import RegionalProductOffer
from app.db.uk_store_catalog import UK_STORES
from app.services.regional_offer_pricing import reviewed_uk_offer
from app.services.off_availability import (
    product_has_off_uk_evidence, off_available_product_ids, community_offer_has_current_off_evidence,
)
from app.services.uk_catalogue_import import canonical_base_unit


UK_OFFER_MAX_AGE_DAYS = 30


def regional_offer_available_condition(*, as_of: date | None = None):
    """Merchant listings and estimated community/app reports remain distinct."""
    from app.services.uk_submission_prices import submission_offer_has_current_product_evidence

    return or_(
        and_(RegionalProductOffer.availability_scope == "online_catalogue",
             RegionalProductOffer.availability_status == "available_online"),
        and_(RegionalProductOffer.availability_scope == "store_observation",
             RegionalProductOffer.availability_status == "reported_available",
             RegionalProductOffer.price_kind == "estimate",
             community_offer_has_current_off_evidence(
                 RegionalProductOffer, as_of=as_of or utc_market_date())),
        and_(RegionalProductOffer.availability_scope == "user_submission",
             RegionalProductOffer.availability_status == "reported_available",
             RegionalProductOffer.price_kind == "estimate",
             submission_offer_has_current_product_evidence(RegionalProductOffer)),
    )


class _UTCReviewDay(FunctionElement):
    """ISO review date independent of the PostgreSQL session TimeZone."""

    type = String()
    inherit_cache = True


@compiles(_UTCReviewDay)
def _compile_review_day_symbolic(element, compiler, **kwargs):
    # Generic SQL rendering is used for diagnostics, never as a DB function.
    return f"utc_review_day({compiler.process(element.clauses, **kwargs)})"


@compiles(_UTCReviewDay, "postgresql")
def _compile_review_day_postgresql(element, compiler, **kwargs):
    column = compiler.process(element.clauses, **kwargs)
    return f"to_char({column} AT TIME ZONE 'UTC', 'YYYY-MM-DD')"


@compiles(_UTCReviewDay, "sqlite")
def _compile_review_day_sqlite(element, compiler, **kwargs):
    column = compiler.process(element.clauses, **kwargs)
    return f"strftime('%Y-%m-%d', {column})"


def utc_market_date() -> date:
    """One trusted server calendar date; never the phone/session timezone."""
    return datetime.now(timezone.utc).date()


def reviewed_uk_offer_conditions(*, as_of: date):
    """Cheap portable SQL guards, not a substitute for full quote validation.

    JSON dates are compared as bounded ISO text rather than cast to DATE: a
    malformed legacy JSON date must not crash a PostgreSQL catalogue query.
    The read/checkout layer still validates sources, fingerprint and exact SKU.
    """
    if type(as_of) is not date:
        raise ValueError("An explicit calendar date is required")
    earliest = as_of - timedelta(days=UK_OFFER_MAX_AGE_DAYS)
    reviewed_day = _UTCReviewDay(RegionalProductOffer.reviewed_at)
    conditions = [
        RegionalProductOffer.country_code == "GB",
        RegionalProductOffer.currency_code == "GBP",
        RegionalProductOffer.store_id.in_([store.id for store in UK_STORES]),
        regional_offer_available_condition(as_of=as_of),
        RegionalProductOffer.reviewed_at.is_not(None),
        RegionalProductOffer.reviewed_at >= datetime.combine(earliest, time.min, timezone.utc),
        RegionalProductOffer.reviewed_at < datetime.combine(as_of + timedelta(days=1), time.min, timezone.utc),
        RegionalProductOffer.package_quantity > 0,
        RegionalProductOffer.package_quantity <= Decimal("999999.999"),
        RegionalProductOffer.package_unit.in_(("g", "ml")),
        RegionalProductOffer.price > 0,
        RegionalProductOffer.price <= Decimal("99999999.99"),
        func.length(RegionalProductOffer.fingerprint) == 64,
        RegionalProductOffer.fingerprint == func.lower(RegionalProductOffer.fingerprint),
        or_(
            and_(RegionalProductOffer.price_kind == "observed", RegionalProductOffer.estimate_reason.is_(None)),
            and_(RegionalProductOffer.price_kind == "estimate", func.length(func.trim(RegionalProductOffer.estimate_reason)).between(10, 1000)),
        ),
    ]
    for source in (RegionalProductOffer.package_source, RegionalProductOffer.price_source,
                   RegionalProductOffer.availability_source):
        checked = source["checked_on"].as_string()
        url = source["url"].as_string()
        publisher = source["publisher"].as_string()
        conditions.extend((
            func.length(checked) == 10,
            checked.like("____-__-__"),
            checked >= earliest.isoformat(),
            checked <= as_of.isoformat(),
            checked <= reviewed_day,
            url.like("https://%"),
            func.length(publisher).between(1, 200),
        ))
    return conditions


def recipe_has_reviewed_uk_offers(recipe: Recipe, offers, *, as_of: date,
                                 store_id: UUID | None = None, off_product_ids=frozenset()) -> bool:
    """Validate country evidence, not the ability to price a household measure.

    Full source/fingerprint and canonical dimension checks remain mandatory.
    Exact shopping arithmetic has its own conversion/whole-package guards.
    """
    if not recipe.ingredients:
        return False
    by_product: dict[UUID, list] = {}
    for offer in offers:
        by_product.setdefault(offer.product_id, []).append(offer)
    for ingredient in recipe.ingredients:
        if ingredient.is_optional:
            continue
        if ingredient.product is None:
            return False
        if ingredient.product_id in off_product_ids:
            # Country-level sale is independent of the weight of a spoon,
            # piece or package. Listing already accepts this same OFF proof.
            # Shopping keeps unresolved amounts in their original units and
            # leaves the price unknown; it must not invent a conversion.
            continue
        try:
            base_unit = canonical_base_unit(ingredient.product)
        except (ValueError, AttributeError):
            return False
        candidates = by_product.get(ingredient.product_id, [])
        if not any(
            (store_id is None or offer.store_id == store_id)
            and (proof := reviewed_uk_offer(offer, as_of=as_of)) is not None
            and proof.package.unit == base_unit
            for offer in candidates
        ):
            return False
    return True


def recipe_market_availability(country_code: str, *, store_id: UUID | None = None,
                               as_of: date | None = None):
    """Every required ingredient needs UK evidence before public pagination.

    Owner-approved policy: exact-GTIN OFF reports establish country-level UK
    availability, not current inventory at the selected shop. Reviewed retailer
    offers remain an alternative. Prices still require their own provenance.
    PL behaviour and recipe permissions are unchanged.
    """
    if country_code != "GB":
        return true()

    store_conditions = [
        Store.country_code == "GB",
        Store.currency_code == "GBP",
        RegionalProductOffer.product_id == RecipeIngredient.product_id,
        *reviewed_uk_offer_conditions(as_of=as_of or utc_market_date()),
    ]
    if store_id is not None:
        store_conditions.append(RegionalProductOffer.store_id == store_id)

    product_is_available = exists(
        select(1)
        .select_from(RegionalProductOffer)
        .join(Store, Store.id == RegionalProductOffer.store_id)
        .where(*store_conditions)
        .correlate(RecipeIngredient)
    )
    product_is_available = or_(product_is_available, product_has_off_uk_evidence(
        RecipeIngredient.product_id, as_of=as_of or utc_market_date(),
    ))
    missing_required_ingredient = exists(
        select(1)
        .select_from(RecipeIngredient)
        .where(
            RecipeIngredient.recipe_id == Recipe.id,
            RecipeIngredient.is_optional.is_(False),
            ~product_is_available,
        )
        .correlate(Recipe)
    )
    # An empty/unknown ingredient list is not evidence that every ingredient
    # is sold locally. Optional ingredients, however, never exclude a dish.
    has_ingredients = exists(
        select(1)
        .select_from(RecipeIngredient)
        .where(RecipeIngredient.recipe_id == Recipe.id)
        .correlate(Recipe)
    )
    return and_(has_ingredients, ~missing_required_ingredient)


def apply_recipe_market_filter(query, user: object, *, store_id: UUID | None = None):
    """Apply before OFFSET/LIMIT so a page is filled with eligible dishes."""
    country = account_country(user)
    if country == "PL":
        return query
    return query.where(recipe_market_availability(country, store_id=store_id))


async def ensure_recipe_available_in_market(db, recipe: Recipe, user: object, *, store_id: UUID | None = None) -> None:
    """Check market availability only; never replace recipe authorization."""
    country = account_country(user)
    if country == "PL":
        return
    result = await db.execute(
        select(Recipe.id).where(
            Recipe.id == recipe.id,
            recipe_market_availability(country, store_id=store_id),
        )
    )
    if result.scalar_one_or_none() is None:
        raise NotFoundException(detail="This recipe is not available in your account country.")
    product_ids = [ingredient.product_id for ingredient in recipe.ingredients if not ingredient.is_optional]
    if not product_ids:
        return
    as_of = utc_market_date()
    stmt = select(RegionalProductOffer).where(
        RegionalProductOffer.product_id.in_(product_ids),
        *reviewed_uk_offer_conditions(as_of=as_of),
    )
    if store_id is not None:
        stmt = stmt.where(RegionalProductOffer.store_id == store_id)
    offers = (await db.execute(stmt)).scalars().all()
    off_ids = await off_available_product_ids(db, product_ids, as_of=as_of)
    if not recipe_has_reviewed_uk_offers(recipe, offers, as_of=as_of, store_id=store_id,
                                        off_product_ids=off_ids):
        raise NotFoundException(detail="This recipe is not available in your account country.")
