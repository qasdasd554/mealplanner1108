"""Used exact barcodes refresh in the background, never a catalogue crawl."""

import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import httpx
import pytest
from fastapi import BackgroundTasks
from sqlalchemy import select

from app.models.off_catalogue_product import OffCatalogueProduct
from app.services import off_on_demand as subject
from app.services.off_catalogue import import_off_catalogue
from tests.test_off_catalogue import database, raw
from tests.test_regional_shopping import db as shopping_db
from tests.test_community_price_integration import setup_community_catalogue, catalogue_db


NOW = datetime(2026, 10, 24, 12, tzinfo=timezone.utc)
CODE = raw()["code"]


@pytest.fixture(autouse=True)
def clean_limiter():
    subject._active.clear()
    subject._attempts.clear()
    subject._window.clear()
    subject._backoff_until = 0


def setup_io(database, monkeypatch, handler):
    session, adapter = database
    adapter.commit = AsyncMock(side_effect=session.commit)
    @asynccontextmanager
    async def session_factory():
        try:
            yield adapter
        finally:
            session.rollback()  # Like AsyncSession.close: release an uncommitted SELECT.
    monkeypatch.setattr(subject, "_session_factory", session_factory)
    requests = []
    async def transport(request):
        assert not session.in_transaction()  # Never hold its DB connection across HTTP.
        requests.append(request)
        return await handler(request)
    factory = httpx.AsyncClient
    monkeypatch.setattr(subject, "_client_factory", lambda **kwargs:
        factory(transport=httpx.MockTransport(transport), **kwargs))
    return session, adapter, requests


async def success(request):
    return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": raw()})


def test_fresh_cache_makes_no_external_request(database, monkeypatch):
    session, adapter, requests = setup_io(database, monkeypatch, success)
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW - timedelta(days=1)))
    session.commit()
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "fresh"
    assert requests == []


def test_stale_refresh_is_one_exact_request_and_retains_package_and_nutrition(database, monkeypatch):
    session, adapter, requests = setup_io(database, monkeypatch, success)
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW - timedelta(days=31)))
    session.commit()
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "checked"
    session.expire_all()
    item = session.get(OffCatalogueProduct, CODE)
    assert item.retrieved_at.replace(tzinfo=timezone.utc) == NOW
    assert item.package_quantity == 450 and item.nutrition_per_100["kcal"] == 60
    assert len(requests) == 1
    assert requests[0].url.host == "world.openfoodfacts.org"
    assert requests[0].url.path.endswith(f"/{CODE}.json")
    assert requests[0].url.params["cc"] == "uk"
    assert requests[0].headers["User-Agent"]


@pytest.mark.parametrize("kind", ["503", "429", "404", "timeout", "bad_json", "wrong_code", "not_uk", "obsolete", "oversized"])
def test_failed_refresh_does_not_renew_old_evidence_or_fail_the_scan(database, monkeypatch, kind):
    async def handler(request):
        if kind.isdigit(): return httpx.Response(int(kind))
        if kind == "timeout": raise httpx.ReadTimeout("test", request=request)
        if kind == "bad_json": return httpx.Response(200, content=b"not-json")
        if kind == "oversized": return httpx.Response(200, content=b"x" * 1_000_001)
        change = {"wrong_code": {"code": "5901234123457"}, "not_uk": {"countries_tags": ["en:poland"]},
                  "obsolete": {"obsolete": True}}[kind]
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": raw(**change)})
    session, adapter, requests = setup_io(database, monkeypatch, handler)
    old = NOW - timedelta(days=31)
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=old))
    session.commit()
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "unavailable"
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "cooldown"
    session.expire_all()
    assert session.get(OffCatalogueProduct, CODE).retrieved_at.replace(tzinfo=timezone.utc) == old
    assert len(requests) == 1


def test_parallel_same_code_is_deduplicated_and_does_not_wait_in_a_queue(database, monkeypatch):
    entered, release = asyncio.Event(), asyncio.Event()
    async def delayed(request):
        entered.set()
        await release.wait()
        return await success(request)
    _, _, requests = setup_io(database, monkeypatch, delayed)
    async def run():
        first = asyncio.create_task(subject.refresh_requested_off_product(CODE, now=NOW))
        await entered.wait()
        assert await subject.refresh_requested_off_product(CODE, now=NOW) == "cooldown"
        release.set()
        assert await first == "checked"
    asyncio.run(run())
    assert len(requests) == 1


