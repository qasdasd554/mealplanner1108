"""Real SQLite query checks for UK recipe availability before pagination."""

import asyncio
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, event, inspect, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session

from app.core.exceptions import NotFoundException
from app.api.v1 import recipes as recipe_routes
from app.models import Base, Product, Recipe, RecipeIngredient, Store, StoreProduct
from app.services.market_catalog import (
    apply_recipe_market_filter,
    ensure_recipe_available_in_market,
    recipe_market_availability,
)
from tests.uk_regional_fixtures import reviewed_offer, uk_store


@pytest.fixture
def market_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    engine.dispose()


def product(db, name="Ingredient"):
    row = Product(id=uuid4(), name=name, unit="g")
    db.add(row)
    db.flush()
    return row


def store(db, country="GB"):
    if country == "GB":
        return uk_store(db)
    row = Store(id=uuid4(), name=f"Store-{uuid4()}", country_code=country,
                currency_code="GBP" if country == "GB" else "PLN")
    db.add(row)
    db.flush()
    return row


def availability(db, ingredient, shop, *, available=True, withdrawn=None):
    if shop.country_code == "GB":
        reviewed_offer(db, ingredient, shop, price="1.00",
                       status="available_online" if available and withdrawn is None else "out_of_stock")
        return
    db.add(StoreProduct(
        id=uuid4(), product_id=ingredient.id, store_id=shop.id,
        price=Decimal("1.00"), is_available=available, withdrawn_at=withdrawn,
    ))
    db.flush()


def recipe(db, *ingredients, name="Recipe"):
    row = Recipe(id=uuid4(), name=name, meal_type="obiad")
    db.add(row)
    db.flush()
    for ingredient, optional in ingredients:
        db.add(RecipeIngredient(
            id=uuid4(), recipe_id=row.id, product_id=ingredient.id,
            quantity=Decimal("100"), unit="g", is_optional=optional,
        ))
    db.flush()
    return row


def visible_ids(db, *, country="GB", selected_store=None):
    query = apply_recipe_market_filter(select(Recipe.id), SimpleNamespace(country_code=country), store_id=selected_store)
    return set(db.scalars(query).all())


def test_uk_requires_every_required_canonical_ingredient(market_db):
    required = product(market_db)
    missing = product(market_db)
    uk = store(market_db)
    availability(market_db, required, uk)
    good = recipe(market_db, (required, False))
    bad = recipe(market_db, (required, False), (missing, False))
    assert visible_ids(market_db) == {good.id}
    assert bad.id not in visible_ids(market_db)


def test_missing_optional_ingredient_does_not_hide_uk_recipe(market_db):
    required = product(market_db)
    optional = product(market_db)
    availability(market_db, required, store(market_db))
    row = recipe(market_db, (required, False), (optional, True))
    assert visible_ids(market_db) == {row.id}


@pytest.mark.parametrize(("available", "withdrawn"), [(False, None), (True, date(2026, 10, 1))])
def test_unavailable_or_withdrawn_mapping_does_not_qualify(market_db, available, withdrawn):
    ingredient = product(market_db)
    availability(market_db, ingredient, store(market_db), available=available, withdrawn=withdrawn)
    recipe(market_db, (ingredient, False))
    assert visible_ids(market_db) == set()


def test_polish_store_mapping_is_not_uk_availability(market_db):
    ingredient = product(market_db)
    availability(market_db, ingredient, store(market_db, "PL"))
    row = recipe(market_db, (ingredient, False))
    assert visible_ids(market_db) == set()
    assert visible_ids(market_db, country="PL") == {row.id}


def test_similar_name_or_other_sku_is_not_an_exact_product_match(market_db):
    ingredient = product(market_db, "Natural yoghurt")
    lookalike = product(market_db, "Natural yoghurt")
    availability(market_db, lookalike, store(market_db))
    recipe(market_db, (ingredient, False))
    assert visible_ids(market_db) == set()


def test_required_ingredients_can_be_available_in_different_uk_stores(market_db):
    first, second = product(market_db), product(market_db)
    shop1, shop2 = store(market_db), store(market_db)
    availability(market_db, first, shop1)
    availability(market_db, second, shop2)
    row = recipe(market_db, (first, False), (second, False))
    assert visible_ids(market_db) == {row.id}
    assert visible_ids(market_db, selected_store=shop1.id) == set()
    availability(market_db, second, shop1)
    assert visible_ids(market_db, selected_store=shop1.id) == {row.id}


