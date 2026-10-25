"""Admin UK catalogue reads can refresh only already reviewed exact offers."""

import asyncio
from contextlib import asynccontextmanager
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import httpx
import pytest
from fastapi import BackgroundTasks
from sqlalchemy import select

from app.models import OffCatalogueProduct, RegionalProductOffer, Store, User
from app.services import community_price_refresh as subject
from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
from tests.test_community_price_integration import setup_community_catalogue, catalogue_db
from tests.test_open_prices_reference import PRICES
from tests.test_regional_shopping import AsyncDB


NOW = datetime(2026, 10, 24, 12, tzinfo=timezone.utc)


def observation():
    row = deepcopy(PRICES["records"][1])
    row.update(id=400000, date="2026-10-24", price=Decimal("0.55"))
    row["proof"]["date"] = row["date"]
    return row


@pytest.fixture(autouse=True)
def clean_limits():
    subject._active.clear()
    subject._attempts.clear()
    subject._offer_attempts.clear()
    subject._window.clear()
    subject._backoff_until = 0


@pytest.fixture
def refresh_db(catalogue_db, monkeypatch):
    session, reviewer, _ = catalogue_db
    row, canonical, reviewed_at = setup_community_catalogue(session, reviewer)
    adapter = AsyncDB(session)
    asyncio.run(import_reviewed_uk_catalogue(adapter, [row], reviewer_user_id=reviewer,
        reviewed_at=reviewed_at, as_of=reviewed_at.date()))
    session.commit()
    @asynccontextmanager
    async def factory():
        try:
            yield adapter
        finally:
            session.rollback()
    monkeypatch.setattr(subject, "_session_factory", factory)
    monkeypatch.setattr(subject, "refresh_requested_off_product", AsyncMock(return_value="fresh"))
    return session, row, reviewer


def setup_http(monkeypatch, rows=None, handler=None):
    calls = []
    import json
    async def transport(request):
        calls.append(request)
        if handler:
            return await handler(request)
        return httpx.Response(200, content=json.dumps({"items": rows or [observation()]}, default=str).encode())
    original = httpx.AsyncClient
    monkeypatch.setattr(subject, "_client_factory", lambda **kwargs: original(
        transport=httpx.MockTransport(transport), **kwargs))
    return calls


def test_refresh_updates_only_price_for_exact_previously_reviewed_food(refresh_db, monkeypatch):
    session, row, reviewer = refresh_db
    calls = setup_http(monkeypatch)
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "updated"
    session.expire_all()
    stored = session.get(RegionalProductOffer, row.proposal_id)
    assert stored.price == Decimal("0.55") and stored.package_quantity == 500
    assert stored.price_kind == "estimate" and stored.availability_scope == "store_observation"
    assert stored.reviewed_by_user_id == reviewer and stored.reviewed_at.replace(tzinfo=timezone.utc) == NOW
    assert stored.price_source["checked_on"] == "2026-10-24"
    assert stored.price_source["observation_id"] == 400000
    assert stored.price_source["package_basis_note"] == row.price.source.package_basis_note
    assert len(calls) == 1 and calls[0].url.host == "prices.openfoodfacts.org"
    assert calls[0].url.params["product_code"] == "20522605"
    assert calls[0].url.params["currency"] == "GBP"
    assert calls[0].url.params["size"] == "10"


@pytest.mark.parametrize("change", ["wrong_code", "wrong_retailer", "wrong_pack", "discount", "future", "stale", "changed_off"])
def test_inconsistent_observation_never_overwrites_approved_offer(refresh_db, monkeypatch, change):
    session, row, reviewer = refresh_db
    candidate = observation()
    if change == "wrong_code": candidate["product_code"] = "20071974"
    elif change == "wrong_retailer": candidate["location"]["osm_brand"] = "Tesco"
    elif change == "wrong_pack": candidate["product"]["product_quantity"] = 750
    elif change == "discount": candidate["price_is_discounted"] = True
    elif change == "future": candidate["date"] = candidate["proof"]["date"] = "2026-10-25"
    elif change == "stale": candidate["date"] = candidate["proof"]["date"] = "2026-09-01"
    elif change == "changed_off":
        session.get(OffCatalogueProduct, "20522605").fingerprint = "f" * 64
        session.commit()
    setup_http(monkeypatch, [candidate])
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) in {"no_valid_price", "no_identity"}
    session.expire_all()
    assert session.get(RegionalProductOffer, row.proposal_id).fingerprint == row.fingerprint


