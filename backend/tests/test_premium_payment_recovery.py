"""Real storage regression: a store consumption outage must not mint points."""
import asyncio
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1 import billing
from app.models import User
from app.services.google_play_billing import PurchaseVerificationError
from tests.test_meal_plan_lifecycle import db


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("platform", ["android", "ios"])
@pytest.mark.parametrize("same_token", [False, True])
@pytest.mark.parametrize("without_returning", [False, True])
def test_simultaneous_point_payments_use_atomic_storage(tmp_path, monkeypatch, country, platform, same_token, without_returning):
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier
    from sqlalchemy import create_engine, event
    from sqlalchemy.orm import Session
    from sqlalchemy.dialects import postgresql
    from app.models import Base
    from tests.test_meal_plan_lifecycle import Database

    engine = create_engine(f"sqlite:///{(tmp_path / 'payments.sqlite3').as_posix()}")
    @event.listens_for(engine, "connect")
    def configure(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")
        connection.create_function("gen_random_uuid", 0, lambda: uuid4().hex)
    Base.metadata.create_all(engine)
    if without_returning:
        engine.dialect.insert_returning = False
    user_id = uuid4()
    with Session(engine) as session:
        session.add(User(id=user_id, email=f"{uuid4()}@example.invalid", password_hash="test",
                         country_code=country, premium_points=5, role="user"))
        session.commit()
    gate = Barrier(2)
    async def verify(*args):
        await asyncio.to_thread(gate.wait, 10)
        return {"is_purchased": True, "is_consumed": False}
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase", verify)
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_consumable", verify)
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase", AsyncMock())
    monkeypatch.setattr(billing, "_notify", AsyncMock())
    def pay(index):
        with Session(engine, expire_on_commit=False) as session:
            if not engine.dialect.insert_returning:
                # SQLite <3.35 cannot return PostgreSQL's server UUID default.
                # Match the shared test adapter without changing app models.
                @event.listens_for(session, "before_flush")
                def supply_test_uuid(test_session, *_):
                    for row in test_session.new:
                        column = type(row).__table__.c.get("id")
                        if column is not None and isinstance(column.type, postgresql.UUID) and row.id is None:
                            row.id = uuid4()
            user = session.get(User, user_id)
            return asyncio.run(billing.verify_points_purchase(billing.VerifyPurchaseRequest(
                purchase_token=f"parallel-{0 if same_token else index}",
                product_id="points_10", platform=platform), user, Database(session)))
    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(pay, [0, 1]))
        with Session(engine) as session:
            assert session.get(User, user_id).premium_points == (15 if same_token else 25)
        assert all(result.premium_points in {15, 25} for result in results)
    finally:
        engine.dispose()


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("platform", ["android", "ios"])
def test_store_retry_after_consumption_failure_credits_once(db, monkeypatch, country, platform):
    user = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                country_code=country, premium_points=3, role="user")
    db.session.add(user)
    db.session.commit()
    verify = AsyncMock(return_value={"is_purchased": True, "is_consumed": False})
    consume = AsyncMock(side_effect=PurchaseVerificationError("offline"))
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase", verify)
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_consumable", verify)
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase", consume)
    monkeypatch.setattr(billing, "_notify", AsyncMock())
    payload = billing.VerifyPurchaseRequest(purchase_token="synthetic-points-token", product_id="points_10", platform=platform)
    for _ in range(2):
        result = asyncio.run(billing.verify_points_purchase(payload, user, db))
        assert result.premium_points == 13
    db.session.refresh(user)
    assert user.premium_points == 13


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_google_consumed_token_is_not_lost_when_server_already_saved(db, monkeypatch, country):
    user = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                country_code=country, premium_points=0, role="user")
    db.session.add(user)
    db.session.commit()
    verify = AsyncMock(return_value={"is_purchased": True, "is_consumed": False})
    consume = AsyncMock()
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase", verify)
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase", consume)
    monkeypatch.setattr(billing, "_notify", AsyncMock())
    payload = billing.VerifyPurchaseRequest(purchase_token="saved-token", product_id="points_20")
    asyncio.run(billing.verify_points_purchase(payload, user, db))
    verify.return_value = {"is_purchased": True, "is_consumed": True}
    result = asyncio.run(billing.verify_points_purchase(payload, user, db))
    assert result.premium_points == 20
    assert db.session.scalar(select(User.premium_points).where(User.id == user.id)) == 20


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("platform", ["android", "ios"])
def test_store_purchase_cannot_credit_another_account(db, monkeypatch, country, platform):
    users = [User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                  country_code=country, premium_points=0, role="user") for _ in range(2)]
    db.session.add_all(users)
    db.session.commit()
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase",
                        AsyncMock(return_value={"is_purchased": True, "is_consumed": False}))
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_consumable",
                        AsyncMock(return_value={"is_purchased": True}))
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase",
                        AsyncMock(side_effect=PurchaseVerificationError("offline")))
    monkeypatch.setattr(billing, "_notify", AsyncMock())
    payload = billing.VerifyPurchaseRequest(purchase_token="owned-token", product_id="points_50", platform=platform)
    asyncio.run(billing.verify_points_purchase(payload, users[0], db))
    with pytest.raises(HTTPException) as error:
        asyncio.run(billing.verify_points_purchase(payload, users[1], db))
    assert error.value.status_code == 409
    db.session.refresh(users[1])
    assert users[1].premium_points == 0


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("platform", ["android", "ios"])
def test_points_http_replay_response_and_owner_binding(db, monkeypatch, country, platform):
    import httpx
    from fastapi import FastAPI
    from app.api.deps import get_current_user, get_db
    from app.models import PointsPurchase

    users = [User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                  country_code=country, premium_points=0, role="user") for _ in range(2)]
    db.session.add_all(users)
    db.session.commit()
    current = [users[0]]
    app = FastAPI()
    app.include_router(billing.router, prefix="/billing")
    app.dependency_overrides[get_current_user] = lambda: current[0]
    async def database():
        yield db
    app.dependency_overrides[get_db] = database
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase",
                        AsyncMock(return_value={"is_purchased": True, "is_consumed": False}))
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_consumable",
                        AsyncMock(return_value={"is_purchased": True}))
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase", AsyncMock())
    monkeypatch.setattr(billing, "_notify", AsyncMock())
    async def requests():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            payload = dict(purchase_token="http-token", product_id="points_10", platform=platform,
                           premium_points=99999)
            for _ in range(2):
                response = await client.post("/billing/verify-points-purchase", json=payload)
                assert response.status_code == 200, response.text
                assert response.json() == {"premium_points": 10}
            current[0] = users[1]
            response = await client.post("/billing/verify-points-purchase", json=payload)
            assert response.status_code == 409
            assert "example.invalid" not in response.text
    asyncio.run(requests())
    record = db.session.scalar(select(PointsPurchase))
    assert len(record.token_hash) == 64 and record.token_hash != "http-token"
    assert record.platform == platform


@pytest.mark.parametrize("platform", ["android", "ios"])
def test_deleted_account_does_not_free_a_purchase_for_reuse(db, monkeypatch, platform):
    from app.models import PointsPurchase
    user = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                premium_points=0, role="user")
    db.session.add(user)
    db.session.commit()
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase",
                        AsyncMock(return_value={"is_purchased": True, "is_consumed": False}))
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_consumable",
                        AsyncMock(return_value={"is_purchased": True}))
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase", AsyncMock())
    monkeypatch.setattr(billing, "_notify", AsyncMock())
    payload = billing.VerifyPurchaseRequest(purchase_token="deleted-account-token", product_id="points_10", platform=platform)
    asyncio.run(billing.verify_points_purchase(payload, user, db))
    db.session.delete(user)
    db.session.commit()
    db.session.expire_all()
    record = db.session.scalar(select(PointsPurchase))
    assert record.user_id is None
