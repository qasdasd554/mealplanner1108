"""Real SQLite lifecycle coverage of UK packs, snapshots and shopping actions."""

import asyncio
from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, delete, event, select, func
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.pool import StaticPool

from app.api.v1 import shopping_lists as api
from app.models import (
    Base, MealPlan, MealPlanEntry, PantryItem, Product, ProductSubstitute, Recipe,
    RecipeIngredient, RegionalProductOffer, ShoppingList, ShoppingListItem,
    ShoppingListItemRegionalSnapshot, Store, StoreProduct, User,
)
from app.db.uk_store_catalog import UK_STORES
from app.schemas.shopping_list import ShoppingListResponse, ShoppingListItemResponse
from app.services.shopping_list_builder import ShoppingListBuilder
from app.services.product_substitution import ProductSubstitutionService
from app.services.pantry_shopping_sync import sync_product_in_shopping_lists
from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
from app.services.regional_shopping import apply_regional_item_quote
from tests.sqlite_uuid_compat import supply_sqlite_uuid_defaults


class AsyncDB:
    def __init__(self, session):
        self.session = session

    def __getattr__(self, name):
        return getattr(self.session, name)

    async def execute(self, *args, **kwargs):
        return self.session.execute(*args, **kwargs)

    async def scalars(self, *args, **kwargs):
        return self.session.scalars(*args, **kwargs)

    async def get(self, *args, **kwargs):
        return self.session.get(*args, **kwargs)

    async def flush(self):
        self.session.flush()

    async def commit(self):
        self.session.commit()

    async def refresh(self, *args, **kwargs):
        self.session.refresh(*args, **kwargs)

    async def delete(self, value):
        self.session.delete(value)

    def begin_nested(self):
        db = self.session

        class Savepoint:
            async def __aenter__(self):
                self.transaction = db.begin_nested()
                return self.transaction.__enter__()

            async def __aexit__(self, *args):
                return self.transaction.__exit__(*args)

        return Savepoint()


def run(value):
    return asyncio.run(value)


def _offer(product_id, retailer, sku, pack, price, *, estimated=False):
    domain = "tesco.com" if retailer == "tesco" else "sainsburys.co.uk"
    source = {"url": f"https://www.{domain}/synthetic-fixture/{sku}", "publisher": "Synthetic fixture", "checked_on": datetime.now(timezone.utc).date().isoformat()}
    return {
        "retailer_slug": retailer, "retailer_sku": sku, "canonical_product_id": product_id,
        "name_en": f"Synthetic UK oats {pack}g",
        "package": {"quantity": pack, "unit": "g", "source": source},
        "price": {"amount": price, "kind": "estimate" if estimated else "observed", "source": source,
                  "estimate_reason": "Synthetic local estimate for this package" if estimated else None},
        "availability_status": "available_online", "availability_source": source,
    }


@pytest.fixture(params=[(True, False), (False, False), (True, True), (False, True)],
    ids=["autoflush", "no-autoflush", "autoflush_without_returning", "no-autoflush_without_returning"])