@pytest.mark.parametrize("kind", ["ordinary", "banned", "missing"])
def test_only_current_unbanned_admin_can_start_price_refresh(refresh_db, monkeypatch, kind):
    session, row, reviewer = refresh_db
    if kind == "ordinary": session.get(User, reviewer).role = "user"
    elif kind == "banned": session.get(User, reviewer).is_banned = True
    else: reviewer = uuid4()
    session.commit()
    monkeypatch.setattr(subject, "_client_factory", MagicMock(side_effect=AssertionError("no HTTP allowed")))
    subject.refresh_requested_off_product.side_effect = AssertionError("no OFF allowed")
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "forbidden"


@pytest.mark.parametrize("status", [429, 503, 404])
def test_external_failure_retains_price_and_does_not_invent_zero(refresh_db, monkeypatch, status):
    session, row, reviewer = refresh_db
    async def handler(request): return httpx.Response(status)
    setup_http(monkeypatch, handler=handler)
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "unavailable"
    session.expire_all()
    assert session.get(RegionalProductOffer, row.proposal_id).price == Decimal("0.45")


def test_source_observation_date_is_not_replaced_with_fetch_date(refresh_db, monkeypatch):
    session, row, reviewer = refresh_db
    original = deepcopy(PRICES["records"][1])
    setup_http(monkeypatch, [original])
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "unchanged"
    session.expire_all()
    assert session.get(RegionalProductOffer, row.proposal_id).price_source["checked_on"] == "2026-09-27"


def test_explicit_api_unit_price_is_a_single_verified_package_not_a_kilogram(refresh_db, monkeypatch):
    session, row, reviewer = refresh_db
    candidate = observation()
    candidate["price_per"] = "UNIT"
    setup_http(monkeypatch, [candidate])
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "updated"
    session.expire_all()
    assert session.get(RegionalProductOffer, row.proposal_id).price == Decimal("0.55")


def test_older_observation_id_on_same_day_cannot_replace_a_newer_saved_one(refresh_db, monkeypatch):
    session, row, reviewer = refresh_db
    older = deepcopy(PRICES["records"][1])
    older["id"] -= 1
    older["price"] = Decimal("0.40")
    setup_http(monkeypatch, [older])
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "no_valid_price"
    session.expire_all()
    assert session.get(RegionalProductOffer, row.proposal_id).fingerprint == row.fingerprint


@pytest.mark.parametrize("change", ["manual_price", "deleted_offer", "changed_mapping", "lost_admin"])
def test_racing_change_during_http_is_not_overwritten_or_recreated(refresh_db, monkeypatch, change):
    import json
    from app.models import OffIngredientMapping
    session, row, reviewer = refresh_db
    adapter = AsyncDB(session)
    async def handler(request):
        assert not session.in_transaction()
        if change == "manual_price":
            manual = row.model_dump(mode="json")
            manual["price"]["amount"] = "0.46"
            await import_reviewed_uk_catalogue(adapter, [manual], reviewer_user_id=reviewer,
                reviewed_at=NOW, as_of=NOW.date())
        elif change == "deleted_offer": session.delete(session.get(RegionalProductOffer, row.proposal_id))
        elif change == "changed_mapping":
            link = session.scalar(select(OffIngredientMapping).where(OffIngredientMapping.off_barcode == "20522605"))
            link.off_fingerprint = "f" * 64
        else: session.get(User, reviewer).role = "user"
        session.commit()
        return httpx.Response(200, content=json.dumps({"items": [observation()]}, default=str).encode())
    setup_http(monkeypatch, handler=handler)
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "unavailable"
    session.expire_all()
    stored = session.get(RegionalProductOffer, row.proposal_id)
    if change == "deleted_offer": assert stored is None
    else: assert stored.price == Decimal("0.46" if change == "manual_price" else "0.45")


def test_price_refresh_cannot_reprice_a_previously_bought_snapshot(refresh_db, monkeypatch):
    from app.models import Product, ShoppingListItem
    from app.services.regional_shopping import apply_regional_item_quote, frozen_regional_purchase_quote
    session, row, reviewer = refresh_db
    stored = session.get(RegionalProductOffer, row.proposal_id)
    product = session.get(Product, row.canonical_product_id)
    item = ShoppingListItem(is_checked=False, is_from_pantry=False)
    apply_regional_item_quote(item, product=product, store_id=row.store_id, quantity=Decimal("600"),
        unit="g", offers=[stored], as_of=NOW.date())
    item.is_checked = True
    before = frozen_regional_purchase_quote(item, as_of=NOW.date())
    assert before is not None and before.total_price == Decimal("0.90")
    session.rollback()
    setup_http(monkeypatch)
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "updated"
    assert frozen_regional_purchase_quote(item, as_of=NOW.date()) == before


