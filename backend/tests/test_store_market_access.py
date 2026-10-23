"""A direct foreign store UUID must not bypass the account's fixed market."""

import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.api.v1 import meal_plans, shopping_lists, users
from app.core.exceptions import AppException
from app.db.session import Base, get_db
from app.models import MealPlan, MealPlanEntry, Product, Recipe, RecipeIngredient, ShoppingList, ShoppingListShare, Store, StoreProduct, User
from app.services.exceptions import StoreNotFoundError
from app.services.meal_plan_generator import MealPlanGenerator
from app.services.meal_plan_lifecycle import WARSAW
from tests.uk_regional_fixtures import reviewed_offer, uk_store


class AsyncAdapter:
    def __init__(self, session):
        self.session = session

    async def execute(self, statement, *args, **kwargs):
        if "pg_advisory_xact_lock" in str(statement):
            # Locking is exercised elsewhere against the quota adapter. This
            # SQLite-only contract test checks country access, not PG locks.
            return None
        return self.session.execute(statement, *args, **kwargs)

    async def get(self, model, identifier):
        return self.session.get(model, identifier)

    def add(self, row):
        self.session.add(row)

    async def flush(self):
        self.session.flush()

    async def commit(self):
        self.session.commit()

    async def rollback(self):
        self.session.rollback()

    async def refresh(self, row):
        self.session.refresh(row)


@pytest.fixture(params=["PL", "GB"])
def market_app(request, monkeypatch):
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    country = request.param
    with Session(engine, expire_on_commit=False) as session:
        @event.listens_for(session, "before_flush")
        def test_ids(test_session, flush_context, instances):
            for row in test_session.new:
                if hasattr(row, "id") and row.id is None:
                    row.id = uuid4()

        pl_store = Store(id=uuid4(), name="Lidl", country_code="PL", currency_code="PLN")
        gb_store = uk_store(session, slug="lidl")
        account = User(
            id=uuid4(), email=f"{country}@example.com", password_hash="test",
            country_code=country, is_premium=True, is_email_verified=True,
        )
        recipe = Recipe(id=uuid4(), name="Test recipe", meal_type="obiad")
        session.add_all([pl_store, gb_store, account, recipe])
        session.commit()
        own, foreign = (pl_store, gb_store) if country == "PL" else (gb_store, pl_store)
        plan = MealPlan(
            id=uuid4(), user_id=account.id, store_id=own.id,
            start_date=datetime.now(WARSAW).date(), duration_days=7,
            meals_per_day=1, status="active",
        )
        session.add(plan)
        session.commit()
        app = FastAPI()
        app.include_router(users.router, prefix="/users")
        app.include_router(meal_plans.router, prefix="/meal-plans")
        app.include_router(shopping_lists.router, prefix="/shopping-lists")

        @app.exception_handler(AppException)
        async def app_error(request, error):
            return JSONResponse(status_code=error.status_code, content={"detail": error.detail})

        adapter = AsyncAdapter(session)
        app.dependency_overrides[get_db] = lambda: adapter
        app.dependency_overrides[get_current_user] = lambda: account
        # These tests concern market selection, not quotas or rate limiting.
        monkeypatch.setattr(
            shopping_lists, "record_shopping_list_creation", AsyncMock(),
        )
        monkeypatch.setattr("app.services.meal_plan_quota.ensure_can_create_meal_plan", AsyncMock())
        monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
        yield SimpleNamespace(
            client=TestClient(app, raise_server_exceptions=False), session=session,
            account=account, own=own, foreign=foreign, plan=plan,
            recipe=recipe, db=adapter,
        )
    engine.dispose()


def test_profile_cannot_select_a_foreign_store_by_id(market_app):
    state = market_app
    response = state.client.put("/users/me", json={"preferred_store_id": str(state.foreign.id)})
    assert response.status_code == 400
    assert state.account.preferred_store_id is None


def test_profile_can_select_own_store_and_clear_it(market_app):
    state = market_app
    response = state.client.put("/users/me", json={"preferred_store_id": str(state.own.id)})
    assert response.status_code == 200
    assert state.account.preferred_store_id == state.own.id
    assert state.client.put("/users/me", json={"preferred_store_id": None}).status_code == 200
    assert state.account.preferred_store_id is None


