"""Existing UK product review must feed the same catalogue/list features as PL."""

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.api.v1.products import review_product
from app.models import Product, Recipe, RecipeIngredient, RegionalProductOffer, Store, StoreProduct
from app.db.uk_store_catalog import UK_STORES
from app.services.market_catalog import recipe_market_availability
from app.services.regional_store_catalogue import list_reviewed_store_products
from app.services.regional_shopping import apply_regional_item_quote, frozen_regional_purchase_quote, load_regional_offers
from tests.test_regional_shopping import db, run


@pytest.fixture
def submission(db):
    session, adapter, admin, _, _ = db
    shop = session.get(Store, UK_STORES[0].id)
    product = Product(id=uuid4(), name="Plain yoghurt", unit="g", default_quantity=100,
        serving_quantity=450, review_status="pending", submitted_country_code="GB",
        submitted_price=Decimal("1.20"), requested_store_ids=[str(shop.id)],
        created_by_user_id=admin.id, created_at=datetime.now(timezone.utc) - timedelta(days=2),
        nutrition_per_100={"kcal": 60, "protein": 4, "fat": 2, "carbs": 6})
    session.add(product)
    session.commit()
    return session, adapter, admin, shop, product


def approve(submission):
    session, adapter, admin, _, product = submission
    run(review_product(product.id, approve=True, db=adapter, current_user=admin))
    return list(session.scalars(select(RegionalProductOffer).where(RegionalProductOffer.product_id == product.id)))


def test_existing_approval_makes_a_usable_gbp_offer_without_legacy_or_foreign_prices(submission):
    session, adapter, _, shop, product = submission
    offers = approve(submission)
    assert len(offers) == 1, "Approved GBP price is otherwise silently ignored by UK readers"
    row = offers[0]
    assert row.price == Decimal("1.20") and row.package_quantity == 450
    assert row.price_kind == "estimate" and row.availability_scope == "user_submission"
    assert row.price_source["provider"] == "product_submission"
    assert row.price_source["checked_on"] == product.created_at.date().isoformat()
    assert list(session.scalars(select(StoreProduct).where(StoreProduct.product_id == product.id))) == []
    page = run(list_reviewed_store_products(adapter, shop.id, skip=0, limit=30,
        search="Plain yoghurt", department_id=None, as_of=datetime.now(timezone.utc).date()))
    assert len(page) == 1 and page[0].price == 1.2
    assert page[0].price_is_estimated is True and page[0].package_quantity == 450
    assert page[0].last_verified is None
    # Re-review is idempotent; no catalogue fan-out to other stores.
    assert len(approve(submission)) == 1


def test_approved_report_is_enough_for_recipe_and_list_but_never_claims_online_stock(submission):
    session, adapter, _, shop, product = submission
    approve(submission)
    dish = Recipe(id=uuid4(), name="Yoghurt dish", meal_type="obiad")
    session.add(dish)
    session.flush()
    session.add(RecipeIngredient(id=uuid4(), recipe_id=dish.id, product_id=product.id,
        quantity=500, unit="g", is_optional=False))
    session.flush()
    assert session.scalar(select(Recipe.id).where(Recipe.id == dish.id, recipe_market_availability("GB"))) == dish.id
    offers = run(load_regional_offers(adapter, [product.id], shop.id))
    item = SimpleNamespace(regional_snapshot=None, is_checked=False, is_from_pantry=False)
    today = datetime.now(timezone.utc).date()
    apply_regional_item_quote(item, product=product, store_id=shop.id, quantity=Decimal("500"),
        unit="g", offers=offers, as_of=today)
    assert item.estimated_price == Decimal("2.40")  # two actual 450g packs, not five 100g portions
    assert item.regional_snapshot.quote_data["availability_status"] == "reported_available"
    item.is_checked = True
    frozen = frozen_regional_purchase_quote(item, as_of=today + timedelta(days=50))
    assert frozen is not None and frozen.total_price == Decimal("2.40")


