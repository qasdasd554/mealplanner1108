"""British stores must not receive Polish catalogue/promotional prices."""

import asyncio
from datetime import date, timedelta
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session

from app.api.v1.price_compare import compare_prices
from app.api.v1 import promotions
from app.models import Base, MealPlan, MealPlanEntry, Product, Recipe, RecipeIngredient, Store, StoreProduct, User
from app.models.promotion import Promotion
from app.services import promo_scraper, promotion_expiry
from tests.uk_regional_fixtures import reviewed_offer, uk_store


@pytest.fixture
def market_price_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        # Keep PostgreSQL UUID defaults intact; make test-created promotions
        # compatible with SQLite builds that lack INSERT ... RETURNING.
        @event.listens_for(session, "before_flush")
        def test_uuid(test_session, flush_context, instances):
            for row in test_session.new:
                column = type(row).__table__.c.get("id")
                if column is not None and isinstance(column.type, postgresql.UUID) and row.id is None:
                    row.id = uuid4()

        yield session
    engine.dispose()


class Database:
    def __init__(self, session):
        self.session = session
        self.statements = []

    async def execute(self, statement):
        self.statements.append(statement)
        return self.session.execute(statement)

    async def get(self, model, identifier):
        return self.session.get(model, identifier)

    async def commit(self):
        self.session.commit()

    async def refresh(self, value):
        self.session.refresh(value)

    def add(self, value):
        self.session.add(value)


@pytest.mark.parametrize(("country", "currency", "expected_price"), [("PL", "PLN", 8.00), ("GB", "GBP", 2.00)])
@pytest.mark.parametrize("wrong_plan_market", [False, True])
def test_price_compare_never_compares_different_currency_lidl_stores(market_price_db, country, currency, expected_price, wrong_plan_market):
    db = market_price_db
    owner = User(id=uuid4(), email="owner@example.com", password_hash="test", country_code=country)
    pl = Store(id=uuid4(), name="Lidl", country_code="PL", currency_code="PLN")
    gb = uk_store(db, slug="lidl")
    ingredient = Product(id=uuid4(), name="Natural yoghurt", unit="g", default_quantity=150)
    dish = Recipe(id=uuid4(), name="Yoghurt", meal_type="śniadanie")
    db.add_all([owner, pl, gb, ingredient, dish])
    db.flush()
    reviewed_offer(db, ingredient, gb, quantity="150", price="2.00")
    db.add_all([
        StoreProduct(id=uuid4(), product_id=ingredient.id, store_id=pl.id, price=Decimal("8.00")),
        StoreProduct(id=uuid4(), product_id=ingredient.id, store_id=gb.id, price=Decimal("2.00")),
        RecipeIngredient(id=uuid4(), recipe_id=dish.id, product_id=ingredient.id, quantity=150, unit="g"),
    ])
    expected_store = pl if country == "PL" else gb
    planned_store = (gb if country == "PL" else pl) if wrong_plan_market else expected_store
    plan = MealPlan(id=uuid4(), user_id=owner.id, store_id=planned_store.id,
                    start_date=date.today(), duration_days=7, meals_per_day=1, status="active")
    db.add(plan)
    db.flush()
    db.add(MealPlanEntry(id=uuid4(), meal_plan_id=plan.id, recipe_id=dish.id,
                         day_number=1, meal_slot="śniadanie", servings_multiplier=1))
    db.flush()
    adapter = Database(db)
    rows = asyncio.run(compare_prices(plan.id, db=adapter, current_user=owner))
    if wrong_plan_market:
        assert rows == []
        return
    assert len(rows) == 1
    assert rows[0].store_id == (pl.id if country == "PL" else gb.id)
    assert rows[0].total_price == expected_price
    assert rows[0].currency_code == currency
    assert rows[0].savings_vs_most_expensive == 0
    assert len(adapter.statements) == (4 if country == "GB" else 3)  # GB adds scoped pantry; PL unchanged
    store_sql = str(adapter.statements[1].compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True}))
    assert f"stores.country_code = '{country}'" in store_sql
    assert f"stores.currency_code = '{currency}'" in store_sql


