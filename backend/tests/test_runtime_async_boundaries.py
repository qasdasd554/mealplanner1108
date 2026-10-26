"""Real ORM regression tests: forbid IO hidden behind a plain attribute read.

Ordinary synchronous adapters silently load relationships, masking asyncpg's
MissingGreenlet in production. This adapter permits ORM loads only inside
explicit awaited session operations, including after rollback expiration.
"""
from contextlib import contextmanager
from datetime import date
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import BackgroundTasks
from sqlalchemy import create_engine, event, select
from sqlalchemy.exc import MissingGreenlet
from sqlalchemy.orm import Session

from app.api.v1 import food_log, meal_plans, pantry, products, shopping_lists
from app.models import Base, MealPlan, MealPlanEntry, Product, Recipe, RecipeIngredient, ShoppingList, ShoppingListItem, Store, StoreProduct, User
from app.schemas.food_log import FoodLogEntryCreate
from app.schemas.meal_plan import MealPlanResponse
from tests.sqlite_uuid_compat import supply_sqlite_uuid_defaults
from tests.test_regional_shopping import AsyncDB
from tests.test_uk_ons_shopping import food
from tests.uk_regional_fixtures import reviewed_offer, uk_store


class GuardedDB(AsyncDB):
    def __init__(self, session):
        super().__init__(session)
        self.in_awaited_operation = False
        self.rollbacks = 0

        @event.listens_for(session, "do_orm_execute")
        def prevent_implicit_io(state):
            if (state.is_relationship_load or state.is_column_load) and not self.in_awaited_operation:
                raise MissingGreenlet("Implicit ORM IO outside an awaited session operation")

    @contextmanager
    def allowed(self):
        previous = self.in_awaited_operation
        self.in_awaited_operation = True
        try:
            yield
        finally:
            self.in_awaited_operation = previous

    async def execute(self, *args, **kwargs):
        with self.allowed():
            result = await super().execute(*args, **kwargs)
            # AsyncSession.execute buffers selectin loaders before returning;
            # synchronous ORM results otherwise defer them until iteration.
            return result.freeze()() if getattr(result, "returns_rows", True) else result

    async def get(self, *args, **kwargs):
        with self.allowed():
            return await super().get(*args, **kwargs)

    async def scalars(self, *args, **kwargs):
        return (await self.execute(*args, **kwargs)).scalars()

    async def flush(self):
        with self.allowed():
            await super().flush()

    async def commit(self):
        with self.allowed():
            await super().commit()

    async def refresh(self, *args, **kwargs):
        with self.allowed():
            await super().refresh(*args, **kwargs)

    async def rollback(self):
        self.rollbacks += 1
        self.session.rollback()


