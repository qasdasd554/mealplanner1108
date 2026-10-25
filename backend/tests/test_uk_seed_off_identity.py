"""Actual legacy seed identity + a public OFF sample; no network or live writes."""

import asyncio
from datetime import datetime, timezone
import json
from pathlib import Path
from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest
from sqlalchemy import select

from app.models import Product, Recipe, RecipeIngredient
from app.services.market_catalog import apply_recipe_market_filter
from app.services.off_catalogue import catalogue_values
from app.services.off_ingredient_mapping import import_reviewed_off_mappings
from app.services.off_availability import off_available_product_ids
from app.services.system_content_language import _index, is_system_ingredient
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db


FIXTURE = json.loads((Path(__file__).parent / "fixtures/off_uk_oats_20261023.json")
    .read_text(encoding="utf-8"))
NOW = datetime.now(timezone.utc)
OATS_ID = UUID("c65508d5-139b-5f92-9850-1507938eb5e5")


def seeded_oats():
    from app.db.seed import PRODUCT_BRANDS, NUTRITION_DATA
    return Product(id=OATS_ID, name="Płatki owsiane", brand=PRODUCT_BRANDS["Płatki owsiane"],
        unit="g", default_quantity=500, serving_quantity=500,
        nutrition_per_100=dict(NUTRITION_DATA["Płatki owsiane"]), review_status="approved")


def test_reviewed_legacy_seed_brand_does_not_hide_generic_ingredient_in_uk(catalogue_db):
    from app.models.off_catalogue_product import OffCatalogueProduct
    session, reviewer, _ = catalogue_db
    product = seeded_oats()
    off = OffCatalogueProduct(**catalogue_values(FIXTURE["product"], retrieved_at=NOW))
    recipe = Recipe(id=uuid4(), name="Example oats dish", meal_type="sniadanie")
    recipe.ingredients = [RecipeIngredient(id=uuid4(), product=product,
        quantity=60, unit="g", is_optional=False)]
    session.add_all([product, off, recipe])
    session.commit()
    row = dict(product_id=product.id, product_name=product.name, product_unit=product.unit,
        product_brand=product.brand,
        off_barcode=off.barcode, off_fingerprint=off.fingerprint,
        review_note="Reviewed plain rolled oats identity; UK-reported example is not the Polish brand or pack.")
    result = asyncio.run(import_reviewed_off_mappings(AsyncAdapter(session), [row],
        reviewer_user_id=reviewer, reviewed_at=NOW, as_of=NOW.date()))
    assert result.created == 1
    visible = set(session.scalars(apply_recipe_market_filter(select(Recipe.id),
        SimpleNamespace(country_code="GB"))))
    assert recipe.id in visible
    assert product.brand == "Sante" and product.serving_quantity == 500
    assert product.barcode is None and off.package_quantity == 1000
    assert product.nutrition_per_100["kcal"] == 389  # Never transplanted from OFF's 370.
    session.commit()
    product.brand = "A different branded identity"
    session.commit()
    assert set(session.scalars(apply_recipe_market_filter(select(Recipe.id),
        SimpleNamespace(country_code="GB")))) == set()
    assert asyncio.run(off_available_product_ids(AsyncAdapter(session), [product.id],
        as_of=NOW.date())) == set()
    assert recipe.id in set(session.scalars(apply_recipe_market_filter(select(Recipe.id),
        SimpleNamespace(country_code="PL"))))


@pytest.mark.parametrize("change", ["id", "name", "author", "barcode", "status", "snapshot_brand"])
def test_seed_exception_never_accepts_arbitrary_branded_food_or_stale_snapshot(catalogue_db, change):
    from app.models.off_catalogue_product import OffCatalogueProduct
    from app.models.off_ingredient_mapping import OffIngredientMapping
    session, reviewer, _ = catalogue_db
    product = seeded_oats()
    if change == "id": product.id = uuid4()
    elif change == "name": product.name = "Chocolate breakfast cereal"
    elif change == "author": product.created_by_user_id = reviewer
    elif change == "barcode": product.barcode = FIXTURE["product"]["code"]
    elif change == "status": product.review_status = "pending"
    off = OffCatalogueProduct(**catalogue_values(FIXTURE["product"], retrieved_at=NOW))
    session.add_all([product, off])
    session.commit()
    row = dict(product_id=product.id, product_name=product.name, product_unit=product.unit,
        product_brand=None if change == "snapshot_brand" else product.brand,
        off_barcode=off.barcode, off_fingerprint=off.fingerprint,
        review_note="Offline identity safety test, never automatic production data.")
    with pytest.raises(ValueError):
        asyncio.run(import_reviewed_off_mappings(AsyncAdapter(session), [row],
            reviewer_user_id=reviewer, reviewed_at=NOW, as_of=NOW.date()))
    assert session.scalar(select(OffIngredientMapping)) is None


def test_all_legacy_seed_ingredient_identities_are_recognised_without_brand_guessing():
    from app.db.seed import PRODUCT_BRANDS, PRODUCTS_DATA, _uid
    entries = _index()["ingredients"]
    assert len(entries) == len(PRODUCTS_DATA) == 390
    assert set(entries) == {str(_uid("product:" + row[0])) for row in PRODUCTS_DATA}
    assert {row["source"] for row in entries.values()} == {row[0] for row in PRODUCTS_DATA}
    for identity, row in entries.items():
        product = SimpleNamespace(id=UUID(identity), name=row["source"],
            brand=PRODUCT_BRANDS[row["source"]], created_by_user_id=None)
        assert is_system_ingredient(product)
        product.id = uuid4()
        assert not is_system_ingredient(product)
