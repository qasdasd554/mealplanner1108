"""Static UK planning assumptions cover the same seed foods as PL, not live offers."""
from datetime import date
from decimal import Decimal
from uuid import uuid4

import pytest
from app.db.seed import PRODUCTS_DATA
from app.services.uk_catalogue_import import canonical_base_unit
from app.services.uk_catalogue_estimates import quote_static_requirement, MODEL_DAY
from app.services.regional_shopping import frozen_regional_purchase_quote
from tests.test_uk_ons_shopping import food


def test_all_390_canonical_foods_have_positive_gbp_planning_prices_not_packs():
    for name, *_ in PRODUCTS_DATA:
        product = food(name)
        unit = canonical_base_unit(product)
        quote = quote_static_requirement(product, Decimal(100), unit, store_id=uuid4(), as_of=MODEL_DAY)
        assert quote is not None, name
        assert quote.total_price > 0 and quote.currency_code == "GBP", name
        assert quote.offer_id is None and quote.package_quantity is None
        assert quote.last_verified is None and quote.price_is_estimated
        assert quote.price_source["provider"] == "uk_catalogue_estimate"
        assert quote.price_source["confirms_package"] is False
        assert quote.price_source["confirms_store_stock"] is False


@pytest.mark.parametrize("name,quantity,unit,cost", [
    ("Mąka pszenna", "500", "g", "0.30"),
    ("Sól", "100", "g", "0.10"),
    ("Szafran", "1", "g", "4.00"),
    ("Jajka", "100", "g", "0.60"),
    ("Ogórek", "150", "g", "0.80"),
])
def test_explicit_quantity_cost_never_confuses_pieces_and_grams(name, quantity, unit, cost):
    quote = quote_static_requirement(food(name), Decimal(quantity), unit, store_id=uuid4(), as_of=MODEL_DAY)
    assert quote.total_price == Decimal(cost)


@pytest.mark.parametrize("change", ["owner", "barcode", "name", "status", "unit"])
def test_foreign_authored_or_changed_identities_cannot_borrow_seed_estimates(change):
    product = food("Mąka pszenna")
    if change == "owner": product.created_by_user_id = uuid4()
    elif change == "barcode": product.barcode = "1234567890123"
    elif change == "name": product.name = "A different food"
    elif change == "status": product.review_status = "pending"
    else: product.unit = "ml"
    assert quote_static_requirement(product, Decimal(100), "g", store_id=uuid4(), as_of=MODEL_DAY) is None


@pytest.mark.parametrize("change", [None, "cost", "source", "quantity", "unit", "offer", "fingerprint"])
def test_checked_static_cost_is_preserved_and_corruption_rejected(change):
    from app.models import ShoppingListItem
    from app.services.regional_shopping import apply_regional_item_quote
    item = ShoppingListItem(id=uuid4(), is_checked=False)
    apply_regional_item_quote(item, product=food("Mąka pszenna"), store_id=uuid4(),
        quantity=Decimal(500), unit="g", offers=[], as_of=MODEL_DAY)
    item.is_checked = True
    snapshot = item.regional_snapshot
    if change == "cost": item.estimated_price = Decimal(999)
    elif change == "source": snapshot.quote_data["price_source"]["confirms_store_stock"] = True
    elif change == "quantity": item.required_quantity = Decimal(501)
    elif change == "unit": item.unit = "ml"
    elif change == "offer": snapshot.offer_id = uuid4()
    elif change == "fingerprint": snapshot.quote_data["reference_fingerprint"] = "0" * 64
    quote = frozen_regional_purchase_quote(item, as_of=date(2027, 1, 1))
    if change is None:
        assert quote.total_price == Decimal("0.30") and quote.offer_id is None
    else:
        assert quote is None


def test_static_store_multiplier_is_neutral_and_does_not_invent_cheapest_store():
    product = food("Mąka pszenna")
    prices = [quote_static_requirement(product, Decimal(1000), "g", store_id=uuid4(), as_of=MODEL_DAY).total_price for _ in range(10)]
    assert len(set(prices)) == 1


@pytest.mark.parametrize("name", ["Bulion warzywny", "Mleko skondensowane słodzone"])
def test_legacy_mixed_measures_use_original_system_dimension_without_fake_package(name):
    from app.services.product_measures import base_unit_for_product

    product = food(name)
    # Older seeds added liquid measures based on the name, even to gram foods.
    product.measure_options = [*product.measure_options,
        {"code": "lyzeczka", "base_unit": "ml", "base_quantity": 5}, None]
    assert base_unit_for_product(name, product.unit) == "g"
    assert canonical_base_unit(product) == "g"
    quote = quote_static_requirement(product, Decimal(100), "g", store_id=uuid4(), as_of=MODEL_DAY)
    assert quote is not None and quote.total_price > 0
    assert quote.package_quantity is None

    product.created_by_user_id = uuid4()
    with pytest.raises(ValueError, match="conflicting"):
        canonical_base_unit(product)