def test_unknown_empty_ingredient_list_is_hidden_only_in_uk(market_db):
    row = recipe(market_db)
    assert visible_ids(market_db) == set()
    assert visible_ids(market_db, country="PL") == {row.id}


def test_polish_and_legacy_queries_keep_pagination_but_separate_community_origins():
    query = select(Recipe).order_by(Recipe.name).offset(30).limit(30)
    for account in (SimpleNamespace(country_code="PL"), SimpleNamespace()):
        scoped = apply_recipe_market_filter(query, account)
        compiled = scoped.compile()
        assert "users.country_code" in str(compiled)
        assert "PL" in compiled.params.values()
        assert scoped._offset_clause.value == scoped._limit_clause.value == 30
        assert "regional_product_offers" not in str(compiled)


def test_market_filter_is_applied_before_pagination_and_does_not_duplicate(market_db):
    known, missing = product(market_db), product(market_db)
    availability(market_db, known, store(market_db))
    availability(market_db, known, store(market_db))
    for idx in range(4):
        recipe(market_db, (missing, False), name=f"A missing {idx}")
    expected = [recipe(market_db, (known, False), name=f"B known {idx}").id for idx in range(3)]
    query = apply_recipe_market_filter(select(Recipe.id), SimpleNamespace(country_code="GB"))
    assert market_db.scalars(query.order_by(Recipe.name).offset(0).limit(2)).all() == expected[:2]
    assert market_db.scalars(query.order_by(Recipe.name).offset(2).limit(2)).all() == expected[2:]
    compiled = str(query.order_by(Recipe.name).limit(2).compile(dialect=postgresql.dialect()))
    assert compiled.index("WHERE") < compiled.index("LIMIT")


class AsyncSessionAdapter:
    def __init__(self, db):
        self.db = db

    async def execute(self, statement):
        return self.db.execute(statement)


def test_detail_market_check_does_not_replace_permissions(market_db):
    ingredient = product(market_db)
    row = recipe(market_db, (ingredient, False))
    gb = SimpleNamespace(country_code="GB")
    adapter = AsyncSessionAdapter(market_db)
    with pytest.raises(NotFoundException):
        asyncio.run(ensure_recipe_available_in_market(adapter, row, gb))
    availability(market_db, ingredient, store(market_db))
    asyncio.run(ensure_recipe_available_in_market(adapter, row, gb))


def test_polish_system_detail_never_adds_an_availability_query():
    # System recipes are shared; only community recipes need the origin guard.
    recipe = Recipe(id=uuid4(), name="System", meal_type="obiad", created_by_user_id=None)
    asyncio.run(ensure_recipe_available_in_market(None, recipe, SimpleNamespace(country_code="PL")))


@pytest.fixture
def catalogue_route_mocks(monkeypatch):
    monkeypatch.setattr(recipe_routes, "get_blocked_user_ids", AsyncMock(return_value=set()))
    monkeypatch.setattr(recipe_routes, "_get_favorite_recipe_ids", AsyncMock(return_value=set()))


async def _catalogue(db, user, *, skip=0, limit=30):
    return await recipe_routes.list_recipes(
        meal_type=None, cuisine=None, difficulty=None, tags=None,
        max_prep_time=None, search=None, favorites_only=False, new_only=False,
        community_only=False, sort_by="name", skip=skip, limit=limit,
        current_user=user, db=AsyncSessionAdapter(db),
    )


