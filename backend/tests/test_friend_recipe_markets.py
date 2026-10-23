"""Country availability cannot be bypassed through a friend's recipe list.

All queries run against ephemeral SQLite. Neither real accounts nor an external
database, notifications, startup migrations or network APIs are accessed.
"""

import asyncio
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.api.v1.friends import friend_recipes
from app.models import (
    Base,
    Friendship,
    Product,
    Recipe,
    RecipeIngredient,
    Store,
    StoreProduct,
    User,
)
from app.models.friendship import canonical_friend_ids
from tests.uk_regional_fixtures import reviewed_offer, uk_store


class AsyncSessionAdapter:
    def __init__(self, session):
        self.session = session

    async def execute(self, query):
        return self.session.execute(query)


@pytest.fixture
def friend_market_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        owner = User(
            id=uuid4(), email="owner@example.invalid", password_hash="not-a-password",
            country_code="PL",
        )
        gb_viewer = User(
            id=uuid4(), email="gb@example.invalid", password_hash="not-a-password",
            country_code="GB",
        )
        pl_viewer = User(
            id=uuid4(), email="pl@example.invalid", password_hash="not-a-password",
            country_code="PL",
        )
        session.add_all([owner, gb_viewer, pl_viewer])
        session.flush()
        for viewer in (gb_viewer, pl_viewer):
            first, second = canonical_friend_ids(owner.id, viewer.id)
            session.add(Friendship(
                id=uuid4(), user_a_id=first, user_b_id=second,
                requested_by_id=owner.id, status="accepted",
            ))
        session.flush()
        yield session, owner, gb_viewer, pl_viewer
    engine.dispose()


def _ingredient(session):
    product = Product(id=uuid4(), name="Ingredient", unit="g")
    session.add(product)
    session.flush()
    return product


def _recipe(session, owner, product, *, visibility="private", active=True):
    recipe = Recipe(
        id=uuid4(), name=f"Recipe-{uuid4()}", meal_type="obiad",
        created_by_user_id=owner.id, visibility=visibility, is_active=active,
    )
    session.add(recipe)
    session.flush()
    session.add(RecipeIngredient(
        id=uuid4(), recipe_id=recipe.id, product_id=product.id,
        quantity=Decimal("100"), unit="g", is_optional=False,
    ))
    session.flush()
    return recipe


def _available(session, product, country):
    if country == "GB":
        reviewed_offer(session, product, uk_store(session), price="1.00")
        return
    store = Store(
        id=uuid4(), name=f"Store-{uuid4()}", country_code=country,
        currency_code="GBP" if country == "GB" else "PLN",
    )
    session.add(store)
    session.flush()
    session.add(StoreProduct(
        id=uuid4(), store_id=store.id, product_id=product.id,
        price=Decimal("1.00"), is_available=True,
    ))
    session.flush()


def _list(session, owner, viewer):
    return asyncio.run(friend_recipes(
        owner.id, current_user=viewer, db=AsyncSessionAdapter(session),
    ))


def test_gb_friend_view_uses_viewer_country_not_polish_recipe_owner(friend_market_db):
    session, owner, gb_viewer, _ = friend_market_db
    uk_product, polish_product = _ingredient(session), _ingredient(session)
    _available(session, uk_product, "GB")
    _available(session, polish_product, "PL")
    private_uk = _recipe(session, owner, uk_product)
    public_uk = _recipe(session, owner, uk_product, visibility="public")
    unavailable = _recipe(session, owner, polish_product)
    rows = _list(session, owner, gb_viewer)
    assert {row.id for row in rows} == {private_uk.id, public_uk.id}
    assert unavailable.id not in {row.id for row in rows}
    assert all(not row.is_own_recipe and not row.is_favorite for row in rows)


def test_polish_friend_view_keeps_existing_private_and_public_rules(friend_market_db):
    session, owner, _, pl_viewer = friend_market_db
    product = _ingredient(session)
    private = _recipe(session, owner, product)
    public = _recipe(session, owner, product, visibility="public")
    _recipe(session, owner, product, visibility="pending")
    _recipe(session, owner, product, active=False)
    assert {row.id for row in _list(session, owner, pl_viewer)} == {private.id, public.id}


def test_gb_friend_view_does_not_duplicate_recipe_for_two_store_mappings(friend_market_db):
    session, owner, gb_viewer, _ = friend_market_db
    product = _ingredient(session)
    _available(session, product, "GB")
    _available(session, product, "GB")
    recipe = _recipe(session, owner, product)
    assert [row.id for row in _list(session, owner, gb_viewer)] == [recipe.id]


def test_market_availability_never_replaces_accepted_friendship(friend_market_db):
    session, owner, gb_viewer, _ = friend_market_db
    product = _ingredient(session)
    _available(session, product, "GB")
    _recipe(session, owner, product)
    session.query(Friendship).delete()
    session.flush()
    with pytest.raises(HTTPException) as failure:
        _list(session, owner, gb_viewer)
    assert failure.value.status_code == 403
