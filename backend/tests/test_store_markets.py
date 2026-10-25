"""Country-scoped store HTTP contracts on a local SQLite database only."""

import asyncio
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from fastapi import HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.db.session import Base, get_db
from app.main import app
from app.models import Store, StoreDepartment, User, Product, Recipe


class AsyncSessionAdapter:
    def __init__(self, session):
        self.session = session

    async def execute(self, statement):
        return self.session.execute(statement)


@pytest.fixture
def market_client():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    account = SimpleNamespace(country_code="PL", role="user", id=uuid4())
    pl_id, gb_id = uuid4(), uuid4()
    with Session(engine) as session:
        session.add_all([
            Store(id=pl_id, name="Lidl", country_code="PL", currency_code="PLN"),
            Store(id=gb_id, name="Lidl", country_code="GB", currency_code="GBP"),
        ])
        session.flush()
        session.add_all([
            StoreDepartment(id=uuid4(), store_id=pl_id, name="Nabiał", sort_order=1),
            StoreDepartment(id=uuid4(), store_id=gb_id, name="Dairy and eggs", sort_order=1),
        ])
        session.commit()
        overrides = app.dependency_overrides.copy()
        app.dependency_overrides[get_db] = lambda: AsyncSessionAdapter(session)
        app.dependency_overrides[get_current_user] = lambda: account
        try:
            # No lifespan context: these tests never execute production startup.
            yield TestClient(app), account, pl_id, gb_id
        finally:
            app.dependency_overrides.clear()
            app.dependency_overrides.update(overrides)
    engine.dispose()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_list_includes_only_account_market_with_correct_currency(market_client, country):
    client, account, pl_id, gb_id = market_client
    account.country_code = country
    response = client.get("/api/v1/stores/")
    assert response.status_code == 200
    assert [(row["id"], row["country_code"], row["currency_code"]) for row in response.json()] == [
        (str(pl_id if country == "PL" else gb_id), country, "PLN" if country == "PL" else "GBP")
    ]


@pytest.mark.parametrize("suffix", ["", "/departments", "/products"])
@pytest.mark.parametrize("country", ["PL", "GB"])
def test_direct_id_cannot_fetch_other_market(market_client, suffix, country):
    client, account, pl_id, gb_id = market_client
    account.country_code = country
    own_id, foreign_id = (pl_id, gb_id) if country == "PL" else (gb_id, pl_id)
    assert client.get(f"/api/v1/stores/{own_id}{suffix}").status_code == 200
    assert client.get(f"/api/v1/stores/{foreign_id}{suffix}").status_code == 404


def test_query_or_header_cannot_override_persisted_country(market_client):
    client, account, pl_id, gb_id = market_client
    response = client.get("/api/v1/stores/?country_code=GB", headers={"X-Country": "GB"})
    assert response.status_code == 200
    assert [row["id"] for row in response.json()] == [str(pl_id)]


def test_admin_catalogue_context_does_not_change_registered_country(market_client):
    client, account, pl_id, gb_id = market_client
    account.role = "admin"
    response = client.get("/api/v1/stores/?market=GB")
    assert response.status_code == 200
    assert [row["id"] for row in response.json()] == [str(gb_id)]
    assert account.country_code == "PL"
    assert [row["id"] for row in client.get("/api/v1/stores/").json()] == [str(pl_id)]


@pytest.mark.parametrize("path", [
    "/stores/?market=GB", "/products/admin/pending?market=GB",
    "/recipes/pending/review?market=GB", "/recipes/admin/all-user-recipes?market=GB",
    "/promotions/pending?market=GB",
])
def test_ordinary_user_cannot_use_admin_market_selection(market_client, path):
    client, account, _, _ = market_client
    assert client.get(f"/api/v1{path}").status_code == 403
    assert account.country_code == "PL"


