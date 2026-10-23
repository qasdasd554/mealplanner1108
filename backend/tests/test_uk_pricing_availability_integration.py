"""Reviewed UK checkout/availability against ephemeral SQLite, no network IO."""

import asyncio
from datetime import timedelta
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select, text
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.api.v1.price_compare import compare_prices, router
from app.core.exceptions import NotFoundException
from app.models import (
    Base, MealPlan, MealPlanEntry, PantryItem, Product, Recipe, RecipeIngredient,
    ShoppingList, ShoppingListItem, Store, StoreProduct, User,
)
from app.services.market_catalog import (
    ensure_recipe_available_in_market, recipe_market_availability,
    reviewed_uk_offer_conditions, utc_market_date,
)
from app.services.meal_plan_generator import MealPlanGenerator, _shopping_list_budget_query
from app.services.shopping_list_builder import ShoppingListBuilder
from tests.uk_regional_fixtures import reviewed_offer, uk_store


class Database:
    def __init__(self, session):
        self.session = session
        self.statements = []

    async def execute(self, statement):
        self.statements.append(statement)
        return self.session.execute(statement)

    async def get(self, model, key):
        return self.session.get(model, key)

    def add(self, value):
        self.session.add(value)

    async def flush(self):
        self.session.flush()

    async def commit(self):
        self.session.commit()


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        @event.listens_for(session, "before_flush")
        def sqlite_uuids(current, flush_context, instances):
            for row in current.new:
                column = type(row).__table__.c.get("id")
                if column is not None and isinstance(column.type, postgresql.UUID) and row.id is None:
                    row.id = uuid4()

        yield session
    engine.dispose()


def setup_plan(db, *, quantity="501", unit="g", product_unit="g", include_pantry=True):
    owner = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test", country_code="GB")
    shop = uk_store(db, slug="tesco")
    product = Product(id=uuid4(), name="Ingredient", unit=product_unit, default_quantity=100)
    dish = Recipe(id=uuid4(), name="Recipe", meal_type="obiad", servings=4)
    db.add_all([owner, product, dish])
    db.flush()
    db.add(RecipeIngredient(id=uuid4(), recipe_id=dish.id, product_id=product.id,
                            quantity=Decimal(quantity), unit=unit, is_optional=False))
    plan = MealPlan(id=uuid4(), user_id=owner.id, store_id=shop.id, start_date=utc_market_date(),
                    duration_days=5, meals_per_day=1, status="active",
                    preferences={"include_pantry": include_pantry})
    db.add(plan)
    db.flush()
    db.add(MealPlanEntry(id=uuid4(), meal_plan_id=plan.id, recipe_id=dish.id,
                         day_number=1, meal_slot="obiad", servings_multiplier=1))
    db.flush()
    return owner, shop, product, dish, plan


def compare(db, owner, plan):
    return asyncio.run(compare_prices(plan.id, db=Database(db), current_user=owner))


def test_gb_legacy_price_mapping_is_not_a_valid_regional_quote_or_listing(db):
    owner, shop, product, dish, plan = setup_plan(db)
    db.add(StoreProduct(id=uuid4(), store_id=shop.id, product_id=product.id,
                        price=Decimal("0.01"), is_available=True))
    db.flush()
    assert db.scalars(select(Recipe.id).where(recipe_market_availability("GB"))).all() == []
    result = compare(db, owner, plan)[0]
    assert result.total_price is None
    assert result.is_complete is False and result.is_cheapest is False
    assert result.savings_vs_most_expensive == 0
    assert result.items == [] and result.missing_products == [product.name]


def test_checkout_uses_local_500g_not_polish_100g_and_exposes_pack_provenance(db):
    owner, shop, product, dish, plan = setup_plan(db)
    offer = reviewed_offer(db, product, shop, quantity="500", price="2.00")
    db.add(StoreProduct(id=uuid4(), store_id=shop.id, product_id=product.id, price=Decimal("99.99")))
    db.flush()
    adapter = Database(db)
    result = asyncio.run(compare_prices(plan.id, db=adapter, current_user=owner))[0]
    assert result.total_price == 4 and result.currency_code == "GBP"
    assert result.is_complete and result.is_cheapest
    assert len(adapter.statements) == 4  # one bulk offer and one owner-scoped pantry query
    item = result.items[0]
    assert item.quantity_needed == 501 and item.unit == "g"
    assert item.package_quantity == 500 and item.package_count == 2
    assert item.purchased_quantity == 1000 and item.price_per_package == 2
    assert item.regional_offer_id == offer.id and item.offer_fingerprint == offer.fingerprint
    assert item.price_source["checked_on"] == utc_market_date().isoformat()
    assert not item.price_is_estimated and item.last_verified == utc_market_date()
    assert product.default_quantity == 100  # no mutation/reinterpretation of Polish data