def db(request):
    autoflush, without_returning = request.param
    # HTTP regression tests use TestClient's worker thread. Share this one
    # local in-memory database there; a thread-local pool creates empty DBs.
    engine = create_engine("sqlite:///:memory:",
        connect_args={"check_same_thread": False}, poolclass=StaticPool)

    @event.listens_for(engine, "connect")
    def configure(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")
        connection.create_function("gen_random_uuid", 0, lambda: uuid4().hex)
        connection.create_function("hashtext", 1, lambda _: 0)
        connection.create_function("pg_advisory_xact_lock", 1, lambda _: None)
        connection.isolation_level = None

    @event.listens_for(engine, "begin")
    def begin(connection):
        connection.exec_driver_sql("BEGIN")

    Base.metadata.create_all(engine)
    if without_returning:
        # Reproduce SQLite 3.34 in Codespace, even on a newer development host.
        engine.dialect.insert_returning = False
    with Session(engine, autoflush=autoflush, expire_on_commit=False) as session:
        supply_sqlite_uuid_defaults(session)
        user = User(id=uuid4(), email="gb-shopping@example.test", password_hash="fixture", role="admin", country_code="GB", is_premium=True)
        product = Product(id=uuid4(), name="Polskie płatki", unit="g", default_quantity=Decimal("100"), serving_quantity=200,
            review_status="approved", nutrition_per_100={"kcal": 370},
            measure_options=[{"code": "g", "base_unit": "g", "base_quantity": 1}, {"code": "opak", "base_unit": "g", "base_quantity": 200}])
        substitute = Product(id=uuid4(), name="Polski zamiennik", unit="g", default_quantity=Decimal("100"), review_status="approved", nutrition_per_100={"kcal": 350})
        session.add_all([user, product, substitute])
        for store in UK_STORES[:2]:
            session.add(Store(id=store.id, name=store.name, country_code="GB", currency_code="GBP"))
        session.commit()
        adapter = AsyncDB(session)
        now = datetime.now(timezone.utc)
        run(import_reviewed_uk_catalogue(adapter, [
            _offer(product.id, "tesco", "oats500", "500", "1.25", estimated=True),
            _offer(product.id, "sainsburys", "oats1000", "1000", "1.80"),
            _offer(substitute.id, "tesco", "alternative250", "250", "0.50"),
        ], reviewer_user_id=user.id, reviewed_at=now, as_of=now.date()))
        session.commit()
        yield session, adapter, user, product, substitute
    engine.dispose()


def make_plan(session, user, product, *, quantity="600", unit="g", include_pantry=True, store_id=None):
    recipe = Recipe(id=uuid4(), name="Synthetic recipe", meal_type="obiad", servings=2)
    recipe.ingredients = [RecipeIngredient(id=uuid4(), product_id=product.id, quantity=Decimal(quantity), unit=unit, is_optional=False)]
    plan = MealPlan(id=uuid4(), user_id=user.id, store_id=store_id or UK_STORES[0].id, start_date=date.today(), duration_days=1,
        meals_per_day=1, status="active", preferences={"include_pantry": include_pantry})
    plan.entries = [MealPlanEntry(id=uuid4(), recipe=recipe, day_number=1, meal_slot="obiad", servings_multiplier=Decimal("1"))]
    session.add(plan)
    session.commit()
    return plan


def loaded(session, list_id):
    session.expire_all()
    return session.scalar(select(ShoppingList).where(ShoppingList.id == list_id).options(
        selectinload(ShoppingList.items).selectinload(ShoppingListItem.store_product),
        selectinload(ShoppingList.store),
    ))


def test_builder_keeps_gbp_local_package_and_canonical_id_roundtrip(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    shopping = loaded(session, shopping.id)
    assert len(shopping.items) == 1
    item = shopping.items[0]
    response = ShoppingListResponse.model_validate(shopping)
    line = response.items_by_department["Other"][0]
    assert item.store_product_id is None
    assert line.product_id == product.id
    assert line.product_name == "Synthetic UK oats 500g"
    assert (line.required_quantity, line.unit) == (600, "g")
    assert (line.package_quantity, line.package_count, line.purchased_quantity) == (500, 2, 1000)
    assert line.estimated_price == 2.50 and line.price_is_estimated
    assert response.currency_code == line.currency_code == "GBP"
    assert response.total_estimated_price == 2.50 and not response.has_unpriced_items
    assert session.get(Product, product.id).serving_quantity == 200


def test_unpriced_unknown_measure_never_assumes_100g_or_uses_polish_pack(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, quantity="1", unit="cup")
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    response = ShoppingListResponse.model_validate(loaded(session, shopping.id))
    line = response.items_by_department["Other"][0]
    assert line.required_quantity == 1 and line.unit == "cup"
    assert line.quote_status == "unpriced" and line.package_quantity is None
    assert response.total_estimated_price is None and response.has_unpriced_items


def test_missing_offer_preserves_required_grams_and_null_price(db):
    session, adapter, user, product, _ = db
    session.execute(delete(RegionalProductOffer).where(RegionalProductOffer.product_id == product.id))
    session.commit()
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    item = loaded(session, shopping.id).items[0]
    assert item.required_quantity == Decimal("600") and item.unit == "g"
    assert item.estimated_price is None
    assert item.regional_snapshot.product_id == product.id


def test_recalc_keeps_manual_rows_checked_status_and_changes_store_packs(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    shopping = loaded(session, shopping.id)
    shopping.items[0].is_checked = True
    session.commit()
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=200, unit="g"), user, adapter))
    shopping = loaded(session, shopping.id)
    assert sum(item.required_quantity for item in shopping.items) == Decimal("800")
    assert sum(item.required_quantity for item in shopping.items if item.is_checked) == Decimal("600")
    # Extra demand is a new unchecked manual row, not a change to purchased food.
    assert sum(item.required_quantity for item in shopping.items if not item.is_generated) == Decimal("200")
    plan.store_id = UK_STORES[1].id
    shopping.store_id = UK_STORES[1].id
    session.commit()
    run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    shopping = loaded(session, shopping.id)
    assert len(shopping.items) == 2
    assert sum(item.required_quantity for item in shopping.items) == Decimal("800")
    assert sum(item.required_quantity for item in shopping.items if item.is_checked) == Decimal("600")
    bought = next(item for item in shopping.items if item.is_checked)
    remaining = next(item for item in shopping.items if not item.is_checked)
    # Repricing the remaining purchases must not rewrite the food already bought.
    assert bought.regional_snapshot.store_id == UK_STORES[0].id
    assert Decimal(bought.regional_snapshot.quote_data["package_quantity"]) == 500
    assert bought.estimated_price == Decimal("2.50")
    assert remaining.regional_snapshot.store_id == UK_STORES[1].id
    assert Decimal(remaining.regional_snapshot.quote_data["package_quantity"]) == 1000
    assert remaining.estimated_price == Decimal("1.80")


