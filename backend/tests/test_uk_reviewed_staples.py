"""Reviewed public UK foods; local SQLite only, never live imports or prices."""

import asyncio
from copy import deepcopy
from datetime import datetime
import json
from pathlib import Path
from uuid import UUID, uuid4

from sqlalchemy import func, select

from app.db.seed import NUTRITION_DATA, PRODUCTS_DATA, PRODUCT_BRANDS, _uid
from app.models import Product, Recipe, RecipeIngredient, RegionalProductOffer
from app.services.market_catalog import recipe_market_availability
from app.services.off_availability import off_available_product_ids
from app.services.off_catalogue import catalogue_values, import_off_catalogue
from app.services.off_ingredient_mapping import OffMappingProposal, import_reviewed_off_mappings
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db


EVIDENCE = json.loads((Path(__file__).parent
    / "fixtures/off_uk_staples_20261023.json").read_text(encoding="utf-8"))
RETRIEVED = datetime.fromisoformat(EVIDENCE["retrieved_at"])


def test_reviewed_batch_uses_exact_seed_foods_not_polish_brands_or_pack_defaults(catalogue_db):
    session, reviewer, _ = catalogue_db
    adapter = AsyncAdapter(session)
    seeds = {row[0]: row for row in PRODUCTS_DATA}
    products = []
    recipes = []
    for proposal in EVIDENCE["proposals"]:
        source = seeds[proposal["product_name"]]
        assert proposal["product_id"] == str(_uid("product:" + source[0]))
        assert proposal["product_unit"] == source[1]
        assert proposal["product_brand"] == PRODUCT_BRANDS[source[0]]
        product = Product(id=UUID(proposal["product_id"]), name=source[0], unit=source[1],
            brand=PRODUCT_BRANDS[source[0]], default_quantity=source[2],
            nutrition_per_100=dict(NUTRITION_DATA[source[0]]), review_status="approved")
        recipe = Recipe(id=uuid4(), name="Synthetic recipe using " + source[0], meal_type="obiad")
        recipe.ingredients = [RecipeIngredient(id=uuid4(), product=product,
            quantity=1, unit=product.unit, is_optional=False)]
        products.append(product)
        recipes.append(recipe)
    session.add_all(products + recipes)
    session.commit()
    original = {p.id: (p.name, p.brand, p.unit, p.default_quantity, p.serving_quantity,
                      deepcopy(p.nutrition_per_100), p.barcode) for p in products}
    raw = [row["product"] for row in EVIDENCE["products"]]
    assert asyncio.run(import_off_catalogue(adapter, raw, retrieved_at=RETRIEVED)) == 6
    session.commit()

    # Cached OFF records alone cannot establish that a generic food ID means
    # this SKU. Matching the ingredient's reviewed identity is a separate step.
    ids = set(original)
    assert asyncio.run(off_available_product_ids(adapter, ids, as_of=RETRIEVED.date())) == set()
    result = asyncio.run(import_reviewed_off_mappings(adapter, EVIDENCE["proposals"],
        reviewer_user_id=reviewer, reviewed_at=RETRIEVED, as_of=RETRIEVED.date()))
    assert (result.created, result.updated, result.unchanged) == (6, 0, 0)
    assert asyncio.run(off_available_product_ids(adapter, ids, as_of=RETRIEVED.date())) == ids
    visible = set(session.scalars(select(Recipe.id).where(
        recipe_market_availability("GB", as_of=RETRIEVED.date()))))
    assert visible == {recipe.id for recipe in recipes}
    assert {p.id: (p.name, p.brand, p.unit, p.default_quantity, p.serving_quantity,
                  p.nutrition_per_100, p.barcode) for p in products} == original
    assert session.scalar(select(func.count()).select_from(RegionalProductOffer)) == 0
    session.rollback()
    assert asyncio.run(off_available_product_ids(adapter, ids, as_of=RETRIEVED.date())) == set()


def test_public_identity_packet_is_explicit_and_reproducible_without_invented_prices():
    assert EVIDENCE["automatic_import"] is False
    assert EVIDENCE["licence"] == "ODbL-1.0"
    proposals = [OffMappingProposal.model_validate(row) for row in EVIDENCE["proposals"]]
    assert len({row.product_id for row in proposals}) == 6
    assert len({row.off_barcode for row in proposals}) == 6
    for row in EVIDENCE["products"]:
        assert row["http_status"] == 200 and row["cache_eligible"]
        assert row["barcode_requested"] == row["product"]["code"]
        parsed = catalogue_values(row["product"], retrieved_at=RETRIEVED)
        assert parsed is not None and parsed["fingerprint"] == row["fingerprint"]
        assert "price" not in parsed
        proposal = next(p for p in proposals if p.off_barcode == parsed["barcode"])
        assert proposal.off_fingerprint == parsed["fingerprint"]
    by_name = {row.product_name: row.off_barcode for row in proposals}
    # Similar tomato labels must remain separate food identities. The rice
    # example proves basmati, not arborio, brown rice or a ready rice meal.
    assert by_name["Passata pomidorowa"] != by_name["Koncentrat pomidorowy"]
    assert "Ryż basmati" in by_name and "Ryż biały" not in by_name
