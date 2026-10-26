"""National quantity estimates are neither merchant prices nor pack evidence."""
from copy import deepcopy
from datetime import date
from decimal import Decimal
from uuid import uuid4

import pytest

from app.db.seed import PRODUCTS_DATA, PRODUCT_BRANDS, NUTRITION_DATA, _uid
from app.models import Product, ShoppingListItem
from app.services.product_measures import build_measure_options
from app.services.regional_shopping import apply_regional_item_quote, frozen_regional_purchase_quote
from app.db.uk_store_catalog import UK_STORES


DAY = date(2026, 10, 24)


def food(name="Płatki owsiane"):
    seed = next(row for row in PRODUCTS_DATA if row[0] == name)
    return Product(id=_uid("product:" + name), name=name, unit=seed[1],
        brand=PRODUCT_BRANDS.get(name), review_status="approved", created_by_user_id=None,
        default_quantity=seed[2], nutrition_per_100=deepcopy(NUTRITION_DATA.get(name)),
        measure_options=build_measure_options(name, seed[1], seed[2], None))


def make_item(product=None, quantity="500", unit="g", *, pantry=False):
    item = ShoppingListItem(id=uuid4(), is_checked=False)
    return apply_regional_item_quote(item, product=product or food(), store_id=UK_STORES[0].id,
        quantity=Decimal(quantity), unit=unit, offers=[], as_of=DAY, from_pantry=pantry)


def test_ons_estimates_required_quantity_without_manufacturing_a_shop_sku():
    item = make_item()
    assert item.estimated_price == Decimal("1.57")
    source = item.regional_snapshot.quote_data["price_source"]
    assert source["provider"] == "ons_national_average" and source["period"] == "2026-09"
    assert item.regional_snapshot.offer_id is None
    assert "package_quantity" not in item.regional_snapshot.quote_data
    item.is_checked = True
    saved = frozen_regional_purchase_quote(item, as_of=date(2026, 12, 1))
    assert saved.total_price == Decimal("1.57") and saved.purchased_quantity == Decimal(500)
    assert saved.package_quantity is None and saved.offer_id is None


@pytest.mark.parametrize("change", ["name", "owner", "status", "dimension"])
def test_changed_or_authored_food_cannot_take_a_seed_foods_reference(change):
    product = food()
    if change == "name": product.name = "Flavoured oat dessert"
    if change == "owner": product.created_by_user_id = uuid4()
    if change == "status": product.review_status = "pending"
    if change == "dimension": product.unit, product.measure_options = "ml", []
    assert make_item(product).estimated_price is None


def test_reference_does_not_guess_an_unsupported_ingredient_or_a_piece_mass():
    assert make_item(food("Mąka pszenna")).estimated_price is None  # ONS self-raising is not plain flour.
    assert make_item(food("Ogórek"), "150").estimated_price is None  # ONS each is not grams.


def test_pantry_is_still_zero_not_a_national_purchase():
    item = make_item(pantry=True)
    assert item.estimated_price == 0 and item.regional_snapshot.quote_status == "pantry"


@pytest.mark.parametrize("change", ["total", "quantity", "source", "period", "fingerprint", "package", "offer", "dimension"])
def test_corrupted_reference_is_not_preserved_as_a_checked_purchase(change):
    item = make_item()
    item.is_checked = True
    snapshot = item.regional_snapshot
    if change == "total": item.estimated_price = Decimal(999)
    if change == "quantity": item.required_quantity = Decimal(900)
    if change == "source": snapshot.quote_data["price_source"]["url"] = "https://example.invalid/"
    if change == "period": snapshot.quote_data["price_source"]["period"] = "2027-01"
    if change == "fingerprint": snapshot.quote_data["reference_fingerprint"] = "X" * 64
    if change == "package": snapshot.quote_data["package_quantity"] = "500"
    if change == "offer": snapshot.offer_id = uuid4()
    if change == "dimension": item.unit = "ml"
    assert frozen_regional_purchase_quote(item, as_of=DAY) is None