def test_add_manual_package_uses_local500g_not_canonical200g_and_reprices(db):
    session, adapter, user, product, _ = db
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    run(api.add_item_to_shopping_list(shopping.meal_plan_id, api.AddItemRequest(product_id=product.id, quantity=1, unit="opak"), user, adapter))
    item = loaded(session, shopping.id).items[0]
    assert item.required_quantity == Decimal("500") and item.unit == "g"
    assert item.estimated_price == Decimal("1.25")
    run(api.add_item_to_shopping_list(shopping.meal_plan_id, api.AddItemRequest(product_id=product.id, quantity=0.25, unit="kg"), user, adapter))
    item = loaded(session, shopping.id).items[0]
    assert item.required_quantity == Decimal("750")
    assert item.regional_snapshot.quote_data["package_count"] == 2
    assert item.estimated_price == Decimal("2.50")


def test_merge_snapshots_requotes_combined_whole_packages_not_sum_of_old_prices(db):
    session, adapter, user, product, _ = db
    lists = []
    for _ in range(2):
        plan = make_plan(session, user, product, quantity="200")
        lists.append(run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id)))
    merged = run(api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[row.meal_plan_id for row in lists]), user, adapter))
    merged = loaded(session, merged.id)
    assert len(merged.items) == 1
    assert merged.items[0].required_quantity == Decimal("400")
    assert merged.items[0].regional_snapshot.product_id == product.id
    assert merged.items[0].regional_snapshot.quote_data["package_count"] == 1
    assert merged.items[0].estimated_price == Decimal("1.25")
    assert session.scalar(select(func.count()).select_from(ShoppingListItemRegionalSnapshot)) == 3


def test_pantry_sync_is_idempotent_and_requotes_only_missing_grams(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    pantry = PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("400"), unit="g")
    session.add(pantry)
    session.commit()
    for _ in range(2):
        run(sync_product_in_shopping_lists(adapter, user.id, product.id))
        session.commit()
    shopping = loaded(session, shopping.id)
    assert len(shopping.items) == 2
    assert sum(row.required_quantity for row in shopping.items) == Decimal("600")
    covered = next(row for row in shopping.items if row.is_from_pantry)
    purchase = next(row for row in shopping.items if not row.is_from_pantry)
    assert covered.required_quantity == Decimal("400") and covered.estimated_price == 0
    assert purchase.required_quantity == Decimal("200") and purchase.estimated_price == Decimal("1.25")
    session.delete(pantry)
    session.commit()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    session.commit()
    shopping = loaded(session, shopping.id)
    assert len(shopping.items) == 1
    assert shopping.items[0].required_quantity == Decimal("600")
    assert shopping.items[0].estimated_price == Decimal("2.50")