def test_uk_quote_aggregates_mixed_units_and_final_entry_multiplier_once(db):
    owner, shop, product, dish, plan = setup_plan(db, quantity="0.25", unit="kg")
    db.add(RecipeIngredient(id=uuid4(), recipe_id=dish.id, product_id=product.id,
                            quantity=Decimal("251"), unit="g", is_optional=False))
    db.flush()
    # 501g of recipe x1.5, not divided by its four servings again.
    plan.entries[0].servings_multiplier = Decimal("1.5")
    reviewed_offer(db, product, shop, quantity="500", price="2.00")
    db.flush()
    item = compare(db, owner, plan)[0].items[0]
    assert item.quantity_needed == 751.5 and item.package_count == 2


def test_explicit_volume_uses_1136ml_and_does_not_cross_mass_dimension(db):
    owner, shop, product, dish, plan = setup_plan(db, quantity="1.136", unit="l", product_unit="ml")
    reviewed_offer(db, product, shop, quantity="1136", unit="ml", price="1.65")
    result = compare(db, owner, plan)[0]
    assert result.total_price == 1.65 and result.items[0].package_count == 1
    assert result.items[0].quantity_needed == 1136 and result.items[0].unit == "ml"
    dish.ingredients[0].unit = "g"
    db.flush()
    assert compare(db, owner, plan)[0].total_price is None


@pytest.mark.parametrize("mutate", ["fingerprint", "source_host", "source_missing", "source_future", "stale", "out_of_stock"])
def test_bad_or_stale_evidence_never_becomes_a_complete_uk_price(db, mutate):
    owner, shop, product, dish, plan = setup_plan(db)
    offer = reviewed_offer(db, product, shop)
    if mutate == "fingerprint":
        offer.fingerprint = "0" * 64
    elif mutate == "source_host":
        offer.price_source = {**offer.price_source, "url": "https://not-a-retailer.example/item"}
    elif mutate == "source_missing":
        offer.price_source = {}
    elif mutate == "source_future":
        offer.price_source = {**offer.price_source, "checked_on": (utc_market_date() + timedelta(days=1)).isoformat()}
    elif mutate == "stale":
        offer.price_source = {**offer.price_source, "checked_on": (utc_market_date() - timedelta(days=31)).isoformat()}
    else:
        offer.availability_status = "out_of_stock"
    db.flush()
    result = compare(db, owner, plan)[0]
    assert result.total_price is None and result.is_complete is False
    with pytest.raises(NotFoundException):
        asyncio.run(ensure_recipe_available_in_market(Database(db), dish, owner))


def test_estimates_are_not_promoted_to_observed_even_with_dated_evidence(db):
    owner, shop, product, dish, plan = setup_plan(db)
    reviewed_offer(db, product, shop, kind="estimate")
    result = compare(db, owner, plan)[0]
    assert result.total_price == 4 and result.has_estimated_prices
    assert result.items[0].price_is_estimated and result.items[0].last_verified is None


@pytest.mark.parametrize("covered,unit,include,expected", [
    ("500", "g", True, 2), ("501", "g", True, 0),
    ("500", "g", False, 4), ("500", "ml", True, 4),
    (None, "g", True, 4),
])
def test_comparison_subtracts_only_explicit_matching_pantry_quantities(db, covered, unit, include, expected):
    owner, shop, product, dish, plan = setup_plan(db, include_pantry=include)
    reviewed_offer(db, product, shop)
    db.add(PantryItem(id=uuid4(), user_id=owner.id, product_id=product.id,
                      quantity=Decimal(covered) if covered else None, unit=unit))
    db.flush()
    result = compare(db, owner, plan)[0]
    assert result.total_price == expected and result.is_complete
    pantry_items = [item for item in result.items if item.is_from_pantry]
    assert bool(pantry_items) == (include and covered is not None and unit == "g")


def test_generator_uses_verified_offers_without_any_legacy_gb_mapping(db):
    owner, shop, product, dish, plan = setup_plan(db)
    offer = reviewed_offer(db, product, shop)
    adapter = Database(db)
    rows = asyncio.run(MealPlanGenerator(adapter)._filter_eligible_recipes(
        allergen_ids=set(), store_id=shop.id, user_id=owner.id, country_code="GB",
    ))
    assert [row.id for row in rows] == [dish.id]
    assert not any("store_products" in str(stmt) for stmt in adapter.statements)
    offer.fingerprint = "0" * 64
    db.flush()
    assert asyncio.run(MealPlanGenerator(Database(db))._filter_eligible_recipes(
        allergen_ids=set(), store_id=shop.id, user_id=owner.id, country_code="GB",
    )) == []


def test_sql_availability_is_before_limit_and_filters_sources_without_date_cast(db):
    owner, shop, product, dish, plan = setup_plan(db)
    reviewed_offer(db, product, shop)
    stmt = select(Recipe.id).where(recipe_market_availability("GB", as_of=utc_market_date())).limit(1)
    assert db.scalars(stmt).all() == [dish.id]
    sql = str(stmt.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True}))
    assert "regional_product_offers" in sql and "store_products" not in sql
    assert "available_online" in sql and "reviewed_at" in sql and "checked_on" in sql
    assert sql.index("WHERE") < sql.index("LIMIT")
    assert "AS DATE" not in sql  # invalid JSON text must not raise database errors