def test_busy_or_circuit_open_skips_without_db_or_http(monkeypatch):
    monkeypatch.setattr(subject, "_session_factory", MagicMock(side_effect=AssertionError("unexpected DB")))
    subject._active.update({"other1", "other2"})
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "busy"
    subject._active.clear()
    subject._backoff_until = subject.time.monotonic() + 60
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "backoff"


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("source", ["catalog", "cache"])
def test_local_scan_only_schedules_uk_refresh_after_response(country, source, monkeypatch):
    from app.api.v1 import products
    nutrition = {"kcal": 60, "protein": 4, "fat": 2, "carbs": 6}
    record = SimpleNamespace(id=uuid4(), name="Yoghurt", brand="Test", unit="g",
        barcode=CODE, serving_quantity=450, nutrition_per_100=nutrition, source="open_food_facts",
        price_min=0, price_max=0)
    first, second = MagicMock(), MagicMock()
    first.scalar_one_or_none.return_value = record if source == "catalog" else None
    second.scalar_one_or_none.return_value = record
    db = SimpleNamespace(execute=AsyncMock(side_effect=[first, second]), rollback=AsyncMock())
    external = AsyncMock(side_effect=AssertionError("scan must remain local"))
    monkeypatch.setattr(products, "lookup_barcode_external", external)
    tasks = BackgroundTasks()
    result = asyncio.run(products.lookup_barcode(CODE, tasks, db, SimpleNamespace(id=uuid4(), country_code=country)))
    assert result.kcal_per_100 == 60 and db.execute.await_count == 2
    assert len(tasks.tasks) == (1 if country == "GB" else 0)
    assert db.rollback.await_count == (1 if country == "GB" else 0)
    if country == "GB":
        assert tasks.tasks[0].func is subject.refresh_requested_off_product
        assert tasks.tasks[0].args == (CODE,)


@pytest.mark.parametrize("barcode", ["not-a-barcode", "5901234123458", "https://example.invalid/x"])
def test_invalid_codes_do_not_start_network_or_database(monkeypatch, barcode):
    monkeypatch.setattr(subject, "_session_factory", MagicMock(side_effect=AssertionError("unexpected DB")))
    assert asyncio.run(subject.refresh_requested_off_product(barcode, now=NOW)) == "invalid"


@pytest.mark.parametrize("writer", ["scan", "search"])
def test_background_writer_preserves_source_fetch_time_not_queue_time(monkeypatch, writer):
    from app.api.v1 import products
    from app.db import session as sessions
    from app.services import off_catalogue

    stored = SimpleNamespace(commit=AsyncMock())
    @asynccontextmanager
    async def factory():
        yield stored
    monkeypatch.setattr(sessions, "async_session_factory", factory)
    monkeypatch.setattr(products, "_upsert_barcode_cache", AsyncMock())
    write = AsyncMock()
    monkeypatch.setattr(off_catalogue, "import_off_catalogue", write)
    clock = "2026-10-22T10:00:00+00:00"
    if writer == "scan":
        asyncio.run(products._persist_barcode_cache_in_background(
            barcode=CODE, off_product=raw(), off_retrieved_at=clock))
    else:
        asyncio.run(products._persist_off_catalogue_in_background([raw()], retrieved_at=clock))
    write.assert_awaited_once()
    assert write.await_args.kwargs["retrieved_at"] == datetime.fromisoformat(clock)


@pytest.mark.parametrize("clock", ["2126-01-01T00:00:00+00:00", "2026-01-01T00:00:00", "not-date"])
def test_background_writer_cannot_create_future_or_undated_evidence(monkeypatch, clock):
    from app.api.v1 import products
    from app.db import session as sessions
    from app.services import off_catalogue

    stored = SimpleNamespace(commit=AsyncMock())
    @asynccontextmanager
    async def factory():
        yield stored
    monkeypatch.setattr(sessions, "async_session_factory", factory)
    write = AsyncMock()
    monkeypatch.setattr(off_catalogue, "import_off_catalogue", write)
    asyncio.run(products._persist_off_catalogue_in_background([raw()], retrieved_at=clock))
    write.assert_not_awaited()
    stored.commit.assert_not_awaited()


def test_refresh_budget_is_bounded_and_does_not_queue_more_requests(monkeypatch):
    empty = MagicMock()
    empty.scalars.return_value.all.return_value = []
    @asynccontextmanager
    async def factory():
        yield SimpleNamespace(execute=AsyncMock(return_value=empty))
    monkeypatch.setattr(subject, "_session_factory", factory)
    monkeypatch.setattr(subject, "_client_factory", MagicMock(side_effect=AssertionError("budget exceeded")))
    subject._window.extend([subject.time.monotonic()] * 6)
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "backoff"
    assert subject._active == set()