@pytest.fixture
def state(request):
    country = getattr(request, "param", "GB")
    engine = create_engine("sqlite:///:memory:")
    @event.listens_for(engine, "connect")
    def uuid_function(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid4().hex)
        connection.create_function("hashtext", 1, lambda _: 0)
        connection.create_function("pg_advisory_xact_lock", 1, lambda _: None)
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        supply_sqlite_uuid_defaults(session)
        user = User(id=uuid4(), email="async-boundaries@example.test", password_hash="fixture",
                    country_code=country, role="user")
        product = food("Mąka pszenna")
        product.barcode = "5010142008692"
        product.serving_quantity = 500
        session.add_all([user, product])
        if country == "GB":
            shop = uk_store(session, slug="tesco")
            reviewed_offer(session, product, shop)
        else:
            shop = Store(id=uuid4(), name="PL fixture", country_code="PL", currency_code="PLN")
            session.add(shop)
        recipes = [Recipe(id=uuid4(), name=name, meal_type="obiad", servings=2,
                          nutrition_total={"kcal": 720, "protein": 20, "fat": 4, "carbs": 140})
                   for name in ("First recipe", "Replacement recipe")]
        session.add_all(recipes)
        session.flush()
        for index, recipe in enumerate(recipes):
            session.add(RecipeIngredient(id=uuid4(), recipe_id=recipe.id, product_id=product.id,
                                         quantity=200 + index * 150, unit="g", is_optional=False))
        plan = MealPlan(id=uuid4(), user_id=user.id, store_id=shop.id, start_date=date.today(),
                        duration_days=7, meals_per_day=1, status="active",
                        preferences={"include_pantry": False})
        session.add(plan)
        session.flush()
        entry = MealPlanEntry(id=uuid4(), meal_plan_id=plan.id, recipe_id=recipes[0].id,
                              day_number=1, meal_slot="obiad", servings_multiplier=1)
        session.add(entry)
        session.commit()
        ids = user.id, product.id, plan.id, entry.id, recipes[1].id
        session.expunge_all()
        adapter = GuardedDB(session)
        yield session, adapter, ids
    engine.dispose()


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_plan_swap_loads_ingredients_and_returns_the_new_recipe_without_implicit_io(state):
    session, db, (user_id, _, plan_id, entry_id, replacement_id) = state
    user = await db.get(User, user_id)
    # Deliberately prime the old relationship, as rebuilding a list can do.
    from sqlalchemy.orm import selectinload
    primed_entry = (await db.execute(select(MealPlanEntry).options(selectinload(MealPlanEntry.recipe))
                     .where(MealPlanEntry.id == entry_id))).scalar_one()
    assert primed_entry.recipe.id != replacement_id
    result = await meal_plans.swap_recipe_in_plan(plan_id, entry_id,
        meal_plans.RecipeSwap(recipe_id=replacement_id), user, db)
    response = MealPlanResponse.model_validate(result)
    assert response.entries[0].recipe.id == replacement_id


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_cached_scan_can_be_saved_to_pantry_then_diary_without_expiring_auth(state):
    session, db, (user_id, product_id, _, _, _) = state
    user = await db.get(User, user_id)
    tasks = BackgroundTasks()
    lookup = await products.lookup_barcode("5010142008692", tasks, db=db, current_user=user)
    assert lookup.found
    # A separate HTTP request re-authenticates, so explicitly reload here too.
    user = await db.get(User, user_id)
    write_tasks = BackgroundTasks()
    result = await pantry.add_pantry_item_from_barcode(
        pantry.AddPantryBarcodeRequest(barcode="5010142008692", quantity=100, unit="g"), user, db,
        background_tasks=write_tasks)
    response = pantry.PantryItemResponse.model_validate(result)
    assert response.product.id == product_id and response.quantity == 100
    assert db.rollbacks == (1 if user.country_code == "GB" else 0)
    if user.country_code == "GB":
        assert write_tasks.tasks, "UK refresh must remain scheduled after the write request"
    diary = await food_log.create_food_log_entry(FoodLogEntryCreate(
        date=date.today(), meal_type="obiad", custom_name="Scanned flour",
        calories=lookup.kcal_per_100, protein=lookup.protein_per_100,
        fat=lookup.fat_per_100, carbs=lookup.carbs_per_100,
        amount_value=100, amount_unit="g"), db, user)
    assert diary.calories == lookup.kcal_per_100 > 0 and diary.amount_value == 100


