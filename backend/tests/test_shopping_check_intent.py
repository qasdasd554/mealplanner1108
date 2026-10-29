"""A repeated purchase confirmation must not undo a successful first write."""
from decimal import Decimal
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI

from app.api.deps import get_current_user, get_db
from app.api.v1.shopping_lists import router
from app.models import MealPlan, Product, ShoppingList, ShoppingListItem, ShoppingListShare, StoreProduct, User
from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
from tests.test_runtime_async_boundaries import state


async def setup_http(state):
    _, db, (owner_id, product_id, plan_id, _, _) = state
    plan = await db.get(MealPlan, plan_id)
    owner = await db.get(User, owner_id)
    guest = User(id=uuid4(), email="shared-check@example.invalid", password_hash="test",
                 country_code="PL" if owner.country_code == "GB" else "GB")
    guest_id = guest.id
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan_id, store_id=plan.store_id)
    item = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, required_quantity=100,
        unit="g", is_checked=False, is_from_pantry=False)
    if owner.country_code == "GB":
        product = await db.get(Product, product_id)
        apply_regional_item_quote(item, product=product, store_id=plan.store_id,
            quantity=Decimal(100), unit="g", offers=[], as_of=regional_pricing_date())
    else:
        offer = StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=product_id,
                             price=3, is_available=True)
        db.add(offer)
        item.store_product_id = offer.id
    db.add(guest)
    db.add(shopping)
    db.add(item)
    db.add(ShoppingListShare(id=uuid4(), meal_plan_id=plan_id, shared_by_user_id=owner_id,
        shared_with_user_id=guest_id, status="accepted"))
    await db.commit()
    acting = {"id": owner_id}
    async def user_dependency():
        return await db.get(User, acting["id"])
    async def db_dependency():
        return db
    app = FastAPI()
    app.include_router(router, prefix="/shopping")
    app.dependency_overrides[get_current_user] = user_dependency
    app.dependency_overrides[get_db] = db_dependency
    return app, acting, owner_id, guest_id, f"/shopping/{plan_id}/items/{item.id}/check"


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("desired", [False, True])
async def test_retry_and_two_shared_users_keep_the_requested_purchase_state(state, desired):
    app, acting, owner_id, guest_id, path = await setup_http(state)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Both users saw the same original state. Repeat the same intent as
        # after a lost response; do not reinterpret it as another toggle.
        for actor in (owner_id, guest_id, owner_id):
            acting["id"] = actor
            response = await client.put(path, json={"is_checked": desired})
            assert response.status_code == 200, response.text
            assert response.json()["is_checked"] is desired


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_old_client_without_purchase_body_keeps_legacy_toggle_support(state):
    app, _, _, _, path = await setup_http(state)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        assert (await client.put(path)).json()["is_checked"] is True
        assert (await client.put(path)).json()["is_checked"] is False


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_purchase_state_requires_a_real_boolean(state):
    app, _, _, _, path = await setup_http(state)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        result = await client.put(path, json={"is_checked": "false"})
        assert result.status_code == 422