def test_catalogue_route_filters_before_limit_and_keeps_light_projection(market_db, catalogue_route_mocks):
    known, missing = product(market_db), product(market_db)
    availability(market_db, known, store(market_db))
    for index in range(4):
        recipe(market_db, (missing, False), name=f"A missing {index}")
    expected = [recipe(market_db, (known, False), name=f"B known {index}").id for index in range(5)]
    market_db.expunge_all()
    statements = []

    @event.listens_for(market_db.get_bind(), "before_cursor_execute")
    def capture_sql(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    user = SimpleNamespace(id=uuid4(), country_code="GB", role="user")
    rows = asyncio.run(_catalogue(market_db, user, limit=3))
    assert [row.id for row in rows] == expected[:3]
    assert len(statements) == 2  # one lightweight page + one batched tag query
    assert {"ingredients", "photo_base64", "instructions"} <= inspect(rows[0]).unloaded
    second = asyncio.run(_catalogue(market_db, user, skip=3, limit=3))
    assert [row.id for row in second] == expected[3:]
    assert len(statements) == 4  # no per-recipe availability/ingredient query


def test_polish_catalogue_route_keeps_unmapped_recipe(market_db, catalogue_route_mocks):
    row = recipe(market_db, (product(market_db), False))
    user = SimpleNamespace(id=uuid4(), country_code="PL", role="user")
    assert [item.id for item in asyncio.run(_catalogue(market_db, user))] == [row.id]


def test_available_route_is_uk_store_scoped_and_ignores_missing_optional(market_db, catalogue_route_mocks):
    required, optional = product(market_db), product(market_db)
    uk, polish = store(market_db), store(market_db, "PL")
    availability(market_db, required, uk)
    availability(market_db, required, polish)
    row = recipe(market_db, (required, False), (optional, True))
    gb = SimpleNamespace(id=uuid4(), country_code="GB", role="user")
    pl = SimpleNamespace(id=uuid4(), country_code="PL", role="user")

    async def selected(shop, user):
        return await recipe_routes.list_available_recipes(
            store_id=shop.id, skip=0, limit=30, current_user=user,
            db=AsyncSessionAdapter(market_db),
        )

    assert [item.id for item in asyncio.run(selected(uk, gb))] == [row.id]
    with pytest.raises(NotFoundException):
        asyncio.run(selected(polish, gb))
    with pytest.raises(NotFoundException):
        asyncio.run(selected(uk, pl))
    # Preserve legacy PL behaviour: this route previously required optional
    # products as well; this UK rollout must not silently change its result.
    assert asyncio.run(selected(polish, pl)) == []


@pytest.mark.parametrize("access", ["owner", "admin", "other"])
def test_detail_route_preserves_owner_and_moderation_access(market_db, catalogue_route_mocks, access):
    owner_id = uuid4()
    row = recipe(market_db, (product(market_db), False))
    row.created_by_user_id = owner_id
    row.visibility = "private" if access == "owner" else "public"
    market_db.flush()
    user = SimpleNamespace(id=owner_id if access == "owner" else uuid4(), country_code="GB",
                           role="admin" if access == "admin" else "user")
    if access == "other":
        with pytest.raises(NotFoundException):
            asyncio.run(recipe_routes.get_recipe(row.id, current_user=user, db=AsyncSessionAdapter(market_db)))
    else:
        assert asyncio.run(recipe_routes.get_recipe(row.id, current_user=user, db=AsyncSessionAdapter(market_db))).id == row.id


def test_match_route_excludes_recipes_with_missing_uk_required_ingredient(market_db):
    known, missing = product(market_db), product(market_db)
    availability(market_db, known, store(market_db))
    good = recipe(market_db, (known, False))
    recipe(market_db, (known, False), (missing, False))
    user = SimpleNamespace(id=uuid4(), country_code="GB", role="user")
    matches = asyncio.run(recipe_routes.match_recipes_by_ingredients(
        recipe_routes.MatchByIngredientsRequest(product_ids=[known.id]),
        current_user=user, db=AsyncSessionAdapter(market_db),
    ))
    assert [match["recipe"].id for match in matches] == [good.id]


@pytest.mark.parametrize("access", ["owner", "other"])
def test_copying_foreign_unavailable_public_recipe_is_not_a_market_bypass(market_db, monkeypatch, access):
    ingredient = product(market_db)
    row = recipe(market_db, (ingredient, False))
    owner_id = uuid4()
    row.created_by_user_id = owner_id
    row.visibility = "public" if access == "other" else "private"
    market_db.flush()
    user = SimpleNamespace(id=owner_id if access == "owner" else uuid4(), country_code="GB", role="user")
    validation = AsyncMock(side_effect=RuntimeError("validation reached"))
    monkeypatch.setattr(recipe_routes, "_validate_recipe_ingredient_products", validation)
    payload = recipe_routes.RecipeVariantCreate(ingredients=[{
        "product_id": ingredient.id, "quantity": 100, "unit": "g",
    }])
    if access == "other":
        with pytest.raises(NotFoundException):
            asyncio.run(recipe_routes.save_recipe_variant(row.id, payload, current_user=user, db=AsyncSessionAdapter(market_db)))
        validation.assert_not_awaited()
    else:
        with pytest.raises(RuntimeError, match="validation reached"):
            asyncio.run(recipe_routes.save_recipe_variant(row.id, payload, current_user=user, db=AsyncSessionAdapter(market_db)))
        validation.assert_awaited_once()