def test_manual_addition_to_generated_row_survives_recalc_and_full_pantry_split(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=200, unit="g"), user, adapter))
    for _ in range(2):
        run(ShoppingListBuilder(adapter).recalculate(shopping.id))
        row = loaded(session, shopping.id).items[0]
        assert row.required_quantity == Decimal("800")
        assert row.regional_snapshot.manual_extra_quantity == Decimal("200")
        assert row.estimated_price == Decimal("2.50")
    session.add(PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("1000"), unit="g"))
    session.commit()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    session.commit()
    run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    shopping = loaded(session, shopping.id)
    assert sum(row.required_quantity for row in shopping.items) == Decimal("800")
    assert all(row.is_from_pantry for row in shopping.items)
    assert sum(row.regional_snapshot.manual_extra_quantity for row in shopping.items) == Decimal("200")


def test_recalc_keeps_checked_generated_row_when_requirement_did_not_change(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    loaded(session, shopping.id).items[0].is_checked = True
    session.commit()
    run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    assert loaded(session, shopping.id).items[0].is_checked is True


def test_mixed_unknown_recipe_and_manual_extra_preserve_all_quantities_once(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, quantity="100")
    recipe = plan.entries[0].recipe
    recipe.ingredients.append(RecipeIngredient(id=uuid4(), product_id=product.id, quantity=Decimal("1"), unit="cup", is_optional=False))
    session.commit()
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=10, unit="g"), user, adapter))
    for _ in range(2):
        run(ShoppingListBuilder(adapter).recalculate(shopping.id))
        rows = loaded(session, shopping.id).items
        assert {row.unit: row.required_quantity for row in rows} == {"g": Decimal("110"), "cup": Decimal("1")}
        assert all(row.estimated_price is None for row in rows)
        assert sum(row.regional_snapshot.manual_extra_quantity for row in rows) == Decimal("10")


@pytest.mark.parametrize("pantry_amount", [None, Decimal("50")])
def test_sync_preserves_separate_checked_and_unchecked_demand(db, pantry_amount):
    session, adapter, user, product, _ = db
    lists = []
    for checked in (True, False):
        plan = make_plan(session, user, product, quantity="100")
        shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
        loaded(session, shopping.id).items[0].is_checked = checked
        session.commit()
        lists.append(shopping)
    merged = run(api.merge_shopping_lists(api.MergeShoppingListsRequest(list_ids=[row.meal_plan_id for row in lists]), user, adapter))
    pantry = None
    if pantry_amount is not None:
        pantry = PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=pantry_amount, unit="g")
        session.add(pantry)
        session.commit()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    session.commit()
    rows = loaded(session, merged.id).items
    assert sum(row.required_quantity for row in rows) == Decimal("200")
    assert sum(row.required_quantity for row in rows if row.is_from_pantry) == (pantry_amount or Decimal(0))
    assert sum(row.required_quantity for row in rows if not row.is_from_pantry and row.is_checked) <= Decimal("100")
    if pantry is not None:
        session.delete(pantry)
        session.commit()
        run(sync_product_in_shopping_lists(adapter, user.id, product.id))
        session.commit()
    rows = loaded(session, merged.id).items
    assert sum(row.required_quantity for row in rows if row.is_checked) == Decimal("100")
    assert sum(row.required_quantity for row in rows if not row.is_checked) == Decimal("100")


def test_include_pantry_false_survives_recalculate_and_sync(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, include_pantry=False)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id, include_pantry=False))
    session.add(PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("1000"), unit="g"))
    session.commit()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    shopping = loaded(session, shopping.id)
    assert not any(item.is_from_pantry for item in shopping.items)
    assert shopping.items[0].estimated_price == Decimal("2.50")


def test_swap_retains_mass_requirement_and_sets_new_local_pack(db):
    session, adapter, user, product, substitute = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    shopping = loaded(session, shopping.id)
    item = run(ProductSubstitutionService(adapter).substitute_shopping_list_item(shopping.items[0], substitute.id, shopping.store_id))
    session.commit()
    assert item.regional_snapshot.product_id == substitute.id
    assert item.substituted_for == product.id
    assert item.required_quantity == Decimal("600")
    assert item.regional_snapshot.quote_data["package_count"] == 3
    assert item.estimated_price == Decimal("1.50")


