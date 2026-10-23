"""Reviewed UK shop catalogue HTTP contract, synthetic evidence, local DB only."""

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.api.v1 import stores
from app.core.exceptions import AppException
from app.db.session import Base, get_db
from app.models import Product, Store, StoreProduct
from tests.uk_regional_fixtures import reviewed_offer, uk_store


@pytest.fixture
def state():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as db:
        gb = uk_store(db, slug="tesco")
        pl = Store(id=uuid4(), name="PL shop", country_code="PL", currency_code="PLN")
        product = Product(id=uuid4(), name="Polska nazwa", unit="g", default_quantity=100,
                          nutrition_per_100={"kcal": 123}, review_status="approved")
        db.add_all([pl, product])
        db.flush()
        offer = reviewed_offer(db, product, gb, quantity="750", price="1.25")
        # Deliberately wrong for UK: this must never become a GBP quote.
        db.add_all([StoreProduct(id=uuid4(), store_id=gb.id, product_id=product.id,
                                price=Decimal("99.99"), is_available=True),
                    StoreProduct(id=uuid4(), store_id=pl.id, product_id=product.id,
                                 price=Decimal("3.99"), is_available=True)])
        db.commit()
        account = SimpleNamespace(id=uuid4(), country_code="GB", role="user")
        app = FastAPI()
        app.include_router(stores.router, prefix="/stores")

        @app.exception_handler(AppException)
        async def handle(request, error):
            return JSONResponse(status_code=error.status_code, content={"detail": error.detail})

        class Adapter:
            async def execute(self, statement):
                return db.execute(statement)

        app.dependency_overrides[get_db] = lambda: Adapter()
        app.dependency_overrides[get_current_user] = lambda: account
        yield SimpleNamespace(client=TestClient(app), db=db, account=account,
                              gb=gb, pl=pl, product=product, offer=offer)
    engine.dispose()


def rows(state, query=""):
    response = state.client.get(f"/stores/{state.gb.id}/products{query}")
    assert response.status_code == 200, response.text
    return response.json()


def test_uk_exposes_reviewed_sku_package_and_provenance_not_polish_pack(state):
    value, = rows(state)
    assert value["id"] == str(state.offer.id)
    assert value["product_id"] == str(state.product.id)
    assert value["name_en"] == state.offer.name_en
    assert value["price"] == 1.25
    assert value["currency_code"] == "GBP"
    assert value["package_quantity"] == 750
    assert value["package_unit"] == "g"
    assert value["price_is_estimated"] is False
    assert value["price_source"]["url"] == state.offer.price_source["url"]
    assert value["availability_scope"] == "online_catalogue"
    assert value["product"]["name"] == "Polska nazwa"  # no global mutation
    assert state.product.default_quantity == 100


@pytest.mark.parametrize("bad", ["stale", "future", "changed_price", "foreign_domain",
                                 "out_of_stock", "unknown_stock", "pending_product", "dimension"])
def test_invalid_or_unavailable_evidence_is_never_exposed(state, bad):
    if bad == "stale":
        old = (datetime.now(timezone.utc) - timedelta(days=31)).date().isoformat()
        state.offer.package_source = {**state.offer.package_source, "checked_on": old}
    elif bad == "future":
        state.offer.reviewed_at = datetime.now(timezone.utc) + timedelta(days=1)
    elif bad == "changed_price":
        state.offer.price = Decimal("2.00")  # fingerprint no longer matches
    elif bad == "foreign_domain":
        state.offer.price_source = {**state.offer.price_source, "url": "https://evil.invalid/item"}
    elif bad == "out_of_stock":
        state.offer.availability_status = "out_of_stock"
    elif bad == "unknown_stock":
        state.offer.availability_status = "unknown"
    elif bad == "pending_product":
        state.product.review_status = "pending"
    elif bad == "dimension":
        state.product.unit = "ml"
    state.db.commit()
    assert rows(state) == []


def test_estimate_is_labelled_even_with_fresh_evidence(state):
    estimated = reviewed_offer(state.db, state.product, state.gb, kind="estimate", price="1.30")
    state.db.commit()
    value = next(row for row in rows(state) if row["id"] == str(estimated.id))
    assert value["price_is_estimated"] is True
    assert value["last_verified"] is None
    assert value["estimate_reason"]
    assert value["price_source"]["checked_on"]


def test_search_includes_local_sku_name_and_escapes_literal_wildcards(state):
    assert len(rows(state, "?search=synthetic")) == 1
    assert rows(state, "?search=does-not-exist") == []
    assert rows(state, "?search=%25") == []
    assert rows(state, "?search=_") == []


def test_valid_rows_are_paginated_after_evidence_validation_with_stable_ties(state):
    state.offer.fingerprint = "0" * 64
    good = [reviewed_offer(state.db, state.product, state.gb, sku=f"good-{i:03}") for i in range(6)]
    state.db.commit()
    all_ids = [row["id"] for row in rows(state)]
    assert len(all_ids) == 6
    assert set(all_ids) == {str(item.id) for item in good}
    pages = [row["id"] for offset in (0, 2, 4) for row in rows(state, f"?skip={offset}&limit=2")]
    assert pages == all_ids


def test_polish_catalogue_preserves_legacy_price_and_package(state):
    state.account.country_code = "PL"
    response = state.client.get(f"/stores/{state.pl.id}/products")
    assert response.status_code == 200
    value, = response.json()
    assert value["price"] == 3.99
    assert value["currency_code"] == "PLN"
    assert value["product"]["default_quantity"] == 100
    assert value.get("package_quantity") is None


def test_foreign_market_still_requires_explicit_admin_context(state):
    state.account.country_code = "PL"
    assert state.client.get(f"/stores/{state.gb.id}/products").status_code == 404
    assert state.client.get(f"/stores/{state.gb.id}/products?market=GB").status_code == 403
    state.account.role = "admin"
    assert len(rows(state, "?market=GB")) == 1
    assert state.account.country_code == "PL"


@pytest.mark.parametrize("suffix", ["", "/departments"])
def test_admin_context_also_applies_to_store_details(state, suffix):
    state.account.country_code, state.account.role = "PL", "admin"
    response = state.client.get(f"/stores/{state.gb.id}{suffix}?market=GB")
    assert response.status_code == 200
    assert state.account.country_code == "PL"