@pytest.mark.asyncio
async def test_diary_nutrition_edit_with_recipe_does_not_lazy_load_recipe_name(state):
    _, db, (user_id, _, _, _, recipe_id) = state
    user = await db.get(User, user_id)
    entry = await food_log.create_food_log_entry(FoodLogEntryCreate(
        date=date.today(), meal_type="obiad", recipe_id=recipe_id), db, user)
    db.session.expunge_all()
    user = await db.get(User, user_id)
    result = await food_log.update_food_log_entry_nutrition(entry.id,
        food_log.FoodLogNutritionUpdate(calories=150, protein=5, fat=3, carbs=20), db, user)
    from app.schemas.food_log import FoodLogEntryResponse
    response = FoodLogEntryResponse.model_validate(result)
    assert response.calories == 150 and response.recipe_name == "Replacement recipe"


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_swapping_recipe_rebuilds_existing_list_with_new_amount_without_hidden_io(state):
    session, db, (user_id, product_id, plan_id, entry_id, recipe_id) = state
    user = await db.get(User, user_id)
    plan = await db.get(MealPlan, plan_id)
    shop_id = plan.store_id
    db.add(StoreProduct(id=uuid4(), product_id=product_id, store_id=shop_id,
                        price=Decimal("3.00"), is_available=True))
    await db.commit()
    from app.services.shopping_list_builder import ShoppingListBuilder
    shopping = await ShoppingListBuilder(db).build_from_meal_plan(plan_id)
    assert shopping.id is not None
    result = await meal_plans.swap_recipe_in_plan(plan_id, entry_id,
        meal_plans.RecipeSwap(recipe_id=recipe_id), user, db)
    assert MealPlanResponse.model_validate(result).entries[0].recipe.id == recipe_id
    response = await shopping_lists.get_shopping_list(plan_id, user, db)
    from app.schemas.shopping_list import ShoppingListResponse
    parsed = ShoppingListResponse.model_validate(response)
    quantities = [item.required_quantity * (1000 if item.unit in {"kg", "l"} else 1)
                  for group in parsed.items_by_department.values()
                  for item in group if not item.is_from_pantry]
    assert quantities == [350]


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
@pytest.mark.parametrize("available", [True, False])
async def test_substitution_endpoint_localizes_rejections_and_serializes_success(state, available):
    session, db, (user_id, product_id, plan_id, _, _) = state
    user = await db.get(User, user_id)
    plan = await db.get(MealPlan, plan_id)
    selected = food("Makaron spaghetti")
    db.add(selected)
    await db.flush()
    if user.country_code == "GB" and available:
        with db.allowed():
            reviewed_offer(session, selected, await db.get(Store, plan.store_id))
    original_sp = StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=product_id, price=3)
    db.add(original_sp)
    if user.country_code == "PL":
        db.add(StoreProduct(id=uuid4(), store_id=plan.store_id, product_id=selected.id,
                            price=4, is_available=available))
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan_id, store_id=plan.store_id)
    db.add(shopping)
    await db.flush()
    item = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id,
                            store_product_id=original_sp.id, required_quantity=100,
                            unit="g", is_checked=False, is_from_pantry=False)
    db.add(item)
    await db.commit()
    item_id, selected_id, country = item.id, selected.id, user.country_code
    session.expunge_all()
    user = await db.get(User, user_id)
    request = shopping_lists.SubstituteRequest(substitute_product_id=selected_id)
    if available:
        result = await shopping_lists.substitute_item(plan_id, item_id, request, user, db)
        from app.schemas.shopping_list import ShoppingListItemResponse
        response = ShoppingListItemResponse.model_validate(result)
        assert response.product_id == selected_id and response.estimated_price > 0
        assert response.currency_code == ("GBP" if country == "GB" else "PLN")
    else:
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as failure:
            await shopping_lists.substitute_item(plan_id, item_id, request, user, db)
        assert failure.value.status_code == 409
        assert str(selected_id) not in failure.value.detail
        assert failure.value.detail.startswith("This alternative" if country == "GB" else "Ten zamiennik")


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_real_http_cached_barcode_pantry_and_diary_keep_macros_and_no_internal_flags(state, monkeypatch):
    import httpx
    from fastapi import FastAPI
    from unittest.mock import AsyncMock
    from app.api.deps import get_current_user, get_db
    from app.services import off_on_demand

    _, db, (user_id, _, _, _, _) = state
    monkeypatch.setattr(off_on_demand, "refresh_requested_off_product", AsyncMock())
    app = FastAPI()
    app.include_router(products.router, prefix="/products")
    app.include_router(pantry.router, prefix="/pantry")
    app.include_router(food_log.router, prefix="/food-log")
    async def current_actor():
        return await db.get(User, user_id)
    async def database():
        yield db
    app.dependency_overrides[get_current_user] = current_actor
    app.dependency_overrides[get_db] = database
    parameters = app.openapi()["paths"]["/products/barcode/{barcode}"]["get"]["parameters"]
    assert [item["name"] for item in parameters] == ["barcode"]
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        scanned = await client.get("/products/barcode/5010142008692")
        assert scanned.status_code == 200
        scanned_data = scanned.json()
        added = await client.post("/pantry/from-barcode", json={
            "barcode": "5010142008692", "quantity": 100, "unit": "g"})
        assert added.status_code == 201, added.text
        assert added.json()["product"]["nutrition_per_100"]["kcal"] == scanned_data["kcal_per_100"]
        logged = await client.post("/food-log/", json={
            "date": date.today().isoformat(), "meal_type": "obiad", "custom_name": scanned_data["name"],
            "calories": scanned_data["kcal_per_100"], "protein": scanned_data["protein_per_100"],
            "fat": scanned_data["fat_per_100"], "carbs": scanned_data["carbs_per_100"],
            "amount_value": 100, "amount_unit": "g"})
        assert logged.status_code == 201, logged.text
        assert logged.json()["calories"] == scanned_data["kcal_per_100"] > 0


@pytest.mark.asyncio
@pytest.mark.parametrize("unit", ["g", "ml"])
async def test_repeated_barcode_save_keeps_a_known_500_unit_package_not_one_gram(state, unit):
    _, db, (user_id, product_id, _, _, _) = state
    product = await db.get(Product, product_id)
    product.name, product.unit = "Known package fixture", unit
    product.measure_options = [{"code": unit, "label": unit,
                                "base_unit": unit, "base_quantity": 1}]
    await db.commit()
    user = await db.get(User, user_id)
    from app.services.regional_requirements import to_regional_base_quantity
    for _ in range(2):
        await pantry.add_pantry_item_from_barcode(pantry.AddPantryBarcodeRequest(
            barcode="5010142008692", quantity=100, unit=unit), user, db)
        assert to_regional_base_quantity(product, Decimal(1), "opak") == (Decimal(500), unit)
