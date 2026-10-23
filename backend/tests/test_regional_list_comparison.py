"""Actual UK shopping baskets: real SQLite/HTTP, no live retailer or DB access."""

from copy import deepcopy
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from sqlalchemy import delete, select

from app.api.deps import get_current_user, get_db
from app.api.v1.price_compare import router
from app.core.exceptions import AppException
from app.models import PantryItem, RegionalProductOffer, ShoppingListShare, Store, User
from app.schemas.shopping_list import ShoppingListResponse
from tests.test_regional_shopping import (
    UK_STORES, ShoppingListBuilder, api, db, loaded, make_plan, run,
)


def client_for(adapter, user):
    app = FastAPI()
    app.include_router(router, prefix="/api/v1/price-compare")
    app.include_router(api.router, prefix="/api/v1/shopping-lists")

    @app.exception_handler(AppException)
    async def app_error(_request, error):
        return JSONResponse(status_code=error.status_code, content={"detail": error.detail})

    async def database():
        yield adapter

    app.dependency_overrides[get_db] = database
    app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(app)


def list_compare(client, list_id):
    return client.get(f"/api/v1/price-compare/shopping-list/{list_id}")


def tesco(response):
    assert response.status_code == 200, response.text
    return next(row for row in response.json() if row["store_id"] == str(UK_STORES[0].id))


def make_shopping(db, *, quantity="600", include_pantry=False):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, quantity=quantity, include_pantry=include_pantry)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id, include_pantry=include_pantry))
    return plan, shopping


def test_actual_list_includes_manual_600g_instead_of_only_recipe_600g(db):
    session, adapter, user, product, _ = db
    plan, shopping = make_shopping(db)
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=600, unit="g"), user, adapter))
    assert ShoppingListResponse.model_validate(loaded(session, shopping.id)).total_estimated_price == 3.75
    with client_for(adapter, user) as client:
        # Preserve the established plan endpoint; the new list route fixes the
        # edited-basket mismatch rather than redefining plan comparisons.
        old = client.get(f"/api/v1/price-compare/{plan.id}")
        assert tesco(old)["total_price"] == 2.50
        actual = tesco(list_compare(client, plan.id))
    assert actual["total_price"] == 3.75 and actual["currency_code"] == "GBP"
    assert sum(row["quantity_needed"] for row in actual["items"]) == 1200
    assert actual["items"][0]["package_count"] == 3


def test_shopping_only_technical_plan_with_manual_product_is_supported(db):
    session, adapter, user, product, _ = db
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    run(api.add_item_to_shopping_list(shopping.meal_plan_id, api.AddItemRequest(product_id=product.id, quantity=600, unit="g"), user, adapter))
    with client_for(adapter, user) as client:
        assert client.get(f"/api/v1/price-compare/{shopping.meal_plan_id}").status_code == 404
        result = tesco(list_compare(client, shopping.meal_plan_id))
    assert result["total_price"] == 2.50 and result["items"][0]["quantity_needed"] == 600


def test_merged_technical_list_compares_retained_current_rows(db):
    _, adapter, user, _, _ = db
    sources = [make_shopping(db, quantity="200")[1] for _ in range(2)]
    merged = run(api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[value.meal_plan_id for value in sources]), user, adapter))
    with client_for(adapter, user) as client:
        result = tesco(list_compare(client, merged.meal_plan_id))
        assert list_compare(client, sources[0].meal_plan_id).status_code == 404
    assert result["total_price"] == 1.25 and result["items"][0]["quantity_needed"] == 400


@pytest.mark.parametrize("viewer_country,share_status,allowed", [
    ("GB", "accepted", True), ("PL", "accepted", True),
    ("GB", "pending", False), ("GB", None, False),
])
def test_owner_or_accepted_share_only_and_viewer_never_changes_list_currency(db, viewer_country, share_status, allowed):
    session, adapter, user, _, _ = db
    plan, _ = make_shopping(db)
    viewer = User(id=uuid4(), email=f"{uuid4()}@example.test", password_hash="fixture", country_code=viewer_country)
    session.add(viewer)
    if share_status is not None:
        session.add(ShoppingListShare(id=uuid4(), meal_plan_id=plan.id, shared_by_user_id=user.id,
                                     shared_with_user_id=viewer.id, status=share_status))
    session.commit()
    with client_for(adapter, viewer) as client:
        response = list_compare(client, plan.id)
    if allowed:
        assert tesco(response)["currency_code"] == "GBP"
    else:
        assert response.status_code == 404