def test_completion_moves_actual_whole_pack_quantity_in_g_once_even_if_offer_deleted(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    shopping = loaded(session, shopping.id)
    shopping.items[0].is_checked = True
    offer_id = shopping.items[0].regional_snapshot.offer_id
    session.execute(delete(RegionalProductOffer).where(RegionalProductOffer.id == offer_id))
    session.commit()
    session.expire_all()
    for _ in range(2):
        run(api.complete_shopping_list(plan.id, True, user, adapter))
    pantry = session.scalar(select(PantryItem).where(PantryItem.product_id == product.id))
    assert pantry.quantity == Decimal("1000") and pantry.unit == "g"
    snapshot = loaded(session, shopping.id).items[0].regional_snapshot
    assert snapshot.offer_id is None and snapshot.quote_data["purchased_quantity"] == "1.0E+3"


def test_completion_preflights_unknown_existing_pantry_without_partial_write(db):
    from fastapi import HTTPException

    session, adapter, user, product, substitute = db
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    for selected in (product, substitute):
        run(api.add_item_to_shopping_list(shopping.meal_plan_id, api.AddItemRequest(product_id=selected.id, quantity=100, unit="g"), user, adapter))
    shopping = loaded(session, shopping.id)
    for item in shopping.items:
        item.is_checked = True
    session.add(PantryItem(id=uuid4(), user_id=user.id, product_id=substitute.id, quantity=None, unit="g"))
    session.commit()
    with pytest.raises(HTTPException) as failure:
        run(api.complete_shopping_list(shopping.meal_plan_id, True, user, adapter))
    assert failure.value.status_code == 409
    assert "finish without moving" in failure.value.detail
    # Even a caller that catches the exception must not accidentally commit an
    # earlier row: validation precedes every pantry mutation in this batch.
    session.commit()
    assert session.scalar(select(PantryItem).where(PantryItem.product_id == product.id)) is None
    assert session.scalar(select(PantryItem).where(PantryItem.product_id == substitute.id)).quantity is None
    assert loaded(session, shopping.id).status != "completed"


def test_manual_add_to_checked_row_does_not_check_new_purchase(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, quantity="100")
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    loaded(session, shopping.id).items[0].is_checked = True
    session.commit()
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=10, unit="g"), user, adapter))
    for _ in range(2):
        rows = loaded(session, shopping.id).items
        assert sum(row.required_quantity for row in rows if row.is_checked) == Decimal("100")
        assert sum(row.required_quantity for row in rows if not row.is_checked) == Decimal("10")
        run(ShoppingListBuilder(adapter).recalculate(shopping.id))


def test_checked_purchase_state_survives_full_pantry_recalc_and_removal(db):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, quantity="100")
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    loaded(session, shopping.id).items[0].is_checked = True
    pantry = PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("100"), unit="g")
    session.add(pantry)
    session.commit()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    session.commit()
    run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    assert loaded(session, shopping.id).items[0].regional_snapshot.purchase_is_checked is True
    session.delete(pantry)
    session.commit()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    session.commit()
    item = loaded(session, shopping.id).items[0]
    assert item.is_from_pantry is False and item.is_checked is True


def test_unknown_custom_item_stays_unpriced_gbp_and_not_added_to_pantry(db):
    session, adapter, user, _, _ = db
    shopping = run(api.create_empty_shopping_list(api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), user, adapter))
    run(api.add_custom_item_to_shopping_list(shopping.meal_plan_id, api.AddCustomItemRequest(name="Batteries"), user, adapter))
    shopping = loaded(session, shopping.id)
    line = ShoppingListResponse.model_validate(shopping).items_by_department["Other"][0]
    assert line.currency_code == "GBP" and line.quote_status == "unpriced"
    assert line.product_id is None and line.package_count is None
    assert line.estimated_price is None


def test_substitute_suggestions_use_regional_quote_not_store_product(db):
    session, adapter, _, product, substitute = db
    session.add(ProductSubstitute(id=uuid4(), original_product_id=product.id, substitute_product_id=substitute.id, similarity_score=Decimal("0.9")))
    session.commit()
    result = run(ProductSubstitutionService(adapter).find_substitutes(product.id, UK_STORES[0].id))
    assert len(result) == 1
    assert result[0]["product"].id == substitute.id
    assert result[0]["regional_quote"].currency_code == "GBP"
    assert "store_product" not in result[0]