def _stores_prices(db, *, pl_price="8.00", gb_price="2.00"):
    pl = Store(id=uuid4(), name="Lidl", country_code="PL", currency_code="PLN")
    gb = Store(id=uuid4(), name="Lidl", country_code="GB", currency_code="GBP")
    ingredient = Product(id=uuid4(), name="Natural yoghurt", unit="g", default_quantity=150)
    db.add_all([pl, gb, ingredient])
    db.flush()
    pl_row = StoreProduct(id=uuid4(), product_id=ingredient.id, store_id=pl.id, price=Decimal(pl_price))
    gb_row = StoreProduct(id=uuid4(), product_id=ingredient.id, store_id=gb.id, price=Decimal(gb_price))
    db.add_all([pl_row, gb_row])
    db.flush()
    return ingredient, pl_row, gb_row


def _promotion(db, *, expired=False):
    row = Promotion(
        id=uuid4(), product_name="Natural yoghurt", store_name="Lidl",
        regular_price=Decimal("8.00"), promo_price=Decimal("5.00"), promo_type="price_cut",
        valid_from=date.today() - timedelta(days=7),
        valid_until=date.today() - timedelta(days=1) if expired else date.today() + timedelta(days=7),
        review_status="pending", is_active=True, price_applied=expired,
    )
    db.add(row)
    db.flush()
    return row


def test_existing_polish_promotions_are_not_returned_to_uk_user(market_price_db):
    row = _promotion(market_price_db)
    db = Database(market_price_db)
    gb = SimpleNamespace(country_code="GB")
    pl = SimpleNamespace(country_code="PL")
    assert asyncio.run(promotions.list_promotions(store_name=None, search=None, db=db, current_user=gb)) == []
    assert asyncio.run(promotions.check_promotion(product_name="yoghurt", store_name="Lidl", db=db, current_user=gb)) == []
    assert asyncio.run(promotions.list_promotions(store_name=None, search=None, db=db, current_user=pl)) == [row]


def test_approval_targets_polish_lidl_without_duplicate_store_exception(market_price_db):
    _, pl_price, gb_price = _stores_prices(market_price_db)
    row = _promotion(market_price_db)
    admin = SimpleNamespace(id=uuid4(), country_code="GB", role="admin")
    asyncio.run(promotions.approve_promotion(row.id, current_user=admin, db=Database(market_price_db)))
    assert pl_price.price == Decimal("5.00")
    assert gb_price.price == Decimal("2.00")
    assert row.price_applied is True


def test_expiry_targets_polish_lidl_and_never_restores_gbp(market_price_db):
    _, pl_price, gb_price = _stores_prices(market_price_db, pl_price="5.00", gb_price="5.00")
    row = _promotion(market_price_db, expired=True)
    restored = asyncio.run(promotion_expiry.restore_expired_promotion_prices(Database(market_price_db)))
    assert restored == 1
    assert pl_price.price == Decimal("8.00")
    assert gb_price.price == Decimal("5.00")
    assert row.price_applied is False


def test_ai_flyer_lookup_is_explicitly_polish_when_store_name_exists_twice(market_price_db, monkeypatch):
    from app.services import promo_ai_scanner

    _stores_prices(market_price_db)
    scan = AsyncMock(return_value=[])
    monkeypatch.setattr(promo_ai_scanner, "find_promotions_for_store", scan)
    result = asyncio.run(promotions._scan_and_queue_promotions("Lidl", Database(market_price_db)))
    assert result["found"] == 0
    scan.assert_awaited_once_with("Lidl", ["Natural yoghurt"])


def test_polish_scraper_cannot_overwrite_same_named_british_store(market_price_db, monkeypatch):
    _, pl_price, gb_price = _stores_prices(market_price_db)
    monkeypatch.setattr(promo_scraper, "_STORE_URLS", {"Lidl": ["https://unused.example"]})
    monkeypatch.setattr(promo_scraper, "_scrape_store", AsyncMock(return_value=[{"name": "Natural yoghurt", "price": "5.00"}]))
    summary = asyncio.run(promo_scraper.scrape_and_update_prices(Database(market_price_db)))
    assert summary["Lidl"]["prices_updated"] == 1
    assert pl_price.price == Decimal("5.00")
    assert gb_price.price == Decimal("2.00")
