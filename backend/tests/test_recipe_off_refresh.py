"""Public recipe country evidence cannot depend on someone rescanning its GTIN."""

import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI
from sqlalchemy import delete, event, select
from sqlalchemy.dialects import postgresql

from app.api.v1 import recipes
from app.db.session import get_db
from app.models import OffCatalogueProduct, OffIngredientMapping, Product, Recipe, RecipeIngredient, RegionalProductOffer, User
from app.services import off_on_demand as subject
from app.services import market_catalog
from app.services.off_catalogue import import_off_catalogue
from app.services.off_ingredient_mapping import import_reviewed_off_mappings
from tests.test_off_catalogue import raw
from tests.test_regional_shopping import db


NOW = datetime(2026, 10, 24, 20, tzinfo=timezone.utc)
CODE = raw()["code"]


@pytest.fixture(autouse=True)
def reset_limits():
    subject._active.clear()
    subject._attempts.clear()
    subject._window.clear()
    subject._backoff_until = 0
    subject._catalogue_next_check = 0
    subject._catalogue_refresh_running = False


def setup_recipe(db, *, age=31, exact=False, public=True, optional=False):
    session, adapter, user, product, _ = db
    session.execute(delete(RegionalProductOffer))
    product_id, user_id = product.id, user.id
    product.barcode = CODE if exact else None
    recipe = Recipe(id=uuid4(), name="Recipe with real ingredients", meal_type="obiad",
        created_by_user_id=user_id, visibility="public" if public else "private", is_active=True)
    recipe.ingredients = [RecipeIngredient(id=uuid4(), product_id=product_id,
        quantity=100, unit="g", is_optional=optional)]
    session.add(recipe)
    session.commit()
    old = NOW - timedelta(days=age)
    asyncio.run(import_off_catalogue(adapter, [raw()], retrieved_at=old))
    session.commit()
    if not exact:
        cached = session.get(OffCatalogueProduct, CODE)
        asyncio.run(import_reviewed_off_mappings(adapter, [dict(product_id=product_id,
            product_name=product.name, product_unit=product.unit, product_brand=product.brand,
            off_barcode=CODE, off_fingerprint=cached.fingerprint,
            review_note="Reviewed plain yoghurt food concept, not a price or package substitution.")],
            reviewer_user_id=user_id, reviewed_at=old, as_of=old.date()))
        session.commit()
    return session, adapter, user_id, product_id, recipe.id


def connect_io(db, monkeypatch, handler=None):
    session, adapter, *_ = db
    @asynccontextmanager
    async def factory():
        try:
            yield adapter
        finally:
            session.rollback()
    monkeypatch.setattr(subject, "_session_factory", factory)
    requests = []
    async def transport(request):
        assert not session.in_transaction()  # No request or refresh transaction during OFF HTTP.
        requests.append(request)
        if handler:
            return await handler(request)
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": raw()})
    client_factory = httpx.AsyncClient
    monkeypatch.setattr(subject, "_client_factory", lambda **kwargs: client_factory(
        transport=httpx.MockTransport(transport), **kwargs))
    return requests


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_http_catalogue_schedules_refresh_after_body_and_releases_connection(db, monkeypatch, country):
    session, adapter, user_id, _, _ = setup_recipe(db)
    user = session.get(User, user_id)
    if country == "PL":
        user = User(id=uuid4(), email="pl-viewer@example.test", password_hash="fixture", country_code="PL")
        session.add(user)
        session.commit()
    adapter.rollback = AsyncMock(side_effect=session.rollback)
    events = []
    async def refresh():
        assert events[-1] == "body-sent"
        assert not session.in_transaction()
        events.append("background-refresh")
    monkeypatch.setattr(subject, "refresh_public_recipe_evidence", refresh, raising=False)
    monkeypatch.setattr(market_catalog, "utc_market_date", lambda: NOW.date())
    async def dependency():
        try:
            yield adapter
        finally:
            session.rollback()
    app = FastAPI()
    app.include_router(recipes.router, prefix="/recipes")
    app.dependency_overrides[get_db] = dependency
    app.dependency_overrides[recipes.get_current_user] = lambda: user
    async def observed(scope, receive, send):
        async def record(message):
            if message["type"] == "http.response.body" and not message.get("more_body", False):
                events.append("body-sent")
            await send(message)
        await app(scope, receive, record)
    async def request():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=observed), base_url="http://test") as client:
            return await client.get("/recipes/")
    response = asyncio.run(request())
    assert response.status_code == 200
    assert len(response.json()) == (1 if country == "PL" else 0)
    assert events == (["body-sent", "background-refresh"] if country == "GB" else ["body-sent"])
    assert adapter.rollback.await_count == int(country == "GB")