@pytest.mark.parametrize("market", ["PL", "GB"])
def test_admin_moderation_queues_filter_market_at_database(market_client, market):
    client, account, _, _ = market_client
    account.role = "admin"
    session = app.dependency_overrides[get_db]().session
    owners = {country: User(
        id=uuid4(), email=f"{country}@example.invalid", password_hash="test", country_code=country,
    ) for country in ("PL", "GB")}
    session.add_all(owners.values())
    session.flush()
    for country in ("PL", "GB"):
        session.add(Product(
            id=uuid4(), name=f"Product {country}", unit="g", review_status="pending",
            submitted_country_code=country, created_by_user_id=owners[country].id,
        ))
        session.add(Recipe(
            id=uuid4(), name=f"Recipe {country}", meal_type="obiad", visibility="pending",
            created_by_user_id=owners[country].id,
        ))
    session.commit()
    for path, expected in [
        ("/products/admin/pending", f"Product {market}"),
        ("/recipes/pending/review", f"Recipe {market}"),
        ("/recipes/admin/all-user-recipes", f"Recipe {market}"),
    ]:
        response = client.get(f"/api/v1{path}?market={market}")
        assert response.status_code == 200, response.text
        assert [row["name"] for row in response.json()] == [expected]
    assert account.country_code == "PL"


@pytest.mark.parametrize("country,currency", [("PL", "GBP"), ("GB", "PLN"), ("US", "USD")])
def test_store_rejects_cross_currency_and_unsupported_market(country, currency):
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        session.add(Store(id=uuid4(), name="Invalid", country_code=country, currency_code=currency))
        with pytest.raises(IntegrityError):
            session.commit()
    engine.dispose()


def test_store_name_remains_unique_within_market():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        session.add_all([
            Store(id=uuid4(), name="Duplicate", country_code="GB", currency_code="GBP"),
            Store(id=uuid4(), name="Duplicate", country_code="GB", currency_code="GBP"),
        ])
        with pytest.raises(IntegrityError):
            session.commit()
    engine.dispose()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_submitted_product_cannot_request_foreign_store(market_client, country):
    from app.api.v1.products import _validate_submission_stores

    _, account, pl_id, gb_id = market_client
    account.country_code = country
    own_id, foreign_id = (pl_id, gb_id) if country == "PL" else (gb_id, pl_id)
    db = app.dependency_overrides[get_db]()
    asyncio.run(_validate_submission_stores(db, [own_id], account))
    with pytest.raises(HTTPException) as error:
        asyncio.run(_validate_submission_stores(db, [foreign_id], account))
    assert error.value.status_code == 400


@pytest.mark.parametrize("submitted,store_country,expected_links", [
    ("PL", "GB", 0), ("GB", "PL", 0), ("PL", "PL", 1), ("GB", "GB", 0),
])
def test_approval_does_not_copy_submitted_price_across_currencies(submitted, store_country, expected_links):
    from app.api.v1.products import review_product
    from app.models import StoreProduct

    store_id = uuid4()
    product = SimpleNamespace(
        id=uuid4(), review_status="pending", requested_store_ids=[str(store_id)],
        submitted_price=Decimal("3.50"), submitted_country_code=submitted,
        created_by_user_id=None, name="Test",
    )
    nested = MagicMock()
    nested.__aenter__ = AsyncMock()
    nested.__aexit__ = AsyncMock(return_value=False)
    existing = MagicMock()
    existing.scalar_one_or_none.return_value = None
    db = SimpleNamespace(
        get=AsyncMock(side_effect=[product, SimpleNamespace(id=store_id, country_code=store_country)]),
        add=MagicMock(), execute=AsyncMock(return_value=existing),
        commit=AsyncMock(), flush=AsyncMock(), begin_nested=MagicMock(return_value=nested),
    )
    # GBP reports without a verified package never enter legacy StoreProduct.
    # The real-DB UK submission suite verifies usable RegionalProductOffer.
    asyncio.run(review_product(product.id, approve=True, db=db, current_user=SimpleNamespace(role="admin", id=uuid4())))
    assert product.review_status == "approved"
    assert sum(isinstance(call.args[0], StoreProduct) for call in db.add.call_args_list) == expected_links
