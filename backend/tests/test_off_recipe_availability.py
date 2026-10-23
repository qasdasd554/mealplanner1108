"""Country-level OFF availability is not a claim of stock at a retailer."""

import asyncio
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.models import Base, Product, Recipe, RecipeIngredient
from app.models.off_catalogue_product import OffCatalogueProduct
from app.services.off_catalogue import catalogue_values
from app.services.market_catalog import (apply_recipe_market_filter,
                                         ensure_recipe_available_in_market)

NOW = datetime.now(timezone.utc)
CODE = "5025125000006"


@pytest.fixture
def db():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    engine.dispose()


def facts(db, **changes):
    raw = {"code": CODE, "product_name_en": "Synthetic yoghurt",
           "countries_tags": ["en:united-kingdom"], "last_modified_t": 1700000000,
           "product_quantity": 450, "product_quantity_unit": "g", **changes}
    values = catalogue_values(raw, retrieved_at=NOW)
    row = OffCatalogueProduct(**values)
    db.add(row)
    db.flush()
    return row


def dish(db, *, barcode=CODE, unit="g", name="Synthetic yoghurt"):
    product = Product(id=uuid4(), name=name, unit=unit, barcode=barcode)
    row = Recipe(id=uuid4(), name="Synthetic recipe", meal_type="obiad")
    db.add_all([product, row])
    db.flush()
    db.add(RecipeIngredient(id=uuid4(), recipe_id=row.id, product_id=product.id,
                            quantity=100, unit=unit, is_optional=False))
    db.flush()
    return row, product


def visible(db, *, market="GB", store=None):
    return set(db.scalars(apply_recipe_market_filter(
        select(Recipe.id), SimpleNamespace(country_code=market), store_id=store)))


class Adapter:
    def __init__(self, db):
        self.db = db

    async def execute(self, statement):
        return self.db.execute(statement)


def test_exact_barcode_reported_in_uk_qualifies_without_a_shop_offer(db):
    facts(db)
    row, _ = dish(db)
    assert visible(db) == {row.id}
    asyncio.run(ensure_recipe_available_in_market(
        Adapter(db), row, SimpleNamespace(country_code="GB")))


def test_same_name_is_not_identity_and_pl_behaviour_is_unchanged(db):
    facts(db)
    row, _ = dish(db, barcode=None)
    assert visible(db) == set()
    assert visible(db, market="PL") == {row.id}


@pytest.mark.parametrize("change", ["old", "foreign", "bad_source"])
def test_stale_or_foreign_evidence_is_not_accepted(db, change):
    row = facts(db)
    if change == "old":
        row.retrieved_at = NOW - timedelta(days=31)
    elif change == "foreign":
        row.country_code = "PL"
    else:
        row.source_url = "https://example.invalid/product/" + CODE
    dish(db)
    assert visible(db) == set()


def test_country_report_does_not_create_any_store_price_or_sku(db):
    from app.models import StoreProduct, RegionalProductOffer
    facts(db)
    dish(db)
    assert list(db.scalars(select(StoreProduct))) == []
    assert list(db.scalars(select(RegionalProductOffer))) == []
