"""Requested UK barcode facts retain country evidence, without extra I/O."""

import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import httpx
import pytest
from fastapi import BackgroundTasks

from app.api.v1 import products
from app.services import barcode_lookup as lookup
from tests.test_off_catalogue import raw


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_single_off_request_carries_country_facts_only_for_uk(country):
    record = raw()
    calls = []

    class Client:
        async def get(self, url, *, params):
            calls.append(params)
            return httpx.Response(200, request=httpx.Request("GET", url), json={
                "status": "success", "result": {"id": "product_found"},
                "product": record,
            })

    result = asyncio.run(lookup._fetch_off(Client(), record["code"], country_code=country))
    assert result is not None and result.kcal_per_100 == 60
    assert len(calls) == 1
    assert ("countries_tags" in calls[0]["fields"]) == (country == "GB")
    assert result.off_product == (record if country == "GB" else None)


def test_nutrition_merge_retains_original_off_evidence():
    record = raw(nutriments={})
    original = lookup._result_from_off_product(record, country_code="GB")
    supplementary = lookup.BarcodeLookupResult(
        name="Other provider", brand=None, unit="g", barcode=record["code"],
        kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6,
        price_min=0, price_max=0, source="usda_fooddata_central",
    )
    result = lookup.merge_lookup_results(original, supplementary)
    assert result.kcal_per_100 == 60
    assert result.off_product == record


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_evidence_is_only_scheduled_after_response_for_uk(country, monkeypatch):
    record = raw()
    external = lookup.BarcodeLookupResult(
        name="Synthetic yoghurt", brand=None, unit="g", barcode=record["code"],
        kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6,
        price_min=2, price_max=4, source="open_food_facts", off_product=record,
    )
    empty = MagicMock()
    empty.scalar_one_or_none.return_value = None
    db = SimpleNamespace(execute=AsyncMock(return_value=empty))
    monkeypatch.setattr(products, "lookup_barcode_external", AsyncMock(return_value=external))
    tasks = BackgroundTasks()
    response = asyncio.run(products.lookup_barcode(record["code"], tasks, db,
        SimpleNamespace(id=uuid4(), country_code=country)))
    assert response.kcal_per_100 == 60 and db.execute.await_count == 2
    assert len(tasks.tasks) == 1
    task = tasks.tasks[0]
    assert task.func is products._persist_barcode_cache_in_background
    assert task.kwargs.get("off_product") == (record if country == "GB" else None)


def test_background_evidence_uses_existing_validated_cache_not_shop_or_user_data(monkeypatch):
    from app.db import session as sessions
    from app.services import off_catalogue

    session = SimpleNamespace(commit=AsyncMock())
    context = MagicMock()
    context.__aenter__ = AsyncMock(return_value=session)
    context.__aexit__ = AsyncMock(return_value=False)
    monkeypatch.setattr(sessions, "async_session_factory", lambda: context)
    nutrition_cache = AsyncMock()
    country_cache = AsyncMock()
    monkeypatch.setattr(products, "_upsert_barcode_cache", nutrition_cache)
    monkeypatch.setattr(off_catalogue, "import_off_catalogue", country_cache)
    record = raw()
    asyncio.run(products._persist_barcode_cache_in_background(
        barcode=record["code"], off_product=record,
    ))
    nutrition_cache.assert_awaited_once_with(session, barcode=record["code"])
    country_cache.assert_awaited_once()
    assert country_cache.await_args.args == (session, [record])
    assert country_cache.await_args.kwargs["retrieved_at"].tzinfo is not None
    session.commit.assert_awaited_once()


def test_background_cache_does_not_attach_another_barcode_country_facts(monkeypatch):
    from app.db import session as sessions
    from app.services import off_catalogue

    session = SimpleNamespace(commit=AsyncMock())
    context = MagicMock()
    context.__aenter__ = AsyncMock(return_value=session)
    context.__aexit__ = AsyncMock(return_value=False)
    monkeypatch.setattr(sessions, "async_session_factory", lambda: context)
    nutrition_cache = AsyncMock()
    country_cache = AsyncMock()
    monkeypatch.setattr(products, "_upsert_barcode_cache", nutrition_cache)
    monkeypatch.setattr(off_catalogue, "import_off_catalogue", country_cache)
    asyncio.run(products._persist_barcode_cache_in_background(
        barcode="5901234123457", off_product=raw(),
    ))
    nutrition_cache.assert_awaited_once_with(session, barcode="5901234123457")
    country_cache.assert_not_awaited()
    session.commit.assert_not_awaited()


def test_country_cache_failure_does_not_undo_the_existing_nutrition_cache(monkeypatch):
    from app.db import session as sessions
    from app.services import off_catalogue

    session = SimpleNamespace(commit=AsyncMock())
    context = MagicMock()
    context.__aenter__ = AsyncMock(return_value=session)
    context.__aexit__ = AsyncMock(return_value=False)
    monkeypatch.setattr(sessions, "async_session_factory", lambda: context)
    nutrition_cache = AsyncMock()  # Original writer has already committed.
    monkeypatch.setattr(products, "_upsert_barcode_cache", nutrition_cache)
    monkeypatch.setattr(off_catalogue, "import_off_catalogue", AsyncMock(side_effect=RuntimeError("Synthetic failure")))
    record = raw()
    asyncio.run(products._persist_barcode_cache_in_background(
        barcode=record["code"], off_product=record,
    ))
    nutrition_cache.assert_awaited_once_with(session, barcode=record["code"])
    session.commit.assert_not_awaited()


@pytest.mark.parametrize("value", [float("nan"), float("inf")])
def test_invalid_raw_provider_numbers_never_leak_through_country_metadata(value):
    record = raw(product_quantity=value)
    result = lookup._result_from_off_product(record, country_code="GB")
    assert result.serving_quantity is None
    assert result.off_product is None
    json.dumps(result.__dict__, allow_nan=False)