def test_checked_purchase_is_frozen_across_stores_and_missing_live_offer(db):
    session, adapter, user, product, _ = db
    plan, shopping = make_shopping(db, quantity="100")
    checked = loaded(session, shopping.id).items[0]
    checked.is_checked = True
    frozen = deepcopy(checked.regional_snapshot.quote_data)
    session.commit()
    session.execute(delete(RegionalProductOffer).where(RegionalProductOffer.id == checked.regional_snapshot.offer_id))
    session.commit()
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=100, unit="g"), user, adapter))
    with client_for(adapter, user) as client:
        result = list_compare(client, plan.id)
    assert result.status_code == 200
    sains = next(row for row in result.json() if row["store_id"] == str(UK_STORES[1].id))
    assert sains["total_price"] == 3.05  # bought Tesco £1.25 + new Sains £1.80
    checked_quote = next(row for row in sains["items"] if row["is_checked"])
    assert checked_quote["package_quantity"] == 500 and checked_quote["purchased_quantity"] == 500
    assert checked_quote["price_in_store"] == 1.25
    assert checked_quote["price_source"] == frozen["price_source"]


def test_pantry_rows_are_zero_without_a_second_pantry_deduction(db):
    session, adapter, user, product, _ = db
    session.add(PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("400"), unit="g"))
    session.commit()
    plan, shopping = make_shopping(db, include_pantry=True)
    # Change the current inventory without syncing the persisted shopping rows:
    # comparison is the current list, not another recipe/pantry recomputation.
    pantry = session.scalar(select(PantryItem).where(PantryItem.product_id == product.id))
    pantry.quantity = Decimal("1000")
    session.commit()
    with client_for(adapter, user) as client:
        result = tesco(list_compare(client, plan.id))
    assert result["total_price"] == 1.25
    assert sum(row["quantity_needed"] for row in result["items"] if row["is_from_pantry"]) == 400
    assert sum(row["quantity_needed"] for row in result["items"] if not row["is_from_pantry"]) == 200


def test_custom_unknown_line_makes_every_total_null_not_free_or_cheapest(db):
    _, adapter, user, _, _ = db
    plan, _ = make_shopping(db)
    run(api.add_custom_item_to_shopping_list(plan.id, api.AddCustomItemRequest(name="Batteries"), user, adapter))
    with client_for(adapter, user) as client:
        response = list_compare(client, plan.id)
    assert response.status_code == 200
    for result in response.json():
        assert result["total_price"] is None and result["is_complete"] is False
        assert result["is_cheapest"] is False and result["savings_vs_most_expensive"] == 0
        assert "Batteries" in result["missing_products"]


def test_empty_list_returns_no_misleading_free_store_winner(db):
    _, adapter, user, _, _ = db
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    with client_for(adapter, user) as client:
        response = list_compare(client, shopping.meal_plan_id)
    assert response.status_code == 200 and response.json() == []


@pytest.mark.parametrize("status,expected", [("completed", 409), ("merged", 404)])
def test_closed_lists_cannot_offer_a_store_switch(db, status, expected):
    session, adapter, user, _, _ = db
    plan, shopping = make_shopping(db)
    shopping.status = status
    session.commit()
    with client_for(adapter, user) as client:
        response = list_compare(client, plan.id)
    assert response.status_code == expected


def test_invalid_source_market_is_not_relabelled_gbp(db):
    session, adapter, user, _, _ = db
    plan, shopping = make_shopping(db)
    foreign = Store(id=uuid4(), name="PL only", country_code="PL", currency_code="PLN")
    session.add(foreign)
    session.flush()
    shopping.store_id = foreign.id
    session.commit()
    with client_for(adapter, user) as client:
        response = list_compare(client, plan.id)
    assert response.status_code == 404


def test_http_compare_then_switch_prices_exactly_the_same_current_basket(db):
    session, adapter, user, product, _ = db
    plan, shopping = make_shopping(db)
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(
        product_id=product.id, quantity=600, unit="g",
    ), user, adapter))
    with client_for(adapter, user) as client:
        comparisons = list_compare(client, plan.id)
        assert comparisons.status_code == 200
        selected = next(row for row in comparisons.json()
                        if row["store_id"] == str(UK_STORES[1].id))
        switched = client.put(f"/api/v1/shopping-lists/{plan.id}/store",
                              json={"store_id": str(UK_STORES[1].id)})
        assert switched.status_code == 200, switched.text
        body = switched.json()
        assert body["currency_code"] == "GBP"
        assert body["store_id"] == selected["store_id"]
        assert body["meal_plan_id"] == str(plan.id)
        assert body["total_estimated_price"] == selected["total_price"] == 3.60
        assert sum(row["required_quantity"] for values in body["items_by_department"].values()
                   for row in values) == 1200
        # The public identifier is deliberately not the database row UUID.
        assert client.put(f"/api/v1/shopping-lists/{shopping.id}/store",
                          json={"store_id": str(UK_STORES[0].id)}).status_code == 404
