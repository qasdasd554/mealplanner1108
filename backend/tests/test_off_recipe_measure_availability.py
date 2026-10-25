"""UK country availability must not depend on knowing a spoon/piece weight."""

import asyncio
from datetime import datetime, timezone
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.core.exceptions import NotFoundException
from app.models import Product, ShoppingListItem, Store
from app.services.market_catalog import (
    ensure_recipe_available_in_market, recipe_has_reviewed_uk_offers,
)
from app.services.regional_shopping import apply_regional_item_quote
from app.db.uk_store_catalog import UK_STORES
from app.services.meal_plan_generator import MealPlanGenerator
from app.services.shopping_list_builder import ShoppingListBuilder
from tests.test_off_ingredient_mapping import (
    CODE, imported, proposal, setup, visible,
)
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db
from tests.test_regional_shopping import AsyncDB
from tests.uk_regional_fixtures import reviewed_offer


@pytest.mark.parametrize("unit", ["szt", "lyzeczka", "lyzka", "szklanka", "opak"])
@pytest.mark.parametrize("identity", ["reviewed_generic", "exact_gtin", "reviewed_retailer"])
def test_off_available_recipe_opens_without_fabricating_measure_or_price(
    catalogue_db, unit, identity,
):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    product = session.get(Product, product_id)
    ingredient = recipe.ingredients[0]
    ingredient.quantity, ingredient.unit = Decimal("2"), unit
    product.measure_options = []
    session.commit()
    if identity == "reviewed_generic":
        imported(session, reviewer, [proposal(session, product_id)])
    elif identity == "exact_gtin":
        product.barcode = CODE
    else:
        reviewed_offer(session, product, session.get(Store, UK_STORES[0].id))
    session.commit()

    # SQL listing already regards this ingredient as sold in the UK. The
    # detail/generator gate must agree; a missing household measure is not
    # evidence that a product disappeared from the country.
    assert visible(session) == {recipe.id}
    asyncio.run(ensure_recipe_available_in_market(
        AsyncAdapter(session), recipe, SimpleNamespace(country_code="GB"),
    ))
    if identity != "reviewed_retailer":
        assert recipe_has_reviewed_uk_offers(
            recipe, [], as_of=datetime.now(timezone.utc).date(),
            off_product_ids={product_id},
        )
    item = ShoppingListItem(is_checked=False, is_generated=True)
    apply_regional_item_quote(
        item, product=product, store_id=None, quantity=ingredient.quantity,
        unit=unit, offers=[], as_of=datetime.now(timezone.utc).date(),
    )
    assert item.required_quantity == Decimal("2") and item.unit == unit
    assert item.estimated_price is None
    assert item.regional_snapshot.quote_status == "unpriced"
    assert item.regional_snapshot.required_quantity is None
    assert item.regional_snapshot.quote_data is None
    assert product.measure_options == [] and product.serving_quantity == 200


def test_missing_country_evidence_still_rejects_recipe_with_unknown_measure(catalogue_db):
    session, _, product_id = catalogue_db
    recipe = setup(session, product_id)
    recipe.ingredients[0].unit = "lyzeczka"
    session.commit()
    assert visible(session) == set()
    with pytest.raises(NotFoundException):
        asyncio.run(ensure_recipe_available_in_market(
            AsyncAdapter(session), recipe, SimpleNamespace(country_code="GB"),
        ))


def test_invalid_retailer_fingerprint_still_rejects_with_english_recovery(catalogue_db):
    session, _, product_id = catalogue_db
    recipe = setup(session, product_id)
    product = session.get(Product, product_id)
    product.measure_options = []
    recipe.ingredients[0].unit = "lyzeczka"
    offer = reviewed_offer(session, product, session.get(Store, UK_STORES[0].id))
    offer.fingerprint = "0" * 64
    session.commit()
    assert visible(session) == {recipe.id}
    with pytest.raises(NotFoundException) as error:
        asyncio.run(ensure_recipe_available_in_market(
            AsyncAdapter(session), recipe, SimpleNamespace(country_code="GB"),
        ))
    assert error.value.detail == "This recipe is not available in your account country."


def test_known_recipe_amount_remains_convertible_and_price_is_not_inferred(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    imported(session, reviewer, [proposal(session, product_id)])
    product = session.get(Product, product_id)
    item = ShoppingListItem(is_checked=False, is_generated=True)
    apply_regional_item_quote(item, product=product, store_id=None,
        quantity=Decimal("0.25"), unit="kg", offers=[],
        as_of=datetime.now(timezone.utc).date())
    assert item.required_quantity == 250 and item.unit == "g"
    assert item.estimated_price is None
    assert item.regional_snapshot.required_quantity == 250


def test_same_off_recipe_qualifies_for_plan_and_keeps_raw_amount_on_shopping_list(catalogue_db):
    session, reviewer, product_id = catalogue_db
    recipe = setup(session, product_id)
    product = session.get(Product, product_id)
    product.measure_options = []
    recipe.ingredients[0].quantity, recipe.ingredients[0].unit = Decimal("2"), "szt"
    session.commit()
    imported(session, reviewer, [proposal(session, product_id)])
    session.commit()
    adapter = AsyncDB(session)
    eligible = asyncio.run(MealPlanGenerator(adapter)._filter_eligible_recipes(
        allergen_ids=set(), store_id=UK_STORES[0].id, country_code="GB",
    ))
    assert [row.id for row in eligible] == [recipe.id]
    plan = SimpleNamespace(
        user_id=reviewer, store_id=UK_STORES[0].id,
        entries=[SimpleNamespace(recipe=eligible[0], servings_multiplier=Decimal("1.5"))],
    )
    rows = asyncio.run(ShoppingListBuilder(adapter)._resolve_regional_requirements(
        plan, include_pantry=False,
    ))
    assert len(rows) == 1
    assert rows[0]["required_quantity"] == 3 and rows[0]["unit"] == "szt"
    assert rows[0]["estimated_price"] is None
    snapshot = rows[0]["regional_snapshot"]
    assert snapshot.product_id == product_id
    assert snapshot.required_quantity is None and snapshot.required_unit is None
    assert snapshot.quote_status == "unpriced" and snapshot.quote_data is None
