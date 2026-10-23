"""Same PL/GB lookup path: local catalogue/cache, then requested external facts.

No bulk country catalogue or per-scan import job is required.
"""
import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import BackgroundTasks
from app.api.v1 import products
from app.models import BarcodeProductCache
from app.services.barcode_lookup import BarcodeLookupResult

CODE = "5025125000006"


def response(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_complete_local_cache_returns_without_any_external_request(country, monkeypatch):
    cache = BarcodeProductCache(barcode=CODE, name="Synthetic yoghurt", unit="g",
        nutrition_per_100={"kcal":60, "protein":4, "fat":2, "carbs":6},
        serving_quantity=450, source="open_food_facts", price_min=2, price_max=4)
    db = SimpleNamespace(execute=AsyncMock(side_effect=[response(None), response(cache)]))
    external = AsyncMock()
    monkeypatch.setattr(products, "lookup_barcode_external", external)
    tasks = BackgroundTasks()
    result = asyncio.run(products.lookup_barcode(CODE, tasks, db,
        SimpleNamespace(id=uuid4(), country_code=country)))
    assert result.kcal_per_100 == 60 and result.serving_quantity == 450
    assert db.execute.await_count == 2
    external.assert_not_awaited()
    assert tasks.tasks == []
    assert all("off_catalogue_products" not in str(call.args[0])
               for call in db.execute.await_args_list)


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_cache_miss_uses_the_same_external_path_and_background_cache_write(country, monkeypatch):
    db = SimpleNamespace(execute=AsyncMock(side_effect=[response(None), response(None)]))
    external = AsyncMock(return_value=BarcodeLookupResult(
        name="Synthetic yoghurt", barcode=CODE, unit="g", serving_quantity=450,
        kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6,
        source="open_food_facts", brand=None, price_min=None, price_max=None))
    monkeypatch.setattr(products, "lookup_barcode_external", external)
    tasks = BackgroundTasks()
    result = asyncio.run(products.lookup_barcode(CODE, tasks, db,
        SimpleNamespace(id=uuid4(), country_code=country)))
    assert result.kcal_per_100 == 60 and result.serving_quantity == 450
    external.assert_awaited_once_with(CODE, **({"country_code":"GB"} if country == "GB" else {}))
    assert len(tasks.tasks) == 1
    assert tasks.tasks[0].func is products._persist_barcode_cache_in_background


def test_no_bulk_catalogue_endpoint_is_part_of_the_application():
    assert all(route.path != "/off-catalogue" for route in products.router.routes)
