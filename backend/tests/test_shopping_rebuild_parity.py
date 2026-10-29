"""PL/GB merge and recalculation must preserve quantities, history and manual rows."""
from datetime import date
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.api.v1 import shopping_lists as api
from app.models import MealPlan, PantryItem, ShoppingList, Store, StoreProduct
from app.services.shopping_list_builder import ShoppingListBuilder
from tests.test_manual_shopping_amounts import setup, add
from tests.test_runtime_async_boundaries import state


async def two_lists(state, checked=False):
    _, db, user, product, first_id = await setup(state)
    first = await db.get(MealPlan, first_id)
    second = MealPlan(id=uuid4(), user_id=user.id, store_id=first.store_id,
        start_date=date.today(), duration_days=1, meals_per_day=0,
        status="archived", preferences={"shopping_list_only": True})
    db.add(second)
    db.add(ShoppingList(id=uuid4(), meal_plan_id=second.id, store_id=first.store_id))
    await db.commit()
    for plan_id in (first_id, second.id):
        await add(db, user, product, plan_id, 200, "g")
        shopping = await api._get_shopping_list_or_404(plan_id, user, db, refresh=True)
        shopping.items[0].is_checked = checked
        await db.commit()
    return db, user, first_id, second.id


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_merge_reprices_combined_unbought_amount_once(state):
    db, user, first, second = await two_lists(state)
    result = await api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[first,second]),user,db)
    assert len(result.items) == 1
    assert result.items[0].required_quantity == 400
    assert result.items[0].estimated_price == Decimal(2)
    for source in (first,second):
        original = (await db.execute(select(ShoppingList).where(ShoppingList.meal_plan_id == source))).scalar_one()
        assert original.status == "merged"


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_merge_keeps_separately_bought_packages_and_prices(state):
    db,user,first,second = await two_lists(state,checked=True)
    result = await api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[first,second]),user,db)
    assert len(result.items) == 2
    assert all(item.is_checked and item.estimated_price == Decimal(2) for item in result.items)


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_recalculation_keeps_checked_generated_purchase_unchanged(state):
    _,db,user,_,plan_id = await setup(state)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    shopping.items[0].is_checked = True
    before = shopping.items[0].required_quantity, shopping.items[0].unit, shopping.items[0].estimated_price
    await db.commit()
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    assert len(shopping.items)==1 and shopping.items[0].is_checked
    assert (shopping.items[0].required_quantity,shopping.items[0].unit,shopping.items[0].estimated_price)==before


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_recalculation_respects_disabled_pantry_in_both_markets(state):
    _,db,user,product,plan_id = await setup(state)
    db.add(PantryItem(id=uuid4(),user_id=user.id,product_id=product.id,quantity=100,unit="g"))
    await db.commit()
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    assert not any(item.is_from_pantry for item in shopping.items)
    assert sum(item.required_quantity for item in shopping.items)==200


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_manual_extra_survives_store_recalculation_with_target_price(state):
    session,db,user,product,plan_id = await setup(state)
    await add(db,user,product,plan_id,100,"g")
    if user.country_code == "GB":
        from tests.uk_regional_fixtures import uk_store,reviewed_offer
        target = uk_store(session,slug="sainsburys")
        reviewed_offer(session,product,target,price="4")
    else:
        target = Store(id=uuid4(),name="Synthetic target",country_code="PL",currency_code="PLN")
        db.add(target)
        db.add(StoreProduct(id=uuid4(),store_id=target.id,product_id=product.id,price=4,is_available=True))
    plan = await db.get(MealPlan,plan_id)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    plan.store_id, shopping.store_id = target.id,target.id
    await db.commit()
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    manual = [item for item in shopping.items if not item.is_generated]
    assert len(manual)==1 and manual[0].required_quantity==100
    assert manual[0].estimated_price==Decimal(4)
    if user.country_code=="PL":
        assert manual[0].store_product.store_id==target.id


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_changed_bought_requirement_does_not_delete_purchase_history(state):
    from fastapi import HTTPException
    from app.models import RecipeIngredient, MealPlanEntry
    _,db,user,_,plan_id = await setup(state)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping = await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    row = shopping.items[0]
    row.is_checked=True
    original=(row.id,row.required_quantity,row.estimated_price)
    recipe_id=(await db.execute(select(MealPlanEntry.recipe_id).where(MealPlanEntry.meal_plan_id==plan_id))).scalar_one()
    ingredient=(await db.execute(select(RecipeIngredient).where(RecipeIngredient.recipe_id==recipe_id))).scalar_one()
    ingredient.quantity=350
    await db.commit()
    with pytest.raises(HTTPException) as caught:
        await ShoppingListBuilder(db).recalculate(shopping.id)
    assert caught.value.status_code==409
    await db.commit()
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    assert len(shopping.items)==1 and shopping.items[0].is_checked
    assert (shopping.items[0].id,shopping.items[0].required_quantity,shopping.items[0].estimated_price)==original


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_failed_plan_store_recalculation_rolls_back_the_store_change(state,monkeypatch):
    import httpx
    from fastapi import FastAPI,HTTPException
    from app.api.v1 import meal_plans
    from app.api.deps import get_current_user,get_db
    _,db,user,_,plan_id=await setup(state)
    old=(await db.get(MealPlan,plan_id)).store_id
    target=Store(id=uuid4(),name="Another test store",country_code=user.country_code,
        currency_code="GBP" if user.country_code=="GB" else "PLN")
    db.add(target)
    await db.commit()
    target_id=target.id
    async def fail(*args,**kwargs):
        raise HTTPException(status_code=409,detail="Synthetic recalculation failure")
    monkeypatch.setattr(ShoppingListBuilder,"recalculate",fail)
    app=FastAPI()
    app.include_router(meal_plans.router,prefix="/plans")
    user_id=user.id
    async def actor():
        return await db.get(type(user),user_id)
    async def database():
        try:
            yield db
        except Exception:
            await db.rollback()
            raise
    app.dependency_overrides[get_current_user]=actor
    app.dependency_overrides[get_db]=database
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url="http://test") as client:
        response=await client.put(f"/plans/{plan_id}/store",json={"store_id":str(target_id)})
        assert response.status_code==409,response.text
    plan=await db.get(MealPlan,plan_id)
    shopping=(await db.execute(select(ShoppingList).where(ShoppingList.meal_plan_id==plan_id))).scalar_one()
    assert plan.store_id==shopping.store_id==old


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_merge_rejects_storage_overflow_before_changing_sources(state):
    from fastapi import HTTPException
    from sqlalchemy import func
    db,user,first,second=await two_lists(state)
    for plan_id in (first,second):
        shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
        shopping.items[0].required_quantity=Decimal("6000000")
    await db.commit()
    before=(await db.execute(select(func.count()).select_from(ShoppingList))).scalar_one()
    with pytest.raises(HTTPException) as caught:
        await api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[first,second]),user,db)
    assert caught.value.status_code==409
    await db.commit()
    assert (await db.execute(select(func.count()).select_from(ShoppingList))).scalar_one()==before
    for plan_id in (first,second):
        shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
        assert shopping.status=="pending" and shopping.items[0].required_quantity==6000000


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_missing_canonical_pack_size_is_not_invented_during_recalculation(state):
    _,db,user,product,plan_id=await setup(state)
    product.default_quantity=None
    await db.commit()
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    row=shopping.items[0]
    if user.country_code=="PL":
        assert row.estimated_price is None
    else:
        # A reviewed local 500 g SKU remains independent of the canonical pack.
        assert row.estimated_price==Decimal(2)
        assert Decimal(row.regional_snapshot.quote_data["package_quantity"])==500


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_recalculation_does_not_price_an_unavailable_shop_offer(state):
    from app.models import RegionalProductOffer
    _,db,user,product,plan_id=await setup(state)
    if user.country_code=="PL":
        offer=(await db.execute(select(StoreProduct).where(StoreProduct.product_id==product.id))).scalar_one()
        offer.is_available=False
    else:
        offer=(await db.execute(select(RegionalProductOffer).where(RegionalProductOffer.product_id==product.id))).scalar_one()
        offer.availability_status="out_of_stock"
    await db.commit()
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    row=shopping.items[0]
    if user.country_code=="PL":
        assert row.estimated_price is None
    else:
        assert row.regional_snapshot.offer_id is None
    assert row.required_quantity==200


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_small_required_mass_is_not_rounded_down_to_zero_kg(state):
    from app.models import RecipeIngredient,MealPlanEntry
    from app.services.regional_requirements import to_regional_base_quantity
    _,db,user,product,plan_id=await setup(state)
    product.unit="kg"
    product.default_quantity=Decimal("0.5")
    recipe_id=(await db.execute(select(MealPlanEntry.recipe_id).where(MealPlanEntry.meal_plan_id==plan_id))).scalar_one()
    ingredient=(await db.execute(select(RecipeIngredient).where(RecipeIngredient.recipe_id==recipe_id))).scalar_one()
    ingredient.quantity=Decimal("0.1")
    await db.commit()
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    await ShoppingListBuilder(db).recalculate(shopping.id)
    shopping=await api._get_shopping_list_or_404(plan_id,user,db,refresh=True)
    row=shopping.items[0]
    assert to_regional_base_quantity(product,row.required_quantity,row.unit)==(Decimal("0.1"),"g")
    assert row.estimated_price==Decimal(2)
