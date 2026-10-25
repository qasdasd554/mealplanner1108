"""OFF product facts are not shop offers. Synthetic fixtures, no network."""

import asyncio
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.models.off_catalogue_product import OffCatalogueProduct
from app.services.off_catalogue import catalogue_values, import_off_catalogue, search_off_catalogue

NOW = datetime.now(timezone.utc)


def raw(**changes):
    return {
        "code": "5025125000006", "product_name_en": "Synthetic yoghurt",
        "brands": "Test brand", "countries_tags": ["en:united-kingdom"],
        "stores": "Tesco,Asda", "product_quantity": 450,
        "product_quantity_unit": "g", "last_modified_t": 1700000000,
        "nutriments": {"energy-kcal_100g": 60, "proteins_100g": 4,
                       "fat_100g": 2, "carbohydrates_100g": 6}, **changes,
    }


def test_real_fields_keep_pack_and_macros_without_any_price_or_stock():
    values = catalogue_values(raw(), retrieved_at=NOW)
    assert values["barcode"] == "5025125000006"
    assert values["name"] == "Synthetic yoghurt"
    assert values["package_quantity"] == 450 and values["base_unit"] == "g"
    assert values["nutrition_per_100"] == {"kcal": 60, "protein": 4, "fat": 2, "carbs": 6}
    assert values["reported_stores"] == ["Tesco", "Asda"]
    assert values["source_url"] == "https://world.openfoodfacts.org/product/5025125000006"
    assert values["licence"] == "ODbL-1.0"
    assert not {"price", "currency", "store_id", "is_available"}.intersection(values)


@pytest.mark.parametrize("change", [
    {"countries_tags": ["en:poland"]}, {"countries_tags": []},
    {"countries_tags": "en:united-kingdom"}, {"code": "5025125000007"},
    {"code": "prefix5025125000006"}, {"obsolete": "on"},
    {"product_name_en": "", "product_name": ""},
    {"last_modified_t": float("nan")}, {"last_modified_t": True},
    {"last_modified_t": int((NOW + timedelta(days=2)).timestamp())},
])
def test_bad_identity_country_or_metadata_never_enters_catalogue(change):
    assert catalogue_values(raw(**change), retrieved_at=NOW) is None


def test_missing_nutrition_and_pack_are_unknown_never_100g_or_zero():
    values = catalogue_values(raw(nutriments={}, product_quantity=None), retrieved_at=NOW)
    assert values["package_quantity"] is None
    assert all(value is None for value in values["nutrition_per_100"].values())


def test_per_serving_and_estimated_macros_are_not_copied_as_per100():
    values = catalogue_values(raw(nutrition_data_per="serving", nutriments={"energy-kcal": 60},
                                 nutriments_estimated={"proteins_100g": 10}), retrieved_at=NOW)
    assert all(value is None for value in values["nutrition_per_100"].values())


@pytest.mark.parametrize("size,unit,expected_size,expected_unit", [
    (500, "ml", 500, "ml"), (0.5, "kg", 500, "g"),
    (float("inf"), "g", None, "g"), (0, "g", None, "g"),
    (12, "oz", None, "g"),
])
def test_package_dimension_is_not_guessed(size, unit, expected_size, expected_unit):
    values = catalogue_values(raw(product_quantity=size, product_quantity_unit=unit), retrieved_at=NOW)
    assert values["package_quantity"] == expected_size
    assert values["base_unit"] == expected_unit


def test_provenance_fingerprint_ignores_fetch_time_but_detects_changed_label():
    first = catalogue_values(raw(), retrieved_at=NOW)
    later = catalogue_values(raw(), retrieved_at=NOW + timedelta(hours=1))
    changed = catalogue_values(raw(product_quantity=500), retrieved_at=NOW)
    assert first["fingerprint"] == later["fingerprint"] != changed["fingerprint"]


@pytest.fixture
def database():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    OffCatalogueProduct.__table__.create(engine)
    with Session(engine) as db:
        class Adapter:
            async def execute(self, statement):
                return db.execute(statement)

            def get_bind(self):
                return db.get_bind()

        yield db, Adapter()
    engine.dispose()


def test_import_is_idempotent_monotonic_and_separate_from_app_data(database):
    db, adapter = database
    assert asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW)) == 1
    assert asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW)) == 1
    assert db.scalar(select(func.count()).select_from(OffCatalogueProduct)) == 1
    newer = raw(last_modified_t=1700000100, product_quantity=500)
    asyncio.run(import_off_catalogue(adapter, [newer], retrieved_at=NOW))
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW))
    db.expire_all()
    assert db.get(OffCatalogueProduct, "5025125000006").package_quantity == 500
    db.rollback()
    assert db.scalar(select(func.count()).select_from(OffCatalogueProduct)) == 0


def test_country_search_returns_real_fields_and_no_pln_ranges(database):
    db, adapter = database
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW))
    result, = asyncio.run(search_off_catalogue(adapter, "yoghurt", country_code="GB", limit=10))
    assert result.kcal_per_100 == 60 and result.serving_quantity == 450
    assert result.source == "open_food_facts"
    assert result.price_min is None and result.price_max is None
    assert result.existing_product_id is None
    assert asyncio.run(search_off_catalogue(adapter, "%", country_code="GB", limit=10)) == []
    assert asyncio.run(search_off_catalogue(adapter, "_", country_code="GB", limit=10)) == []
    assert asyncio.run(search_off_catalogue(adapter, "yoghurt", country_code="PL", limit=10)) == []


