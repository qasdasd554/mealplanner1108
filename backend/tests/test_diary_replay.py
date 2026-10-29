"""A retried barcode diary write must not duplicate already committed food."""
from datetime import date
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.api.v1 import food_log
from app.models import FoodLogEntry, User
from app.schemas.food_log import FoodLogEntryCreate
from tests.test_runtime_async_boundaries import state


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_same_diary_request_replays_the_saved_entry_without_adding_calories(state):
    _, db, (user_id, _, _, _, _) = state
    user = await db.get(User, user_id)
    request = FoodLogEntryCreate(date=date.today(), meal_type="przekąska", custom_name="Milk",
        calories=150, protein=7.5, fat=5, carbs=12.5, amount_value=1, amount_unit="opak",
        portion_size=250, portion_unit="ml", client_entry_id=uuid4())
    first = await food_log.create_food_log_entry(request, db, user)
    replay = await food_log.create_food_log_entry(request, db, user)
    assert replay.id == first.id
    assert (await db.execute(select(func.count()).select_from(FoodLogEntry))).scalar_one() == 1
    assert (await food_log.get_daily_summary(request.date, db, user)).total_calories == 150


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_two_distinct_diary_requests_can_still_record_two_packs(state):
    _, db, (user_id, _, _, _, _) = state
    user = await db.get(User, user_id)
    for _ in range(2):
        await food_log.create_food_log_entry(FoodLogEntryCreate(date=date.today(), meal_type="przekąska",
            custom_name="Milk", calories=150, client_entry_id=uuid4()), db, user)
    assert (await food_log.get_daily_summary(date.today(), db, user)).total_calories == 300


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_client_id_cannot_replay_another_accounts_entry(state):
    from fastapi import HTTPException
    session, db, (user_id, _, _, _, _) = state
    user = await db.get(User, user_id)
    request = FoodLogEntryCreate(date=date.today(), meal_type="snack", custom_name="Milk",
        calories=150, client_entry_id=uuid4())
    first = await food_log.create_food_log_entry(request, db, user)
    stranger = User(id=uuid4(), email="other@example.test", password_hash="fixture",
        country_code=user.country_code, role="user")
    session.add(stranger)
    session.commit()
    with pytest.raises(HTTPException) as caught:
        await food_log.create_food_log_entry(request, db, stranger)
    assert caught.value.status_code == 409
    assert str(first.id) not in caught.value.detail
    assert (await db.execute(select(func.count()).select_from(FoodLogEntry))).scalar_one() == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_unique_conflict_replays_committed_entry_after_rollback(state, monkeypatch):
    _, db, (user_id, _, _, _, recipe_id) = state
    user = await db.get(User, user_id)
    request = FoodLogEntryCreate(date=date.today(), meal_type="lunch", recipe_id=recipe_id,
        calories=150, client_entry_id=uuid4())
    first = await food_log.create_food_log_entry(request, db, user)
    # Simulate another request committing between the initial lookup and insert.
    db.session.expunge_all()
    user = await db.get(User, user_id)
    original = food_log._find_client_entry
    calls = 0
    async def miss_once(*args):
        nonlocal calls
        calls += 1
        return None if calls == 1 else await original(*args)
    monkeypatch.setattr(food_log, "_find_client_entry", miss_once)
    replay = await food_log.create_food_log_entry(request, db, user)
    assert replay.id == first.id
    assert replay.recipe_name == first.recipe_name
    assert db.rollbacks == 1
    assert (await db.execute(select(func.count()).select_from(FoodLogEntry))).scalar_one() == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_old_clients_without_request_id_can_add_two_identical_meals(state):
    _, db, (user_id, _, _, _, _) = state
    user = await db.get(User, user_id)
    request = FoodLogEntryCreate(date=date.today(), meal_type="snack", custom_name="Milk", calories=150)
    first = await food_log.create_food_log_entry(request, db, user)
    second = await food_log.create_food_log_entry(request, db, user)
    assert first.id != second.id
    assert (await food_log.get_daily_summary(date.today(), db, user)).total_calories == 300


@pytest.mark.asyncio
@pytest.mark.parametrize("state", ["PL", "GB"], indirect=True)
async def test_http_retries_return_the_same_serializable_entry(state):
    import httpx
    from fastapi import FastAPI
    from app.api.deps import get_current_user, get_db
    _, db, (user_id, _, _, _, _) = state
    app = FastAPI()
    app.include_router(food_log.router, prefix="/food-log")
    async def user_dependency():
        return await db.get(User, user_id)
    async def db_dependency():
        return db
    app.dependency_overrides[get_current_user] = user_dependency
    app.dependency_overrides[get_db] = db_dependency
    payload = {"date": date.today().isoformat(), "meal_type": "snack", "custom_name": "Milk",
        "calories": 150, "protein": 7.5, "fat": 5, "carbs": 12.5,
        "client_entry_id": str(uuid4())}
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        first = await client.post("/food-log/", json=payload)
        replay = await client.post("/food-log/", json=payload)
        assert first.status_code == replay.status_code == 201
        assert first.json() == replay.json()
        assert first.json()["id"] == payload["client_entry_id"]
        assert "client_entry_id" not in first.json()
        invalid = await client.post("/food-log/", json={**payload, "client_entry_id": "invalid"})
        assert invalid.status_code == 422
    assert (await db.execute(select(func.count()).select_from(FoodLogEntry))).scalar_one() == 1
