"""Generic food identity survives missing or invalid retailer evidence."""

import asyncio
from decimal import Decimal
from uuid import uuid4

import pytest

from app.models import PantryItem, ShoppingListItem
from app.schemas.shopping_list import ShoppingListItemResponse
from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
from tests.test_uk_seed_off_identity import seeded_oats
from tests.test_uk_pricing_availability_integration import db, Database, setup_plan
from tests.uk_regional_fixtures import reviewed_offer, uk_store


@pytest.mark.parametrize("evidence", ["absent", "changed", "pantry", "valid"])
def test_list_uses_english_generic_food_without_borrowing_an_unverified_sku_name(db, evidence):
    food = seeded_oats()
    db.add(food)
    shop = uk_store(db, slug="tesco")
    offer = reviewed_offer(db, food, shop, quantity="750", price="1.25")
    if evidence == "changed": offer.name_en = "Unreviewed ready meal title"
    offers = [] if evidence == "absent" else [offer]
    row = ShoppingListItem(id=uuid4(), is_checked=False, is_generated=True)
    apply_regional_item_quote(row, product=food, store_id=shop.id,
        quantity=Decimal("600"), unit="g", offers=offers,
        as_of=regional_pricing_date(), from_pantry=evidence == "pantry")
    value = ShoppingListItemResponse.model_validate(row)
    assert value.product_name == (offer.name_en if evidence == "valid" else "Oats")
    assert value.currency_code == "GBP" and value.brand is None
    assert value.required_quantity == 600 and value.unit == "g"
    if evidence == "valid":
        assert value.estimated_price == 1.25 and value.package_quantity == 750
        assert value.package_count == 1 and value.purchased_quantity == 750
    elif evidence == "pantry":
        assert value.estimated_price == 0 and value.package_quantity is None
    else:
        assert value.estimated_price == 1.89 and value.quote_status == "quoted"
        assert value.price_is_estimated
        assert value.price_source["provider"] == "ons_national_average"
        assert value.price_source["confirms_store_stock"] is False
        assert value.package_quantity is None and value.regional_offer_id is None
    assert food.brand == "Sante" and food.serving_quantity == 500


@pytest.mark.parametrize("covered", [False, True])
def test_plan_comparison_uses_generic_english_label_for_pantry_or_missing_price(db, covered):
    from app.api.v1.price_compare import compare_prices
    owner, shop, previous, dish, plan = setup_plan(db, quantity="600", include_pantry=True)
    food = seeded_oats()
    db.add(food)
    db.flush()
    dish.ingredients[0].product_id = food.id
    dish.ingredients[0].product = food
    if covered:
        db.add(PantryItem(id=uuid4(), user_id=owner.id, product_id=food.id,
            quantity=Decimal("600"), unit="g"))
    db.flush()
    result = asyncio.run(compare_prices(plan.id, db=Database(db), current_user=owner))[0]
    assert result.currency_code == "GBP"
    if covered:
        assert result.total_price == 0 and result.items[0].product_name == "Oats"
        assert result.items[0].is_from_pantry and result.items[0].quantity_needed == 600
    else:
        assert result.total_price == 1.89 and result.missing_products == []
        assert result.is_complete and not result.is_cheapest
        assert result.items[0].product_name == "Oats"
        assert result.items[0].price_source["provider"] == "ons_national_average"
        assert result.items[0].regional_offer_id is None and result.items[0].package_quantity is None