def test_future_cache_is_not_treated_as_a_fresh_lookup(database, monkeypatch):
    session, adapter, requests = setup_io(database, monkeypatch, success)
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=NOW + timedelta(days=1)))
    session.commit()
    assert asyncio.run(subject.refresh_requested_off_product(CODE, now=NOW)) == "checked"
    assert len(requests) == 1  # The monotonic writer still cannot rewrite the future row.
    session.expire_all()
    assert session.get(OffCatalogueProduct, CODE).retrieved_at.replace(tzinfo=timezone.utc) > NOW


def test_http_dependency_releases_request_transaction_before_background_http(shopping_db, monkeypatch):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.v1 import products
    from app.db.session import get_db

    session, adapter, user, product, _ = shopping_db
    product.barcode = CODE
    product.nutrition_per_100 = {"kcal": 60, "protein": 4, "fat": 2, "carbs": 6}
    session.commit()
    adapter.rollback = AsyncMock(side_effect=session.rollback)
    events = []
    async def dependency():
        events.append("request-db-enter")
        try:
            yield adapter
        finally:
            events.append("request-db-cleanup")
    async def refresh(code):
        # Yield dependency cleanup occurs after BackgroundTasks in the current
        # FastAPI. The explicit rollback must have released its connection now.
        assert code == CODE and not session.in_transaction()
        events.append("background-http")
    monkeypatch.setattr(subject, "refresh_requested_off_product", refresh)
    app = FastAPI()
    app.include_router(products.router, prefix="/products")
    app.dependency_overrides[get_db] = dependency
    app.dependency_overrides[products.get_current_user] = lambda: user
    with TestClient(app) as client:
        response = client.get(f"/products/barcode/{CODE}")
    assert response.status_code == 200
    assert response.json()["kcal_per_100"] == 60
    assert events == ["request-db-enter", "background-http", "request-db-cleanup"]
    adapter.rollback.assert_awaited_once()


def test_same_gtin_alias_cannot_bypass_deduplication(monkeypatch):
    subject._attempts[CODE.zfill(14)] = subject.time.monotonic()
    monkeypatch.setattr(subject, "_session_factory", MagicMock(side_effect=AssertionError("unexpected DB")))
    assert asyncio.run(subject.refresh_requested_off_product("0" + CODE, now=NOW)) == "cooldown"


def test_changed_off_facts_invalidate_review_without_approving_a_new_mapping(catalogue_db, monkeypatch):
    from copy import deepcopy
    from tests.test_regional_shopping import AsyncDB
    from tests.test_uk_reviewed_staples import EVIDENCE
    from app.models import OffIngredientMapping
    from app.services.off_availability import off_available_product_ids

    session, reviewer, _ = catalogue_db
    _, canonical, _ = setup_community_catalogue(session, reviewer)
    product_id = canonical.id
    adapter = AsyncDB(session)
    clock = NOW + timedelta(days=8)
    assert asyncio.run(off_available_product_ids(adapter, [product_id], as_of=clock.date())) == {product_id}
    session.rollback()
    @asynccontextmanager
    async def factory():
        try:
            yield adapter
        finally:
            session.rollback()
    monkeypatch.setattr(subject, "_session_factory", factory)
    changed = deepcopy(next(row["product"] for row in EVIDENCE["products"] if row["barcode_requested"] == "20522605"))
    changed["product_name_en"] = "Changed label requiring a new review"
    changed["last_modified_t"] += 1
    client_factory = httpx.AsyncClient
    monkeypatch.setattr(subject, "_client_factory", lambda **kwargs: client_factory(
        transport=httpx.MockTransport(lambda request: httpx.Response(200,
            json={"status": "success", "result": {"id": "product_found"}, "product": changed})), **kwargs))
    assert asyncio.run(subject.refresh_requested_off_product("20522605", now=clock)) == "checked"
    assert asyncio.run(off_available_product_ids(adapter, [product_id], as_of=clock.date())) == set()
    session.expire_all()
    link = session.scalar(select(OffIngredientMapping).where(OffIngredientMapping.product_id == product_id))
    cached = session.get(OffCatalogueProduct, "20522605")
    assert link.off_fingerprint != cached.fingerprint  # Review is retained, never silently rewritten.