def test_empty_list_cannot_be_created_for_foreign_store(market_app):
    state = market_app
    before = state.session.scalar(select(func.count()).select_from(MealPlan))
    response = state.client.post("/shopping-lists/empty", json={"store_id": str(state.foreign.id)})
    assert response.status_code == 404
    assert state.session.scalar(select(func.count()).select_from(MealPlan)) == before
    assert state.session.scalar(select(func.count()).select_from(ShoppingList)) == 0


def test_empty_list_can_use_account_market_store(market_app):
    state = market_app
    response = state.client.post("/shopping-lists/empty", json={"store_id": str(state.own.id)})
    assert response.status_code == 201
    assert state.session.scalar(select(ShoppingList.store_id)) == state.own.id


def test_recipe_list_rejects_foreign_store_before_creating_anything(market_app, monkeypatch):
    state = market_app
    builder = AsyncMock(side_effect=AssertionError("Foreign store reached builder"))
    monkeypatch.setattr(shopping_lists.ShoppingListBuilder, "build_from_meal_plan", builder)
    response = state.client.post("/shopping-lists/from-recipes", json={
        "store_id": str(state.foreign.id), "recipe_ids": [str(state.recipe.id)],
    })
    assert response.status_code == 404
    builder.assert_not_awaited()
    assert state.session.scalar(select(func.count()).select_from(MealPlan)) == 1


def test_plan_store_update_cannot_switch_markets(market_app):
    state = market_app
    response = state.client.put(
        f"/meal-plans/{state.plan.id}/store", json={"store_id": str(state.foreign.id)},
    )
    assert response.status_code == 404
    assert state.plan.store_id == state.own.id


def test_plan_can_select_another_store_in_the_same_market(market_app):
    state = market_app
    response = state.client.put(
        f"/meal-plans/{state.plan.id}/store", json={"store_id": str(state.own.id)},
    )
    assert response.status_code == 200
    assert state.plan.store_id == state.own.id


def test_generator_rejects_foreign_store_before_recipe_selection(market_app, monkeypatch):
    state = market_app
    generator = MealPlanGenerator(state.db)
    selection = AsyncMock(side_effect=AssertionError("Foreign store reached recipe selection"))
    monkeypatch.setattr(generator, "_load_user_profile", AsyncMock(return_value=(state.account, set())))
    monkeypatch.setattr(generator, "_filter_eligible_recipes", selection)
    with pytest.raises(StoreNotFoundError):
        asyncio.run(generator.generate(state.account.id, state.foreign.id, 1, 1))
    selection.assert_not_awaited()


def test_generate_http_rejects_foreign_store(market_app, monkeypatch):
    state = market_app
    selection = AsyncMock(side_effect=AssertionError("Foreign store reached recipe selection"))
    monkeypatch.setattr(MealPlanGenerator, "_filter_eligible_recipes", selection)
    response = state.client.post("/meal-plans/generate", json={
        "store_id": str(state.foreign.id), "duration_days": 1, "meals_per_day": 1,
    })
    assert response.status_code == 422
    selection.assert_not_awaited()


def test_market_store_lookup_is_query_scoped_and_keeps_legacy_pl_accounts(market_app):
    from app.services.store_market_access import get_store_in_account_market

    state = market_app
    assert asyncio.run(get_store_in_account_market(state.db, state.own.id, state.account)).id == state.own.id
    assert asyncio.run(get_store_in_account_market(state.db, state.foreign.id, state.account)) is None
    assert asyncio.run(get_store_in_account_market(state.db, uuid4(), state.account)) is None
    pl_store_id = state.own.id if state.account.country_code == "PL" else state.foreign.id
    assert asyncio.run(get_store_in_account_market(state.db, pl_store_id, SimpleNamespace())).id == pl_store_id


def test_resume_cannot_recreate_a_legacy_plan_from_another_market(market_app):
    state = market_app
    state.plan.status = "archived"
    state.plan.archived_at = datetime.now(timezone.utc)
    state.plan.store_id = state.foreign.id
    state.session.add(MealPlanEntry(
        id=uuid4(), meal_plan_id=state.plan.id, recipe_id=state.recipe.id,
        day_number=1, meal_slot="obiad",
    ))
    state.session.commit()
    response = state.client.post(f"/meal-plans/{state.plan.id}/resume", json={
        "start_date": datetime.now(WARSAW).date().isoformat(),
    })
    assert response.status_code == 404
    assert state.session.scalar(select(func.count()).select_from(MealPlan)) == 1


