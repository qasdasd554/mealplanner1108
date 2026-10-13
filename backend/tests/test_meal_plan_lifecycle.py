"""Real-ORM lifecycle regressions with foreign-key preservation enabled."""

import asyncio
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session

from app.api.v1 import meal_plans
from app.core.exceptions import NotFoundException
from app.models import (
    Base, FoodLogEntry, MealPlan, MealPlanCreation, MealPlanEntry, Notification, Recipe,
    ShoppingList, ShoppingListItem, Store, User,
)
from app.schemas.meal_plan import MealPlanGenerateRequest, MealPlanResponse
from app.services import meal_plan_lifecycle as lifecycle


class Database:
    def __init__(self, session):
        self.session = session
        self.statements = []

    async def execute(self, statement, *args, **kwargs):
        self.statements.append(statement)
        return self.session.execute(statement, *args, **kwargs)

    def add(self, row):
        self.session.add(row)

    async def commit(self):
        self.session.commit()

    async def rollback(self):
        self.session.rollback()

    async def flush(self):
        self.session.flush()

    async def refresh(self, row):
        self.session.refresh(row)

    async def get(self, model, identifier):
        return self.session.get(model, identifier)


@pytest.fixture(params=["default", "without_returning"])
def db(request):
    engine = create_engine("sqlite:///:memory:")
    if request.param == "without_returning":
        # SQLite < 3.35 in some Linux Codespaces cannot return server UUIDs.
        engine.dialect.insert_returning = False

    @event.listens_for(engine, "connect")
    def configure(connection, record):
        connection.execute("PRAGMA foreign_keys=ON")
        connection.create_function("gen_random_uuid", 0, lambda: uuid4().hex)

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        if not engine.dialect.insert_returning:
            # PostgreSQL zwraca gen_random_uuid() po INSERT, ale starszy SQLite
            # nie potrafi oddać ORM wygenerowanego klucza UUID. Adapter dotyczy
            # wyłącznie tej sesji testowej: nie zmienia modeli ani bazy Neon.
            @event.listens_for(session, "before_flush")
            def supply_test_uuid(test_session, flush_context, instances):
                for row in test_session.new:
                    column = type(row).__table__.c.get("id")
                    if column is not None and isinstance(column.type, postgresql.UUID) and row.id is None:
                        row.id = uuid4()

        yield Database(session)
    engine.dispose()


def test_sqlite_adapter_preserves_production_uuid_defaults(db):
    for model in (MealPlan, MealPlanEntry, ShoppingList):
        column = model.__table__.c.id
        assert column.default is None
        assert str(column.server_default.arg) == "gen_random_uuid()"
        compiled = str(model.__table__.insert().compile(dialect=postgresql.dialect()))
        assert model.__tablename__ in compiled


def make_plan(db, *, premium=False, status="active", start=None, duration=7):
    user = User(id=uuid4(), email=f"{uuid4()}@example.com", password_hash="test", role="user", is_premium=premium)
    store = Store(id=uuid4(), name=f"Store-{uuid4()}")
    recipe = Recipe(id=uuid4(), name="Owsianka", meal_type="śniadanie", nutrition_total={"kcal": 300})
    db.session.add_all([user, store, recipe])
    db.session.flush()
    plan = MealPlan(
        id=uuid4(), user_id=user.id, store_id=store.id,
        start_date=start or date(2026, 10, 7), duration_days=duration,
        meals_per_day=1, status=status,
        preferences={"household_size": 2, "preference_warnings": ["Test preferencji"]},
    )
    db.session.add(plan)
    db.session.flush()
    entry = MealPlanEntry(id=uuid4(), meal_plan_id=plan.id, recipe_id=recipe.id,
                          day_number=1, meal_slot="śniadanie", servings_multiplier=Decimal("1.50"))
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan.id, store_id=store.id)
    log = FoodLogEntry(id=uuid4(), user_id=user.id, date=plan.start_date, meal_type="breakfast", recipe_id=recipe.id)
    db.session.add_all([entry, shopping, log])
    db.session.flush()
    item = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, custom_name="Płatki", required_quantity=1, unit="opak", is_checked=True)
    db.session.add(item)
    db.session.commit()
    return user, plan, entry, shopping, item, log


