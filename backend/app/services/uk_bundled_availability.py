"""Use the already reviewed starter on a fresh deployment, without a DB import.

This is a small pinned OFF reference, not a catalogue dump or a price/stock
feed. It cannot renew its original observation times. A persisted newer OFF
record takes precedence, including changed/withdrawn facts. No DB writes,
synthetic reviewer account, provider calls or application-startup work.
"""

from datetime import date, timedelta, timezone
from functools import lru_cache
from pathlib import Path

from sqlalchemy import and_, case, exists, false, func, or_, select
from sqlalchemy.orm import aliased

from app.models import Product, OffCatalogueProduct


@lru_cache(maxsize=1)
def _reviewed_rows():
    # The loader validates the shipped canonical hashes, all GTINs, fingerprints
    # and country evidence. Import lazily to avoid the importer/SQL module cycle.
    from app.services.uk_starter_import import load_starter_bundle

    bundle = load_starter_bundle(Path(__file__).resolve().parents[1] /
        "data/uk_starter_20261024.json")
    records = {row.values["barcode"]: row for row in bundle.products}
    original = tuple((link, records[link.off_barcode]) for link in bundle.proposals)
    from app.services.uk_system_recipe_reference import reviewed_system_recipe_references

    expanded = reviewed_system_recipe_references()[0]
    rows = original + expanded
    if len({link.product_id for link, _ in rows}) != len(rows):
        raise ValueError('Duplicate bundled country food identity')
    return rows


def bundled_uk_evidence_condition(product_id, *, as_of: date):
    if type(as_of) is not date:
        raise ValueError("An explicit calendar date is required")
    food = aliased(Product)
    matches = []
    from app.services.off_availability import off_uk_evidence_conditions

    for link, record in _reviewed_rows():
        observed = record.retrieved_at.astimezone(timezone.utc).date()
        persisted = exists(select(1).select_from(OffCatalogueProduct).where(
            OffCatalogueProduct.barcode == link.off_barcode))
        unchanged_fresh = exists(select(1).select_from(OffCatalogueProduct).where(
            OffCatalogueProduct.barcode == link.off_barcode,
            OffCatalogueProduct.fingerprint == link.off_fingerprint,
            *off_uk_evidence_conditions(as_of=as_of)))
        # A real matching fetch may extend freshness; changing a source file's
        # timestamp, a different fingerprint or a non-UK record never can.
        proof = unchanged_fresh
        if as_of - timedelta(days=30) <= observed <= as_of:
            proof = or_(proof, ~persisted)
        matches.append(and_(food.id == link.product_id, food.name == link.product_name,
            food.brand.is_not_distinct_from(link.product_brand), proof))
    if not matches:
        return false()
    # Only the unchanged generic food concept qualifies. An exact SKU, edited
    # identity, pending contribution or user's food can never borrow this proof.
    return exists(select(1).select_from(food).where(
        food.id == product_id, food.barcode.is_(None),
        food.created_by_user_id.is_(None), food.review_status == "approved",
        or_(*matches),
    ).correlate_except(food))


def bundled_cached_identity_condition(food, cached):
    """Known matching cached identities may use the existing bounded refresh."""
    return or_(*(and_(food.id == link.product_id, food.name == link.product_name,
        food.brand.is_not_distinct_from(link.product_brand),
        cached.barcode == link.off_barcode, cached.fingerprint == link.off_fingerprint)
        for link, _ in _reviewed_rows()))


def bundled_recipe_refresh_query(*, now, excluded_keys=(), limit=2):
    """At most two already-reviewed codes used by public recipe ingredients.

    No name search, dump, implicit approval, product/price/pack rewrite or
    full-dataset import. Just initialise/refresh the actually used exact GTINs
    through the existing provider budget after the catalogue response is sent.
    """
    from app.models import Recipe, RecipeIngredient

    rows = _reviewed_rows()
    code = case({link.product_id: link.off_barcode for link, _ in rows}, value=Product.id)
    cached = aliased(OffCatalogueProduct)
    identity = or_(*(and_(Product.id == link.product_id, Product.name == link.product_name,
        Product.brand.is_not_distinct_from(link.product_brand)) for link, _ in rows))
    same_cache = bundled_cached_identity_condition(Product, cached)
    used = exists(select(1).select_from(RecipeIngredient).join(Recipe,
        Recipe.id == RecipeIngredient.recipe_id).where(
            RecipeIngredient.product_id == Product.id,
            RecipeIngredient.is_optional.is_(False), Recipe.is_active.is_(True),
            or_(Recipe.created_by_user_id.is_(None), Recipe.visibility == "public"),
        ).correlate(Product))
    return select(code).select_from(Product).outerjoin(cached, cached.barcode == code).where(
        Product.created_by_user_id.is_(None), Product.barcode.is_(None),
        Product.review_status == "approved", identity, used,
        func.ltrim(code, "0").not_in(tuple(excluded_keys)),
        or_(cached.barcode.is_(None), and_(same_cache,
            cached.country_code == "GB", cached.licence == "ODbL-1.0",
            cached.source_url == "https://world.openfoodfacts.org/product/" + cached.barcode,
            cached.retrieved_at < now - timedelta(days=7))),
    ).order_by(cached.retrieved_at.asc().nulls_first(), Product.id).limit(min(2, max(0, limit)))