@pytest.mark.parametrize("bad", ["no_pack", "foreign", "zero_price", "old", "future", "rejected"])
def test_unusable_submission_still_reviews_product_without_inventing_a_price_or_pack(submission, bad):
    session, adapter, admin, _, product = submission
    if bad == "no_pack": product.serving_quantity = None
    elif bad == "foreign": product.submitted_country_code = "PL"
    elif bad == "zero_price": product.submitted_price = 0
    elif bad == "old": product.created_at = datetime.now(timezone.utc) - timedelta(days=40)
    elif bad == "future": product.created_at = datetime.now(timezone.utc) + timedelta(days=2)
    session.commit()
    run(review_product(product.id, approve=bad != "rejected", db=adapter, current_user=admin))
    assert product.review_status == ("rejected" if bad == "rejected" else "approved")
    assert list(session.scalars(select(RegionalProductOffer).where(RegionalProductOffer.product_id == product.id))) == []
    assert list(session.scalars(select(StoreProduct).where(StoreProduct.product_id == product.id))) == []


@pytest.mark.parametrize("change", ["name", "price", "package", "rejected", "country", "unit", "brand", "barcode"])
def test_editing_an_approved_submission_invalidates_live_quotes_not_historical_purchases(submission, change):
    session, adapter, _, shop, product = submission
    assert len(approve(submission)) == 1
    if change == "name": product.name = "Different food"
    elif change == "price": product.submitted_price = Decimal("2.00")
    elif change == "package": product.serving_quantity = 100
    elif change == "country": product.submitted_country_code = "PL"
    elif change == "unit": product.unit = "ml"
    elif change == "brand": product.brand = "Different brand"
    elif change == "barcode": product.barcode = "5901234123457"
    else: product.review_status = "rejected"
    session.commit()
    assert run(load_regional_offers(adapter, [product.id], shop.id)) == []


def test_existing_compare_switch_complete_and_pantry_features_use_approved_reports(submission):
    from copy import deepcopy
    from app.api.v1 import price_compare, shopping_lists as api
    from app.models import PantryItem
    from app.schemas.shopping_list import ShoppingListResponse
    from app.services.shopping_list_builder import ShoppingListBuilder
    from tests.test_regional_shopping import make_plan, loaded

    session, adapter, admin, shop, product = submission
    target = session.get(Store, UK_STORES[1].id)
    product.requested_store_ids = [str(shop.id), str(target.id)]
    session.commit()
    assert len(approve(submission)) == 2
    plan = make_plan(session, admin, product, quantity="500", include_pantry=False, store_id=shop.id)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    list_id, plan_id, product_id, admin_id = shopping.id, plan.id, product.id, admin.id
    comparison = run(price_compare.compare_shopping_list_prices(plan_id, adapter, admin))
    assert len(comparison) == 2
    assert all(row.is_complete and row.total_price == 2.40 and row.has_estimated_prices for row in comparison)
    run(api.update_shopping_list_store(plan_id, api.ShoppingListStoreRequest(store_id=target.id), admin, adapter))
    current = loaded(session, list_id)
    assert current.store_id == target.id
    assert ShoppingListResponse.model_validate(current).total_estimated_price == 2.40
    item = current.items[0]
    item.is_checked = True
    old_price = deepcopy(item.regional_snapshot.quote_data)
    product = session.get(Product, product_id)
    product.submitted_price = Decimal("2.00")
    session.commit()
    # Purchased history survives live-price invalidation and a shop switch.
    run(api.update_shopping_list_store(plan_id, api.ShoppingListStoreRequest(store_id=shop.id), admin, adapter))
    current = loaded(session, list_id)
    assert current.items[0].regional_snapshot.quote_data == old_price
    for _ in range(2):
        run(api.complete_shopping_list(plan_id, True, admin, adapter))
    pantry = session.scalar(select(PantryItem).where(PantryItem.user_id == admin_id, PantryItem.product_id == product_id))
    assert pantry.quantity == 900 and pantry.unit == "g"  # two bought packs, added only once