def test_end_is_midnight_after_last_day_and_dst_is_elapsed_24_hours():
    plan = MealPlan(start_date=date(2026, 10, 19), duration_days=7)
    assert plan.end_date == date(2026, 10, 25)
    assert lifecycle.plan_expires_at(plan) == datetime(2026, 10, 25, 23, tzinfo=timezone.utc)
    assert lifecycle.plan_has_expired(plan, now=datetime(2026, 10, 25, 22, 59, tzinfo=timezone.utc)) is False
    assert lifecycle.plan_has_expired(plan, now=datetime(2026, 10, 25, 23, tzinfo=timezone.utc)) is True


def test_reminder_is_atomic_once_and_only_last_24_hours(db, monkeypatch):
    _, plan, *_ = make_plan(db)
    sent = []

    async def push(session, notification):
        assert db.session.get(Notification, notification.id) is not None
        sent.append(notification.id)

    monkeypatch.setattr(lifecycle, "push_for_notification", push)
    expiry = lifecycle.plan_expires_at(plan)
    assert asyncio.run(lifecycle.process_due_meal_plans(db, now=expiry - timedelta(hours=24, seconds=1))).reminders == 0
    assert asyncio.run(lifecycle.process_due_meal_plans(db, now=expiry - timedelta(hours=24))).reminders == 1
    assert asyncio.run(lifecycle.process_due_meal_plans(db, now=expiry - timedelta(seconds=1))).reminders == 0
    assert len(sent) == 1
    notification = db.session.scalar(select(Notification))
    assert notification.notification_type == "meal_plan_expiring"
    assert notification.meal_plan_id == plan.id
    assert "13.10.2026" in notification.message
    compiled = [str(stmt.compile(dialect=postgresql.dialect())) for stmt in db.statements]
    assert any("FOR UPDATE OF meal_plans SKIP LOCKED" in statement for statement in compiled)


@pytest.mark.parametrize("premium, expected", [(False, "expired"), (True, "archived")])
def test_expiration_preserves_shopping_and_diary(db, premium, expected):
    _, plan, entry, shopping, item, log = make_plan(db, premium=premium)
    result = asyncio.run(lifecycle.process_due_meal_plans(db, now=lifecycle.plan_expires_at(plan)))
    db.session.expire_all()
    assert db.session.get(MealPlan, plan.id).status == expected
    assert result.archived + result.removed == 1
    assert db.session.get(MealPlanEntry, entry.id) is not None
    assert db.session.get(ShoppingList, shopping.id).meal_plan_id == plan.id
    assert db.session.get(ShoppingListItem, item.id).is_checked is True
    assert db.session.get(FoodLogEntry, log.id) is not None
    assert db.session.scalar(select(func.count(Notification.id))) == 0


def test_api_reads_do_not_send_push_and_archive_is_premium_only(db, monkeypatch):
    user, plan, *_ = make_plan(db, premium=True, start=date(2026, 1, 1))
    async def should_not_push(*args):
        raise AssertionError("API read must not wait for FCM")
    monkeypatch.setattr(lifecycle, "push_for_notification", should_not_push)
    assert asyncio.run(meal_plans.list_meal_plans(current_user=user, db=db)) == []
    archives = asyncio.run(meal_plans.list_archived_meal_plans(current_user=user, db=db))
    assert [archive.id for archive in archives] == [plan.id]
    user.is_premium = False
    db.session.commit()
    with pytest.raises(HTTPException) as error:
        asyncio.run(meal_plans.list_archived_meal_plans(current_user=user, db=db))
    assert error.value.status_code == 403
    assert db.session.get(MealPlan, plan.id).status == "archived"


def test_archived_technical_shopping_rows_are_not_exposed(db):
    user, plan, *_ = make_plan(db, premium=True, status="archived")
    assert asyncio.run(meal_plans.list_archived_meal_plans(current_user=user, db=db)) == []
    with pytest.raises(NotFoundException):
        asyncio.run(meal_plans.get_meal_plan(plan.id, current_user=user, db=db))


