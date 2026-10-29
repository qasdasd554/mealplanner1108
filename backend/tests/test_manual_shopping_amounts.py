"""Real ORM parity checks for manual shopping amounts, pack cost and pantry transfer."""
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1 import shopping_lists as api
from app.models import MealPlan, PantryItem, Product, ShoppingList, StoreProduct, User
from tests.test_runtime_async_boundaries import state


async def setup(state):
    session, db, (user_id, product_id, plan_id, _, _) = state
    user = await db.get(User, user_id)
    product = await db.get(Product, product_id)
    product.unit = "g"
    product.default_quantity = Decimal(500)
    product.serving_quantity = 500
    product.measure_options = [{"code": "g", "base_unit": "g", "base_quantity": 1},
        {"code": "opak", "base_unit": "g", "base_quantity": 500}]
    plan = await db.get(MealPlan, plan_id)
    if user.country_code == "PL":
        db.add(StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=product_id,
            price=Decimal(2), is_available=True))
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan_id, store_id=plan.store_id)
    db.add(shopping)
    await db.commit()
    return session, db, user, product, plan_id


async def add(db, user, product, plan_id, quantity, unit):
    return await api.add_item_to_shopping_list(plan_id,
        api.AddItemRequest(product_id=product.id, quantity=quantity, unit=unit), user, db)


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_manual_amount_prices_all_required_packages_and_combines_dimensions(state):
    _, db, user, product, plan_id = await setup(state)
    await add(db, user, product, plan_id, 250, "g")
    await add(db, user, product, plan_id, 1, "opak")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    assert len(shopping.items) == 1
    row = shopping.items[0]
    assert (row.required_quantity, row.unit, row.estimated_price) == (Decimal(750), "g", Decimal(4))


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_manual_large_amount_prices_two_packs_on_first_add(state):
    _, db, user, product, plan_id = await setup(state)
    await add(db, user, product, plan_id, 600, "g")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    assert shopping.items[0].estimated_price == Decimal(4)


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_manual_extra_does_not_mutate_already_bought_quantity(state):
    _, db, user, product, plan_id = await setup(state)
    await add(db, user, product, plan_id, 250, "g")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    row = shopping.items[0]
    row.is_checked = True
    await db.commit()
    await add(db, user, product, plan_id, 250, "g")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    assert len(shopping.items) == 2
    assert sorted((r.is_checked, r.required_quantity) for r in shopping.items) == [(False, 250), (True, 250)]


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_completed_list_cannot_be_modified_by_manual_append(state):
    _, db, user, product, plan_id = await setup(state)
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    shopping.status = "completed"
    await db.commit()
    with pytest.raises(HTTPException) as caught:
        await add(db, user, product, plan_id, 100, "g")
    assert caught.value.status_code == 409
    assert not (await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)).items


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_completion_adds_bought_pack_mass_to_existing_kg_and_retry_is_safe(state):
    _, db, user, product, plan_id = await setup(state)
    await add(db, user, product, plan_id, 600, "g")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    shopping.items[0].is_checked = True
    db.add(PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("0.25"), unit="kg"))
    await db.commit()
    await api.complete_shopping_list(plan_id, True, user, db)
    retry = await api.complete_shopping_list(plan_id, True, user, db)
    pantry = (await db.execute(select(PantryItem).where(PantryItem.user_id == user.id))).scalar_one()
    assert (pantry.quantity, pantry.unit) == (Decimal(1250), "g")
    assert retry["moved_to_pantry"] == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_unproven_mass_volume_conversion_remains_separate_and_unpriced(state):
    _, db, user, product, plan_id = await setup(state)
    await add(db, user, product, plan_id, 100, "g")
    await add(db, user, product, plan_id, 50, "ml")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    assert len(shopping.items) == 2
    unknown = next(row for row in shopping.items if row.unit == "ml")
    assert unknown.required_quantity == 50 and unknown.estimated_price is None


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_incompatible_pantry_unit_prevents_the_entire_transfer(state):
    session, db, user, product, plan_id = await setup(state)
    plan = await db.get(MealPlan, plan_id)
    second = Product(id=uuid4(), name="Synthetic second food", unit="g", default_quantity=500,
        serving_quantity=500, review_status="approved", measure_options=product.measure_options)
    db.add(second)
    await db.flush()
    if user.country_code == "PL":
        db.add(StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=second.id,
            price=2, is_available=True))
    else:
        from app.models import Store
        from tests.uk_regional_fixtures import reviewed_offer
        reviewed_offer(session, second, await db.get(Store, plan.store_id))
    await db.commit()
    for food in (product, second):
        await add(db, user, food, plan_id, 100, "g")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    for row in shopping.items:
        row.is_checked = True
    db.add(PantryItem(id=uuid4(), user_id=user.id, product_id=second.id, quantity=3, unit="ml"))
    await db.commit()
    with pytest.raises(HTTPException) as caught:
        await api.complete_shopping_list(plan_id, True, user, db)
    assert caught.value.status_code == 409
    # Even if an outer caller commits after handling the failure, no earlier row leaked.
    await db.commit()
    rows = (await db.execute(select(PantryItem).where(PantryItem.user_id == user.id))).scalars().all()
    assert [(r.product_id, r.quantity, r.unit) for r in rows] == [(second.id, 3, "ml")]
    assert shopping.status == "pending"
    await api.complete_shopping_list(plan_id, False, user, db)
    assert shopping.status == "completed"


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_custom_append_preserves_bought_history_and_completed_state(state):
    _, db, user, _, plan_id = await setup(state)
    payload = api.AddCustomItemRequest(name="Kitchen towels", quantity=2, unit="szt")
    await api.add_custom_item_to_shopping_list(plan_id, payload, user, db)
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    shopping.items[0].is_checked = True
    await db.commit()
    await api.add_custom_item_to_shopping_list(plan_id, payload, user, db)
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    assert sorted((r.is_checked, r.required_quantity) for r in shopping.items) == [(False, 2), (True, 2)]
    shopping.status = "completed"
    await db.commit()
    with pytest.raises(HTTPException) as caught:
        await api.add_custom_item_to_shopping_list(plan_id, payload, user, db)
    assert caught.value.status_code == 409


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_summary_keeps_unknown_prices_unknown_in_both_markets(state):
    _, db, user, _, plan_id = await setup(state)
    await api.add_custom_item_to_shopping_list(plan_id,
        api.AddCustomItemRequest(name="Unpriced purchase"), user, db)
    summary = await api.get_shopping_list_summary(plan_id, user, db)
    assert summary.has_unpriced_items
    assert summary.total_estimated_price is None and summary.remaining_price is None
    assert summary.checked_price == 0
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    shopping.items[0].is_checked = True
    await db.commit()
    summary = await api.get_shopping_list_summary(plan_id, user, db)
    assert summary.total_estimated_price is None and summary.checked_price is None
    assert summary.remaining_price == 0
    assert summary.currency_code == ("GBP" if user.country_code == "GB" else "PLN")


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_unit_conversion_happens_before_storage_rounding(state):
    _, db, user, product, plan_id = await setup(state)
    await add(db, user, product, plan_id, 0.0001, "kg")
    shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
    assert (shopping.items[0].required_quantity, shopping.items[0].unit) == (Decimal("0.100"), "g")


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_http_manual_append_and_summary_serialize_the_same_amount_and_cost(state):
    import httpx
    from fastapi import FastAPI
    from app.api.deps import get_current_user, get_db
    _, db, user, product, plan_id = await setup(state)
    app = FastAPI()
    app.include_router(api.router, prefix="/shopping")
    async def user_dependency():
        return user
    async def db_dependency():
        return db
    app.dependency_overrides[get_current_user] = user_dependency
    app.dependency_overrides[get_db] = db_dependency
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        for amount, unit in [(250, "g"), (1, "opak")]:
            response = await client.post(f"/shopping/{plan_id}/items", json={
                "product_id": str(product.id), "quantity": amount, "unit": unit})
            assert response.status_code == 201, response.text
        response = await client.get(f"/shopping/{plan_id}")
        assert response.status_code == 200, response.text
        body = response.json()
        rows = [row for group in body["items_by_department"].values() for row in group]
        assert [(row["required_quantity"], row["unit"], row["estimated_price"]) for row in rows] == [(750, "g", 4)]
        assert body["total_estimated_price"] == 4
        assert body["currency_code"] == ("GBP" if user.country_code == "GB" else "PLN")
        summary = await client.get(f"/shopping/{plan_id}/summary")
        assert summary.status_code == 200, summary.text
        assert summary.json()["total_estimated_price"] == 4