def test_too_old_or_future_national_dataset_is_not_a_current_quote():
    from app.services.uk_ons_pricing import quote_national_requirement
    for day in [date(2026, 10, 1)]:
        assert quote_national_requirement(food(), Decimal(500), "g", store_id=UK_STORES[0].id, as_of=day) is None
    fallback = quote_national_requirement(food(), Decimal(500), "g",
        store_id=UK_STORES[0].id, as_of=date(2027, 3, 1))
    assert fallback.price_source["provider"] == "uk_catalogue_estimate"
    assert fallback.price_is_estimated and fallback.last_verified is None
    assert make_item(food("Cukier"), "1").estimated_price is None  # Below a penny is not free.


def test_all_reviewed_links_resolve_real_seed_names_and_exact_ons_records():
    from app.services.uk_ons_pricing import _LINKS
    from app.services.uk_national_price_reference import reference_dataset
    seeds = {row[0] for row in PRODUCTS_DATA}
    ons = {row["name"] for row in reference_dataset()["records"]}
    assert set(_LINKS) <= seeds and set(_LINKS.values()) <= ons


from tests.test_regional_shopping import db, run, make_plan, loaded, _offer


def test_real_list_plan_comparison_check_and_pantry_share_the_same_reference(db):
    from app.api.v1.price_compare import _compare_uk_prices, compare_shopping_list_prices
    from app.models import Store, PantryItem
    from app.schemas.shopping_list import ShoppingListResponse
    from app.services.shopping_list_builder import ShoppingListBuilder
    from app.services.regional_shopping import complete_regional_items_to_pantry
    session, adapter, user, *_ = db
    product = food()
    session.add(product); session.commit()
    plan = make_plan(session, user, product, quantity="500")
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    shopping = loaded(session, shopping.id)
    response = ShoppingListResponse.model_validate(shopping)
    assert response.total_estimated_price == 1.57 and response.price_is_estimated
    line = response.items_by_department["Other"][0]
    assert line.package_quantity is None and line.package_count is None and line.regional_offer_id is None
    stores = [session.get(Store, store.id) for store in UK_STORES[:2]]
    for results in [run(_compare_uk_prices(adapter, plan, stores)), run(compare_shopping_list_prices(plan.id, adapter, user))]:
        assert len(results) == 2 and all(row.total_price == 1.57 for row in results)
        assert all(not row.is_cheapest and row.savings_vs_most_expensive == 0 for row in results)
        assert all(row.items[0].package_quantity is None for row in results)
    shopping.items[0].is_checked = True; session.commit()
    assert run(complete_regional_items_to_pantry(adapter, shopping, user.id)) == 1
    session.flush()
    from sqlalchemy import select
    stored = session.scalar(select(PantryItem).where(PantryItem.product_id == product.id))
    assert stored.quantity == 500 and stored.unit == "g"  # Not a fictional whole pack.


def test_reviewed_merchant_price_takes_priority_over_a_national_reference(db):
    from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
    from datetime import datetime, timezone
    session, adapter, user, *_ = db
    product = food(); session.add(product); session.commit()
    now = datetime.now(timezone.utc)
    run(import_reviewed_uk_catalogue(adapter, [_offer(product.id, "tesco", "reviewed-oats", "500", "1.10")],
        reviewer_user_id=user.id, reviewed_at=now, as_of=now.date()))
    from app.models import RegionalProductOffer
    from sqlalchemy import select
    offers = session.scalars(select(RegionalProductOffer).where(RegionalProductOffer.product_id == product.id)).all()
    item = ShoppingListItem(id=uuid4(), is_checked=False)
    apply_regional_item_quote(item, product=product, store_id=UK_STORES[0].id,
        quantity=Decimal(500), unit="g", offers=offers, as_of=now.date())
    assert item.estimated_price == Decimal("1.10") and item.regional_snapshot.offer_id is not None