def test_resume_copies_entries_without_ai_points_or_old_archive_changes(db, monkeypatch):
    user, plan, entry, shopping, item, log = make_plan(db, premium=True)
    asyncio.run(lifecycle.process_due_meal_plans(db, now=lifecycle.plan_expires_at(plan)))
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    start = datetime.now(lifecycle.WARSAW).date() + timedelta(days=1)
    resumed = asyncio.run(meal_plans.resume_meal_plan(plan.id, meal_plans.ResumeMealPlanRequest(start_date=start), current_user=user, db=db))
    assert resumed.id != plan.id and resumed.status == "active"
    assert resumed.start_date == start and resumed.duration_days == plan.duration_days
    assert len(resumed.entries) == 1
    copied = resumed.entries[0]
    assert copied.recipe_id == entry.recipe_id and copied.id != entry.id
    assert copied.servings_multiplier == Decimal("1.50")
    assert copied.day_number == entry.day_number and copied.meal_slot == entry.meal_slot
    assert resumed.preferences == plan.preferences
    assert resumed.expiration_reminder_sent_at is None
    assert plan.status == "archived" and plan.archived_at is not None
    assert user.premium_points == 0
    assert db.session.get(ShoppingList, shopping.id) is not None
    new_list = db.session.scalar(select(ShoppingList).where(ShoppingList.meal_plan_id == resumed.id))
    assert new_list is not None and new_list.id != shopping.id
    assert db.session.get(ShoppingListItem, item.id).is_checked is True
    assert db.session.scalar(select(func.count(MealPlanCreation.id))) == 1
    assert MealPlanResponse.model_validate(resumed).preference_warnings == ["Test preferencji"]


def test_resume_list_failure_rolls_back_clone_and_creation_ledger(db, monkeypatch):
    from app.services.exceptions import ServiceError
    user, plan, _, shopping, *_ = make_plan(db, premium=True, status="archived")
    plan.archived_at = datetime.now(timezone.utc)
    db.session.commit()
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    class FailedBuilder:
        def __init__(self, session):
            self.session = session
        async def build_from_meal_plan(self, identifier, **kwargs):
            raise ServiceError("Nie udało się utworzyć listy.")
    monkeypatch.setattr(meal_plans, "ShoppingListBuilder", FailedBuilder)
    with pytest.raises(HTTPException) as error:
        asyncio.run(meal_plans.resume_meal_plan(
            plan.id, meal_plans.ResumeMealPlanRequest(start_date=datetime.now(lifecycle.WARSAW).date()),
            current_user=user, db=db,
        ))
    assert error.value.status_code == 422
    assert db.session.scalar(select(func.count(MealPlan.id))) == 1
    assert db.session.scalar(select(func.count(MealPlanCreation.id))) == 0
    assert db.session.get(MealPlan, plan.id).status == "archived"
    assert db.session.get(ShoppingList, shopping.id) is not None


@pytest.mark.parametrize("old_count", [10, "10"])
def test_resume_legacy_ten_person_plan_scales_to_eight_without_changing_archive(db, monkeypatch, old_count):
    user, plan, entry, *_ = make_plan(db, premium=True, status="archived")
    plan.archived_at = datetime.now(timezone.utc)
    plan.preferences = {"household_size": old_count, "include_pantry": False}
    entry.servings_multiplier = Decimal("1.00")
    db.session.commit()
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    resumed = asyncio.run(meal_plans.resume_meal_plan(
        plan.id, meal_plans.ResumeMealPlanRequest(start_date=datetime.now(lifecycle.WARSAW).date()),
        current_user=user, db=db,
    ))
    assert resumed.preferences["household_size"] == 8
    assert resumed.entries[0].servings_multiplier == Decimal("0.80")
    assert resumed.preference_warnings == ["Plan dostosowaliśmy do limitu 8 osób."]
    assert plan.preferences["household_size"] == old_count
    assert entry.servings_multiplier == Decimal("1.00")


def test_resume_requires_owner_premium_archive_and_nonpast_date(db, monkeypatch):
    user, plan, *_ = make_plan(db, premium=True, status="archived")
    plan.archived_at = datetime.now(timezone.utc)
    db.session.commit()
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    today = datetime.now(lifecycle.WARSAW).date()
    payload = meal_plans.ResumeMealPlanRequest(start_date=today)
    stranger = User(id=uuid4(), role="user", is_premium=True)
    with pytest.raises(NotFoundException):
        asyncio.run(meal_plans.resume_meal_plan(plan.id, payload, current_user=stranger, db=db))
    with pytest.raises(HTTPException) as error:
        asyncio.run(meal_plans.resume_meal_plan(plan.id, meal_plans.ResumeMealPlanRequest(start_date=today-timedelta(days=1)), current_user=user, db=db))
    assert error.value.status_code == 422
    user.is_premium = False
    with pytest.raises(HTTPException) as error:
        asyncio.run(meal_plans.resume_meal_plan(plan.id, payload, current_user=user, db=db))
    assert error.value.status_code == 403