@pytest.mark.parametrize("exact", [False, True])
def test_expired_country_facts_recover_without_new_scan_or_identity_review(db, monkeypatch, exact):
    session, adapter, _, product_id, recipe_id = setup_recipe(db, exact=exact)
    original = session.get(Product, product_id)
    food_facts = (original.name, original.nutrition_per_100.copy(), original.serving_quantity)
    query = select(Recipe.id).where(Recipe.id == recipe_id,
        market_catalog.recipe_market_availability("GB", as_of=NOW.date()))
    assert session.scalar(query) is None
    session.rollback()
    requests = connect_io(db, monkeypatch)
    assert asyncio.run(subject.refresh_public_recipe_evidence(now=NOW)) == "checked"
    assert len(requests) == 1
    assert session.scalar(query) == recipe_id
    product = session.get(Product, product_id)
    assert (product.name, product.nutrition_per_100, product.serving_quantity) == food_facts
    if not exact:
        mapping = session.scalar(select(OffIngredientMapping).where(OffIngredientMapping.product_id == product_id))
        assert mapping.reviewed_at.replace(tzinfo=timezone.utc) == NOW - timedelta(days=31)


@pytest.mark.parametrize("kind", ["fresh", "private", "optional", "pending", "renamed", "changed-review", "future", "inactive"])
def test_only_due_reviewed_public_recipe_ingredients_can_trigger_http(db, monkeypatch, kind):
    session, _, _, product_id, recipe_id = setup_recipe(db,
        age=1 if kind == "fresh" else 10, public=kind != "private", optional=kind == "optional")
    if kind == "pending":
        session.get(Product, product_id).review_status = "pending"
    elif kind == "renamed":
        session.get(Product, product_id).name = "A different food"
    elif kind == "changed-review":
        session.scalar(select(OffIngredientMapping)).off_fingerprint = "a" * 64
    elif kind == "future":
        session.get(OffCatalogueProduct, CODE).retrieved_at = NOW + timedelta(days=1)
    elif kind == "inactive":
        session.get(Recipe, recipe_id).is_active = False
    session.commit()
    requests = connect_io(db, monkeypatch)
    assert asyncio.run(subject.refresh_public_recipe_evidence(now=NOW)) == "fresh"
    assert requests == []


@pytest.mark.parametrize("failure", ["503", "404", "changed", "not-uk"])
def test_failure_or_changed_fact_never_renews_review_or_creates_fake_availability(db, monkeypatch, failure):
    session, _, _, product_id, recipe_id = setup_recipe(db)
    original_review = session.scalar(select(OffIngredientMapping)).off_fingerprint
    session.rollback()
    async def handler(request):
        if failure.isdigit():
            return httpx.Response(int(failure))
        change = {"product_name_en": "Different yoghurt", "last_modified_t": 1700000100} if failure == "changed" else {"countries_tags": ["en:poland"]}
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": raw(**change)})
    requests = connect_io(db, monkeypatch, handler)
    asyncio.run(subject.refresh_public_recipe_evidence(now=NOW))
    assert len(requests) == 1
    assert session.scalar(select(OffIngredientMapping)).off_fingerprint == original_review
    assert session.scalar(select(Recipe.id).where(Recipe.id == recipe_id,
        market_catalog.recipe_market_availability("GB", as_of=NOW.date()))) is None


@pytest.mark.parametrize("kind", ["interval", "parallel", "scan-busy", "provider-backoff", "http-budget"])
def test_no_database_or_http_when_shared_refresh_budget_is_busy(monkeypatch, kind):
    if kind == "interval":
        subject._catalogue_next_check = subject.time.monotonic() + 60
    elif kind == "parallel":
        subject._catalogue_refresh_running = True
    elif kind == "scan-busy":
        subject._active.update({"one", "two"})
    elif kind == "provider-backoff":
        subject._backoff_until = subject.time.monotonic() + 60
    else:
        subject._window.extend([subject.time.monotonic()] * 6)
    factory = Mock(side_effect=AssertionError("No capacity means no DB query"))
    monkeypatch.setattr(subject, "_session_factory", factory)
    assert asyncio.run(subject.refresh_public_recipe_evidence(now=NOW)) in {"busy", "backoff"}
    factory.assert_not_called()