@pytest.mark.parametrize("kind", ["timeout", "redirect", "oversized", "malformed"])
def test_bounded_transport_failure_does_not_modify_the_offer(refresh_db, monkeypatch, kind):
    session, row, reviewer = refresh_db
    async def handler(request):
        if kind == "timeout": raise httpx.ReadTimeout("test", request=request)
        if kind == "redirect": return httpx.Response(302, headers={"Location": "https://example.invalid"})
        if kind == "oversized": return httpx.Response(200, content=b"x" * 1_000_001)
        return httpx.Response(200, json={"items": {"not": "a list"}})
    calls = setup_http(monkeypatch, handler=handler)
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "unavailable"
    assert len(calls) == 1
    session.expire_all()
    assert session.get(RegionalProductOffer, row.proposal_id).fingerprint == row.fingerprint


def test_refresh_uses_the_current_admin_not_the_old_reviewer(refresh_db, monkeypatch):
    session, row, old_reviewer = refresh_db
    current_admin = uuid4()
    session.add(User(id=current_admin, email="new-reviewer@example.test", password_hash="fixture",
        role="admin", country_code="PL"))
    session.commit()
    setup_http(monkeypatch)
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, current_admin, now=NOW)) == "updated"
    session.expire_all()
    assert current_admin != old_reviewer
    assert session.get(RegionalProductOffer, row.proposal_id).reviewed_by_user_id == current_admin


def test_source_owner_and_address_are_not_persisted_as_price_metadata(refresh_db, monkeypatch):
    session, row, reviewer = refresh_db
    candidate = observation()
    candidate["owner"] = "private-example-owner"
    candidate["proof"]["owner_comment"] = "private-example-note"
    candidate["location"]["osm_address_city"] = "private-example-address"
    setup_http(monkeypatch, [candidate])
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "updated"
    session.expire_all()
    stored = session.get(RegionalProductOffer, row.proposal_id)
    assert "private-example" not in repr((stored.price_source, stored.availability_source, stored.package_source))


def test_cooldown_and_busy_work_skip_instead_of_queuing(refresh_db, monkeypatch):
    _, row, reviewer = refresh_db
    subject._attempts[row.store_id] = subject.time.monotonic()
    monkeypatch.setattr(subject, "_session_factory", MagicMock(side_effect=AssertionError("no DB expected")))
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "cooldown"
    subject._attempts.clear()
    subject._active.update({uuid4(), uuid4()})
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "backoff"


def test_rate_budget_prevents_external_price_requests(refresh_db, monkeypatch):
    _, row, reviewer = refresh_db
    subject._window.extend([subject.time.monotonic()] * 6)
    monkeypatch.setattr(subject, "_client_factory", MagicMock(side_effect=AssertionError("no HTTP expected")))
    assert asyncio.run(subject.refresh_reviewed_store_prices(row.store_id, reviewer, now=NOW)) == "backoff"


@pytest.mark.parametrize("country,role", [("PL", "admin"), ("GB", "user"), ("GB", "admin")])
def test_existing_store_view_schedules_only_uk_admin_jobs(country, role, monkeypatch):
    from app.api.v1 import stores
    from app.db.uk_store_catalog import UK_STORES
    selected = UK_STORES[0].id
    db_result = MagicMock()
    db_result.scalar_one_or_none.return_value = Store(id=selected, country_code=country, currency_code="GBP" if country == "GB" else "PLN")
    db_result.scalars.return_value.all.return_value = []
    db = SimpleNamespace(execute=AsyncMock(return_value=db_result), rollback=AsyncMock())
    monkeypatch.setattr(stores, "list_reviewed_store_products", AsyncMock(return_value=[]))
    tasks = BackgroundTasks()
    asyncio.run(stores.list_store_products(selected, skip=0, limit=30, search=None, department_id=None,
        db=db, current_user=SimpleNamespace(id=uuid4(), country_code=country, role=role), market=None, background_tasks=tasks))
    assert len(tasks.tasks) == (1 if (country, role) == ("GB", "admin") else 0)
    if tasks.tasks:
        assert tasks.tasks[0].func is subject.refresh_reviewed_store_prices
        db.rollback.assert_awaited_once()


def test_polish_admin_can_refresh_only_in_explicit_uk_market(monkeypatch):
    from app.api.v1 import stores
    from app.db.uk_store_catalog import UK_STORES
    selected = UK_STORES[0].id
    result = MagicMock()
    result.scalar_one_or_none.return_value = Store(id=selected, country_code="GB", currency_code="GBP")
    db = SimpleNamespace(execute=AsyncMock(return_value=result), rollback=AsyncMock())
    monkeypatch.setattr(stores, "list_reviewed_store_products", AsyncMock(return_value=[]))
    admin = SimpleNamespace(id=uuid4(), country_code="PL", role="admin")
    tasks = BackgroundTasks()
    asyncio.run(stores.list_store_products(selected, skip=0, limit=30, search=None, department_id=None,
        db=db, current_user=admin, market="GB", background_tasks=tasks))
    assert len(tasks.tasks) == 1 and tasks.tasks[0].args == (selected, admin.id)