def test_postgres_review_day_is_explicitly_utc_not_session_timezone():
    stmt = select(Recipe.id).where(recipe_market_availability("GB", as_of=utc_market_date()))
    sql = str(stmt.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True}))
    assert "AT TIME ZONE 'UTC'" in sql
    assert "to_char(" in sql and "'YYYY-MM-DD'" in sql
    assert "substr(CAST(regional_product_offers.reviewed_at AS VARCHAR)" not in sql


@pytest.mark.parametrize("offset_timestamp,expected_available", [
    ("previous_day_pacific", True),
    ("current_day_east", False),
])
def test_sqlite_review_day_normalises_offset_to_utc(db, offset_timestamp, expected_available):
    _, shop, product, _, _ = setup_plan(db)
    offer = reviewed_offer(db, product, shop)
    as_of = utc_market_date()
    stored = (
        f"{as_of - timedelta(days=1)} 17:30:00-07:00"
        if offset_timestamp == "previous_day_pacific"
        else f"{as_of} 00:30:00+02:00"
    )
    # SQLite DateTime binding discards offsets. Raw persisted ISO values cover
    # the boundary directly; no real PostgreSQL session is claimed by this test.
    db.execute(text("UPDATE regional_product_offers SET reviewed_at = :reviewed_at WHERE id = :offer_id"),
               {"reviewed_at": stored, "offer_id": offer.id.hex})
    found = db.scalars(select(type(offer).id).where(
        type(offer).id == offer.id, *reviewed_uk_offer_conditions(as_of=as_of),
    )).all()
    assert bool(found) is expected_available


@pytest.mark.parametrize("rows,expected", [
    ([], None), ([(None, False)], None),
    ([(Decimal("2"), False), (None, False)], None),
    ([(Decimal("2"), False), (Decimal("0"), True)], Decimal("2")),
    ([(Decimal("0"), True)], Decimal("0")),
])
def test_generated_uk_budget_is_unknown_until_every_purchase_has_a_quote(db, rows, expected):
    owner, shop, product, dish, plan = setup_plan(db)
    shopping = ShoppingList(id=uuid4(), store_id=shop.id, meal_plan_id=plan.id)
    db.add(shopping)
    db.flush()
    for price, pantry in rows:
        db.add(ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id,
                                custom_name="Synthetic", required_quantity=100, unit="g",
                                estimated_price=price, is_from_pantry=pantry))
    db.flush()
    assert db.scalar(_shopping_list_budget_query(shopping.id, "GB")) == expected


def test_http_null_total_and_pack_fields_are_serialized_without_pln_fallback(db):
    owner, shop, product, dish, plan = setup_plan(db)
    offer = reviewed_offer(db, product, shop)
    app = FastAPI()
    app.include_router(router, prefix="/price-compare")
    app.dependency_overrides[get_current_user] = lambda: owner
    app.dependency_overrides[get_db] = lambda: Database(db)
    with TestClient(app) as client:
        response = client.get(f"/price-compare/{plan.id}")
        assert response.status_code == 200
        payload = response.json()[0]
        assert payload["currency_code"] == "GBP" and payload["total_price"] == 4
        assert payload["items"][0]["package_count"] == 2
        offer.fingerprint = "0" * 64
        db.flush()
        payload = client.get(f"/price-compare/{plan.id}").json()[0]
        assert payload["total_price"] is None and payload["is_complete"] is False


@pytest.mark.parametrize("covered,has_offer,expected", [
    (None, True, Decimal("4.00")), ("500", True, Decimal("2.00")),
    ("501", True, Decimal("0.00")), (None, False, None),
    ("500", False, None), ("501", False, Decimal("0.00")),
])
def test_actual_builder_checkout_matches_comparison_and_plan_budget(db, covered, has_offer, expected):
    owner, shop, product, dish, plan = setup_plan(db)
    owner.is_premium = True  # use real quota history, without PostgreSQL advisory locks on SQLite
    if has_offer:
        reviewed_offer(db, product, shop)
    if covered is not None:
        db.add(PantryItem(id=uuid4(), user_id=owner.id, product_id=product.id,
                          quantity=Decimal(covered), unit="g"))
    db.flush()
    shopping = asyncio.run(ShoppingListBuilder(Database(db)).build_from_meal_plan(plan.id))
    result = compare(db, owner, plan)[0]
    budget = db.scalar(_shopping_list_budget_query(shopping.id, "GB"))
    assert budget == expected
    assert result.total_price == (float(expected) if expected is not None else None)
    assert result.is_complete == (expected is not None)
    assert all(item.regional_snapshot is not None for item in shopping.items)
    if expected is not None:
        assert sum(item.estimated_price for item in shopping.items) == expected