def test_no_query_for_polish_account_or_too_short_input():
    db = SimpleNamespace(execute=AsyncMock())
    assert asyncio.run(search_off_catalogue(db, "yoghurt", country_code="PL", limit=10)) == []
    assert asyncio.run(search_off_catalogue(db, "a", country_code="GB", limit=10)) == []
    db.execute.assert_not_awaited()


def test_bounded_import_rejects_large_batch_before_writing():
    db = SimpleNamespace(execute=AsyncMock())
    with pytest.raises(ValueError, match="500"):
        asyncio.run(import_off_catalogue(db, [raw()] * 501, retrieved_at=NOW))
    db.execute.assert_not_awaited()


def test_same_revision_conflict_does_not_replace_existing_data(database):
    db, adapter = database
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW))
    asyncio.run(import_off_catalogue(adapter, [raw(product_quantity=1)], retrieved_at=NOW))
    assert db.get(OffCatalogueProduct, "5025125000006").package_quantity == 450


@pytest.mark.parametrize("revision,size", [(1700000000, 450), (1700000100, 500)])
def test_older_fetch_never_replaces_a_more_recent_snapshot(database, revision, size):
    db, adapter = database
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW))
    asyncio.run(import_off_catalogue(adapter, [raw(last_modified_t=revision, product_quantity=size)],
                                     retrieved_at=NOW - timedelta(hours=1)))
    db.expire_all()
    stored = db.get(OffCatalogueProduct, "5025125000006")
    assert stored.retrieved_at.replace(tzinfo=timezone.utc) == NOW
    assert stored.source_modified_t == 1700000000
    assert stored.package_quantity == 450


@pytest.mark.parametrize("revision,size,expected_revision,expected_size,hours", [
    (1700000000, 450, 1700000000, 450, 1),
    (1700000100, 500, 1700000100, 500, 1),
    (1699999900, 400, 1700000000, 450, 0),
])
def test_later_fetch_refreshes_only_a_compatible_or_newer_source_revision(
        database, revision, size, expected_revision, expected_size, hours):
    db, adapter = database
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW))
    asyncio.run(import_off_catalogue(adapter, [raw(last_modified_t=revision, product_quantity=size)],
                                     retrieved_at=NOW + timedelta(hours=1)))
    db.expire_all()
    stored = db.get(OffCatalogueProduct, "5025125000006")
    assert stored.retrieved_at.replace(tzinfo=timezone.utc) == NOW + timedelta(hours=hours)
    assert stored.source_modified_t == expected_revision
    assert stored.package_quantity == expected_size


@pytest.mark.parametrize("offset,visible", [
    (timedelta(days=-30), True), (timedelta(0), True),
    (timedelta(microseconds=1), False), (timedelta(days=2), False),
    (timedelta(days=-30, microseconds=-1), False),
])
def test_country_search_obeys_both_exact_fetch_time_boundaries(database, offset, visible):
    _, adapter = database
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW + offset))
    results = asyncio.run(search_off_catalogue(
        adapter, "yoghurt", country_code="GB", limit=10, now=NOW))
    assert bool(results) is visible


def test_old_cache_does_not_permanently_hide_a_new_label(database):
    _, adapter = database
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW))
    assert asyncio.run(search_off_catalogue(adapter, "yoghurt", country_code="GB", limit=10,
                                           now=NOW + timedelta(days=31))) == []


def test_http_first_lookup_caches_off_after_response_and_next_lookup_is_local(database, monkeypatch):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.v1 import products
    from app.db.session import get_db
    from app.services import barcode_lookup

    db, adapter = database
    empty = MagicMock()
    empty.scalars.return_value.all.return_value = []
    original_execute = adapter.execute

    async def execute(statement):
        # A Product select now legitimately contains an OFF availability
        # subquery. Dispatch by the primary mapped entity/table, not SQL text.
        entities = getattr(statement, "column_descriptions", ())
        if (any(column.get("entity") is OffCatalogueProduct for column in entities)
                or getattr(statement, "entity_description", {}).get("entity") is OffCatalogueProduct):
            return await original_execute(statement)
        return empty

    adapter.execute = execute
    result = barcode_lookup._result_from_off_product(raw(), country_code="GB")
    result.off_product = raw()
    lookup = AsyncMock(return_value=[result])
    monkeypatch.setattr(barcode_lookup, "search_products_external", lookup)

    async def persist(records, *, retrieved_at=None):
        await import_off_catalogue(adapter, records, retrieved_at=datetime.fromisoformat(retrieved_at) if retrieved_at else NOW)

    monkeypatch.setattr(products, "_persist_off_catalogue_in_background", persist)
    app = FastAPI()
    app.include_router(products.router, prefix="/products")
    app.dependency_overrides[get_db] = lambda: adapter
    from uuid import uuid4
    app.dependency_overrides[products.get_current_user] = lambda: SimpleNamespace(id=uuid4(), country_code="GB")
    with TestClient(app) as client:
        first = client.get("/products/search-by-name?query=yoghurt&limit=1")
        second = client.get("/products/search-by-name?query=yoghurt&limit=1")
    assert first.status_code == second.status_code == 200
    assert first.json()[0]["kcal_per_100"] == second.json()[0]["kcal_per_100"] == 60
    assert second.json()[0]["serving_quantity"] == 450
    assert second.json()[0]["existing_product_id"] is None
    assert second.json()[0]["price_min"] is None
    lookup.assert_awaited_once()
    assert db.scalar(select(func.count()).select_from(OffCatalogueProduct)) == 1