@pytest.mark.parametrize("state", ["expired", "archived"])
def test_status_endpoint_cannot_reactivate_finished_plan(db, state):
    user, plan, *_ = make_plan(db, premium=True, status=state)
    if state == "archived":
        plan.archived_at = datetime.now(timezone.utc)
        db.session.commit()
    with pytest.raises((HTTPException, NotFoundException)) as error:
        asyncio.run(meal_plans.update_meal_plan_status(plan.id, meal_plans.StatusUpdate(status="active"), current_user=user, db=db))
    assert error.value.status_code in (404, 409)
    assert plan.status == state


def test_standard_cannot_manually_archive_and_expired_direct_link_is_hidden(db):
    user, plan, *_ = make_plan(db, start=datetime.now(lifecycle.WARSAW).date())
    with pytest.raises(HTTPException) as error:
        asyncio.run(meal_plans.update_meal_plan_status(plan.id, meal_plans.StatusUpdate(status="archived"), current_user=user, db=db))
    assert error.value.status_code == 403
    plan.start_date = date(2026, 1, 1)
    db.session.commit()
    with pytest.raises(NotFoundException):
        asyncio.run(meal_plans.get_meal_plan(plan.id, current_user=user, db=db))


def test_generator_schema_enforces_eight_people_and_accepts_existing_calculator_goal():
    with pytest.raises(ValidationError):
        MealPlanGenerateRequest(store_id=uuid4(), household_size=9)
    assert MealPlanGenerateRequest(store_id=uuid4(), household_size=8, target_kcal=6000).target_kcal == 6000


@pytest.mark.parametrize("value", [True, False, 0, 21, "²", "10" * 3000, None, {}, 10.5])
def test_invalid_legacy_household_is_not_inferred_from_portion_multiplier(value):
    assert meal_plans._stored_household_size(value) is None


def test_paid_renewal_is_verified_before_archiving_and_uncertain_failure_is_retained(db, monkeypatch):
    user, plan, *_ = make_plan(db)
    user.premium_product_id = "premium_monthly"
    user.premium_purchase_token = "token"
    user.premium_expires_at = datetime(2026, 10, 12, tzinfo=timezone.utc)
    user.premium_last_verified_at = datetime(2026, 10, 11, tzinfo=timezone.utc)
    db.session.commit()
    calls = []
    monkeypatch.setattr(lifecycle, "is_premium_active", lambda owner: bool(owner.is_premium))
    async def failed_refresh(session, owner):
        calls.append(owner.id)
        return False
    monkeypatch.setattr(lifecycle, "refresh_subscription_if_needed", failed_refresh)
    asyncio.run(lifecycle.process_due_meal_plans(db, now=lifecycle.plan_expires_at(plan)))
    assert calls == [user.id] and plan.status == "active"
    async def renewal(session, owner):
        owner.is_premium = True
        owner.premium_expires_at = datetime(2026, 11, 12, tzinfo=timezone.utc)
        await session.commit()
        return True
    monkeypatch.setattr(lifecycle, "refresh_subscription_if_needed", renewal)
    asyncio.run(lifecycle.process_due_meal_plans(db, now=lifecycle.plan_expires_at(plan)))
    assert plan.status == "archived"


def test_failure_for_one_plan_does_not_prevent_others(db, monkeypatch):
    _, broken, *_ = make_plan(db)
    _, healthy, *_ = make_plan(db, premium=True)
    original = lifecycle.plan_expires_at
    def maybe_fail(plan):
        if plan.id == broken.id:
            raise RuntimeError("broken legacy row")
        return original(plan)
    monkeypatch.setattr(lifecycle, "plan_expires_at", maybe_fail)
    result = asyncio.run(lifecycle.process_due_meal_plans(db, now=original(healthy)))
    assert result.archived == 1 and healthy.status == "archived"
    assert broken.status == "active"