def test_selection_is_bounded_and_cooldowns_cannot_starve_other_codes(db, monkeypatch):
    session, adapter, _, _, recipe_id = setup_recipe(db, exact=True)
    # Three distinct approved public foods, each already used by this recipe.
    codes = [CODE, "5901234123457", "20071974"]
    old = NOW - timedelta(days=31)
    for index, code in enumerate(codes[1:], start=1):
        food = Product(id=uuid4(), name=f"Other public food {index}", unit="g",
            barcode=code, review_status="approved")
        session.add(food)
        session.flush()
        session.add(RecipeIngredient(id=uuid4(), recipe_id=recipe_id, product_id=food.id,
            quantity=100, unit="g", is_optional=False))
        session.flush()
        asyncio.run(import_off_catalogue(adapter, [raw(code=code)], retrieved_at=old))
    session.commit()
    # A failing GTIN and its equivalent padded alias share a cooldown.
    subject._attempts[codes[0].zfill(14)] = subject.time.monotonic()
    connect_io(db, monkeypatch)
    fetch = AsyncMock(return_value="checked")
    monkeypatch.setattr(subject, "refresh_requested_off_product", fetch)
    statements = []
    def capture(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)
    event.listen(session.bind, "before_cursor_execute", capture)
    try:
        assert asyncio.run(subject.refresh_public_recipe_evidence(now=NOW)) == "checked"
        assert asyncio.run(subject.refresh_public_recipe_evidence(now=NOW)) == "busy"
    finally:
        event.remove(session.bind, "before_cursor_execute", capture)
    assert fetch.await_count == 2
    assert {call.args[0] for call in fetch.await_args_list} == set(codes[1:])
    assert len([sql for sql in statements if sql.startswith("SELECT")]) == 1
    assert all(sql == "BEGIN" or sql.startswith("SELECT") for sql in statements)


def test_selection_database_error_is_best_effort_and_releases_running_guard(monkeypatch, caplog):
    @asynccontextmanager
    async def broken():
        raise RuntimeError("private connection details must not appear")
        yield
    monkeypatch.setattr(subject, "_session_factory", broken)
    assert asyncio.run(subject.refresh_public_recipe_evidence(now=NOW)) == "unavailable"
    assert subject._catalogue_refresh_running is False
    assert "RuntimeError" in caplog.text
    assert "private connection" not in caplog.text


def test_cancellation_releases_running_guard_without_swallowing_cancel(monkeypatch):
    entered, release = asyncio.Event(), asyncio.Event()
    async def execute(query):
        entered.set()
        await release.wait()
    @asynccontextmanager
    async def waiting():
        yield SimpleNamespace(execute=execute)
    monkeypatch.setattr(subject, "_session_factory", waiting)
    async def cancel():
        task = asyncio.create_task(subject.refresh_public_recipe_evidence(now=NOW))
        await entered.wait()
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
    asyncio.run(cancel())
    assert subject._catalogue_refresh_running is False


def test_postgres_selection_is_correlated_bounded_and_never_locks_public_readers():
    statement = subject._public_recipe_refresh_query(now=NOW, excluded_keys=[CODE.lstrip("0")])
    compiled = str(statement.compile(dialect=postgresql.dialect()))
    assert "EXISTS" in compiled and "LIMIT" in compiled
    assert "ltrim(off_catalogue_products.barcode" in compiled
    assert "off_ingredient_mappings.off_fingerprint = off_catalogue_products.fingerprint" in compiled
    assert "FOR UPDATE" not in compiled
    assert str(NOW.date()) not in compiled  # Bound SQL parameters, not string-built dates.


@pytest.mark.parametrize("premium", [False, True])
def test_nonempty_response_keeps_author_favorites_and_light_payload_after_rollback(db, monkeypatch, premium):
    session, adapter, user_id, _, recipe_id = setup_recipe(db, age=1)
    user = session.get(User, user_id)
    user.role, user.display_name = "user", "Recipe author"
    user.is_premium = premium
    user.premium_expires_at = NOW + timedelta(days=7) if premium else NOW - timedelta(days=7)
    user.tiktok_username = "food.author"
    session.commit()
    fetch = AsyncMock()
    monkeypatch.setattr(subject, "refresh_public_recipe_evidence", fetch)
    monkeypatch.setattr(market_catalog, "utc_market_date", lambda: NOW.date())
    monkeypatch.setattr(recipes, "_get_favorite_recipe_ids", AsyncMock(return_value={recipe_id}))
    adapter.rollback = AsyncMock(side_effect=session.rollback)
    async def dependency():
        yield adapter
    app = FastAPI()
    app.include_router(recipes.router, prefix="/recipes")
    app.dependency_overrides[get_db] = dependency
    app.dependency_overrides[recipes.get_current_user] = lambda: user
    async def request():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            return await client.get("/recipes/")
    response = asyncio.run(request())
    assert response.status_code == 200
    row, = response.json()
    assert row["created_by_name"] == "Recipe author"
    assert row["created_by_tiktok_username"] == ("food.author" if premium else None)
    assert row["created_by_profile_loaded"] is True and row["is_favorite"] is True
    assert row["is_own_recipe"] is True
    assert "ingredients" not in row and "photo_base64" not in row and "instructions" not in row
    adapter.rollback.assert_awaited_once()
    fetch.assert_awaited_once()
