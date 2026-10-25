"""Refreshed OFF facts invalidate live community quotes, not bought history."""

import asyncio
from datetime import date, timedelta
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.models import (
    OffCatalogueProduct, OffIngredientMapping, Product, Recipe, RegionalProductOffer, ShoppingListItem, User,
)
from app.services import market_catalog, regional_shopping
from app.services.regional_store_catalogue import list_reviewed_store_products
from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
from tests.test_community_price_integration import setup_community_catalogue
from tests.test_uk_catalogue_import import catalogue_db
from tests.test_regional_shopping import AsyncDB, make_plan


@pytest.fixture
def current_catalogue(catalogue_db, monkeypatch):
    session, reviewer, _ = catalogue_db
    row, canonical, now = setup_community_catalogue(session, reviewer)
    adapter = AsyncDB(session)
    asyncio.run(import_reviewed_uk_catalogue(adapter, [row], reviewer_user_id=reviewer,
        reviewed_at=now, as_of=now.date()))
    user = User(id=uuid4(), email="community-live-evidence@example.test", password_hash="fixture",
        country_code="GB", is_premium=True)
    session.add(user)
    session.commit()
    plan = make_plan(session, user, canonical, quantity="600", include_pantry=False, store_id=row.store_id)
    recipe_id = plan.entries[0].recipe_id
    monkeypatch.setattr(regional_shopping, "regional_pricing_date", lambda: now.date())
    return session, adapter, row, canonical.id, now, recipe_id


def live_paths(state):
    session, adapter, row, product_id, now, _ = state
    direct = list(session.scalars(select(RegionalProductOffer).where(
        RegionalProductOffer.id == row.proposal_id,
        *market_catalog.reviewed_uk_offer_conditions(as_of=now.date()))))
    shopping = asyncio.run(regional_shopping.load_regional_offers(adapter, {product_id}, row.store_id))
    store = asyncio.run(list_reviewed_store_products(adapter, row.store_id,
        skip=0, limit=20, search=None, department_id=None, as_of=now.date()))
    return direct, shopping, store


def test_current_community_evidence_is_available_in_each_live_path(current_catalogue):
    assert all(len(rows) == 1 for rows in live_paths(current_catalogue))


@pytest.mark.parametrize("change", [
    "fingerprint", "pack", "off_name", "off_dimension", "off_stale", "off_future",
    "canonical_name", "canonical_brand", "canonical_unit", "canonical_unapproved",
    "mapping_missing", "mapping_fingerprint", "mapping_future", "mapping_dimension",
])
def test_changed_off_or_reviewed_identity_cannot_supply_a_live_quote(current_catalogue, change):
    session, _, row, product_id, now, _ = current_catalogue
    off = session.get(OffCatalogueProduct, "20522605")
    mapping = session.get(OffIngredientMapping, (product_id, "20522605"))
    product = session.get(Product, product_id)
    if change == "fingerprint": off.fingerprint = "f" * 64
    elif change == "pack": off.package_quantity = 400
    elif change == "off_name": off.name = "A different food"
    elif change == "off_dimension": off.base_unit = "ml"
    elif change == "off_stale": off.retrieved_at = now - timedelta(days=31)
    elif change == "off_future": off.retrieved_at = now + timedelta(days=2)
    elif change == "canonical_name": product.name = "Different ingredient"
    elif change == "canonical_brand": product.brand = "Different brand"
    elif change == "canonical_unit": product.unit = "ml"
    elif change == "canonical_unapproved": product.review_status = "pending"
    elif change == "mapping_missing": session.delete(mapping)
    elif change == "mapping_fingerprint": mapping.off_fingerprint = "f" * 64
    elif change == "mapping_future": mapping.reviewed_at = now + timedelta(days=2)
    elif change == "mapping_dimension": mapping.base_unit = "ml"
    session.commit()
    assert live_paths(current_catalogue) == ([], [], [])


def test_refresh_changed_fingerprint_cannot_keep_recipe_visible_via_stale_offer(current_catalogue):
    session, _, _, _, now, recipe_id = current_catalogue
    session.get(OffCatalogueProduct, "20522605").fingerprint = "f" * 64
    session.commit()
    assert session.scalar(select(Recipe.id).where(Recipe.id == recipe_id,
        market_catalog.recipe_market_availability("GB", as_of=now.date()))) is None


def test_changed_live_evidence_does_not_erase_a_bought_snapshot(current_catalogue):
    session, adapter, row, product_id, now, _ = current_catalogue
    product = session.get(Product, product_id)
    offers = asyncio.run(regional_shopping.load_regional_offers(adapter, {product_id}, row.store_id))
    item = ShoppingListItem(is_checked=False, is_from_pantry=False)
    regional_shopping.apply_regional_item_quote(item, product=product, store_id=row.store_id,
        quantity=Decimal("600"), unit="g", offers=offers, as_of=now.date())
    item.is_checked = True
    before = regional_shopping.frozen_regional_purchase_quote(item, as_of=now.date())
    assert before is not None and before.total_price == Decimal("0.90")
    session.get(OffCatalogueProduct, "20522605").fingerprint = "f" * 64
    session.commit()
    assert live_paths(current_catalogue) == ([], [], [])
    after = regional_shopping.frozen_regional_purchase_quote(item, as_of=now.date())
    assert after == before


def test_correlated_guard_compiles_for_postgres_without_unsafe_json_date_casts():
    from sqlalchemy.dialects import postgresql
    statement = select(Recipe.id).where(market_catalog.recipe_market_availability(
        "GB", as_of=date(2026, 10, 23)))
    sql = str(statement.compile(dialect=postgresql.dialect()))
    assert "off_ingredient_mappings" in sql and "off_catalogue_products" in sql
    assert "price_source ->>" in sql
