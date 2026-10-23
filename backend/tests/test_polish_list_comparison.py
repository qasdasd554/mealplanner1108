"""Recipe/manual lists must compare their saved basket, not a hidden plan."""

from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models import Store, StoreProduct, ShoppingListItem, ShoppingListShare, User
from tests.test_regional_shopping import db, run, api, loaded, make_plan, ShoppingListBuilder, UK_STORES
from tests.test_regional_list_comparison import client_for, list_compare


@pytest.fixture
def pl(db):
    session, adapter, user, product, _ = db
    user = User(id=uuid4(), email="pl-shopping@example.test", password_hash="fixture", role="admin", country_code="PL", is_premium=True)
    session.add(user)
    product.name, product.default_quantity = "Mąka", Decimal("500")
    for i, store in enumerate(session.scalars(select(Store)).all()):
        store.country_code, store.currency_code = "PL", "PLN"
        session.add(StoreProduct(id=uuid4(), store_id=store.id, product_id=product.id,
                                 price=Decimal("5") + i, is_available=True))
    session.commit()
    return session, adapter, user, product, db[-1]


def test_polish_technical_recipe_list_compares_without_visible_plan(pl):
    session, adapter, user, product, _ = pl
    plan = make_plan(session, user, product, quantity="600", include_pantry=False)
    plan.status = "archived"
    session.commit()
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id, include_pantry=False))
    with client_for(adapter, user) as client:
        result = list_compare(client, plan.id)
    assert result.status_code == 200, result.text
    assert len(result.json()) == 2
    for row in result.json():
        assert row["currency_code"] == "PLN" and row["is_complete"]
        assert row["items"][0]["quantity_needed"] == 600
        assert row["items"][0]["package_count"] == 2
    assert len(loaded(session, shopping.id).items) == 1


def test_polish_empty_manual_list_can_compare_and_switch_actual_rows(pl):
    session, adapter, user, product, _ = pl
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    run(api.add_item_to_shopping_list(shopping.meal_plan_id,
        api.AddItemRequest(product_id=product.id, quantity=600, unit="g"), user, adapter))
    with client_for(adapter, user) as client:
        response = list_compare(client, shopping.meal_plan_id)
        assert response.status_code == 200, response.text
        target = next(row for row in response.json() if row["store_id"] == str(UK_STORES[1].id))
        changed = client.put(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/store",
                             json={"store_id": str(UK_STORES[1].id)})
    assert changed.status_code == 200, changed.text
    assert changed.json()["total_estimated_price"] == target["total_price"]
    rows = loaded(session, shopping.id).items
    assert len(rows) == 1 and rows[0].required_quantity == 600 and rows[0].unit == "g"


def test_polish_unknown_custom_line_is_not_a_free_winning_basket(pl):
    _, adapter, user, _, _ = pl
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    run(api.add_custom_item_to_shopping_list(shopping.meal_plan_id, api.AddCustomItemRequest(name="Nieznany zakup"), user, adapter))
    with client_for(adapter, user) as client:
        response = list_compare(client, shopping.meal_plan_id)
    assert response.status_code == 200, response.text
    for row in response.json():
        assert row["total_price"] is None and not row["is_cheapest"] and not row["is_complete"]


def test_polish_list_access_denial_and_unpriced_store_switch_preserve_basket(pl):
    session, adapter, user, product, _ = pl
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    run(api.add_item_to_shopping_list(shopping.meal_plan_id,
        api.AddItemRequest(product_id=product.id, quantity=600, unit="g"), user, adapter))
    other = User(id=uuid4(), email="outsider@example.test", password_hash="fixture", country_code="PL")
    session.add(other)
    target = session.scalar(select(StoreProduct).where(StoreProduct.store_id == UK_STORES[1].id))
    target.is_available = False
    session.commit()
    with client_for(adapter, other) as client:
        assert list_compare(client, shopping.meal_plan_id).status_code == 404
    old_row = loaded(session, shopping.id).items[0]
    before = old_row.id, old_row.required_quantity, old_row.unit, old_row.is_checked
    with client_for(adapter, user) as client:
        response = client.put(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/store",
                          json={"store_id": str(UK_STORES[1].id)})
    assert response.status_code == 200, response.text
    changed = loaded(session, shopping.id)
    assert changed.store_id == UK_STORES[1].id
    row = changed.items[0]
    assert (row.id, row.required_quantity, row.unit, row.is_checked) == before
    assert row.store_product.product_id == product.id
    assert row.estimated_price is None
    assert response.json()["total_estimated_price"] is None
    assert response.json()["has_unpriced_items"] is True


def test_polish_custom_unknown_rows_can_change_shop_without_becoming_free(pl):
    session, adapter, user, _, _ = pl
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    for name in ("Nieznany zakup", "Drugi własny zakup"):
        run(api.add_custom_item_to_shopping_list(shopping.meal_plan_id, api.AddCustomItemRequest(name=name), user, adapter))
    before = [(row.id, row.custom_name, row.required_quantity, row.unit) for row in loaded(session, shopping.id).items]
    with client_for(adapter, user) as client:
        response = client.put(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/store", json={"store_id": str(UK_STORES[1].id)})
        comparison = list_compare(client, shopping.meal_plan_id)
    assert response.status_code == 200, response.text
    assert response.json()["total_estimated_price"] is None
    assert [(row.id, row.custom_name, row.required_quantity, row.unit) for row in loaded(session, shopping.id).items] == before
    assert all(row["total_price"] is None and not row["is_cheapest"] for row in comparison.json())