def test_merge_cannot_create_a_new_list_in_a_foreign_market(market_app):
    state = market_app
    state.plan.store_id = state.foreign.id
    second_plan = MealPlan(
        id=uuid4(), user_id=state.account.id, store_id=state.foreign.id,
        start_date=state.plan.start_date, duration_days=1, meals_per_day=0,
        status="archived",
    )
    state.session.add(second_plan)
    state.session.flush()
    state.session.add_all([
        ShoppingList(id=uuid4(), meal_plan_id=state.plan.id, store_id=state.foreign.id),
        ShoppingList(id=uuid4(), meal_plan_id=second_plan.id, store_id=state.foreign.id),
    ])
    state.session.commit()
    response = state.client.post("/shopping-lists/merge", json={
        "list_ids": [str(state.plan.id), str(second_plan.id)],
    })
    assert response.status_code == 404
    assert state.session.scalar(select(func.count()).select_from(MealPlan)) == 2
    assert state.session.scalar(select(func.count()).select_from(ShoppingList)) == 2


def test_recipe_swap_requires_local_availability_only_in_uk(market_app):
    state = market_app
    replacement = Recipe(id=uuid4(), name="Unavailable UK recipe", meal_type="obiad")
    entry = MealPlanEntry(
        id=uuid4(), meal_plan_id=state.plan.id, recipe_id=state.recipe.id,
        day_number=1, meal_slot="obiad",
    )
    state.session.add_all([replacement, entry])
    state.session.commit()
    response = state.client.put(
        f"/meal-plans/{state.plan.id}/entries/{entry.id}/swap",
        json={"recipe_id": str(replacement.id)},
    )
    if state.account.country_code == "GB":
        assert response.status_code == 404
        assert entry.recipe_id == state.recipe.id
    else:
        assert response.status_code == 200
        assert entry.recipe_id == replacement.id


def test_accepted_shared_list_from_another_market_remains_readable(market_app):
    state = market_app
    other_country = "GB" if state.account.country_code == "PL" else "PL"
    owner = User(
        id=uuid4(), email="other-owner@example.com", password_hash="test", country_code=other_country,
    )
    state.session.add(owner)
    state.session.flush()
    shared_plan = MealPlan(
        id=uuid4(), user_id=owner.id, store_id=state.foreign.id,
        start_date=state.plan.start_date, duration_days=1, meals_per_day=0,
        status="archived",
    )
    state.session.add(shared_plan)
    state.session.flush()
    state.session.add_all([
        ShoppingList(id=uuid4(), meal_plan_id=shared_plan.id, store_id=state.foreign.id),
        ShoppingListShare(
            id=uuid4(), meal_plan_id=shared_plan.id, shared_by_user_id=owner.id,
            shared_with_user_id=state.account.id, status="accepted",
        ),
    ])
    state.session.commit()
    response = state.client.get(f"/shopping-lists/{shared_plan.id}")
    assert response.status_code == 200
    assert response.json()["store_id"] == str(state.foreign.id)


def test_generator_filters_unknown_ingredients_only_for_uk(market_app):
    state = market_app
    available_product = Product(id=uuid4(), name="Local oats", unit="g")
    mapped_recipe = Recipe(id=uuid4(), name="Mapped recipe", meal_type="obiad")
    state.session.add_all([available_product, mapped_recipe])
    state.session.flush()
    state.session.add_all([
        RecipeIngredient(
            id=uuid4(), recipe_id=mapped_recipe.id, product_id=available_product.id,
            quantity=100, unit="g", is_optional=False,
        ),
        StoreProduct(
            id=uuid4(), store_id=state.own.id, product_id=available_product.id,
            price=1, is_available=True,
        ),
    ])
    if state.account.country_code == "GB":
        reviewed_offer(state.session, available_product, state.own, price="1.00")
    state.session.commit()
    recipes = asyncio.run(MealPlanGenerator(state.db)._filter_eligible_recipes(
        set(), state.own.id, user_id=state.account.id, country_code=state.account.country_code,
    ))
    expected = {mapped_recipe.id}
    if state.account.country_code == "PL":
        expected.add(state.recipe.id)  # Preserve the existing Polish algorithm.
    assert {recipe.id for recipe in recipes} == expected
