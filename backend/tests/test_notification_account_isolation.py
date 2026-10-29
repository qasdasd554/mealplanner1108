"""Notification read state and shared-device logout must stay account scoped."""
import asyncio
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select

from app.api.v1 import notifications as api
from app.models import DeviceToken, Notification, User
from tests.test_meal_plan_lifecycle import db


def run(task):
    return asyncio.run(task)


def users(db, country):
    accounts = [User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                     country_code=country) for _ in range(2)]
    db.session.add_all(accounts)
    db.session.commit()
    return accounts


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_reading_notifications_never_changes_another_accounts_badge(db, country):
    owner, other = users(db, country)
    own = Notification(id=uuid4(), user_id=owner.id, notification_type="billing", message="Own")
    foreign = Notification(id=uuid4(), user_id=other.id, notification_type="billing", message="Foreign")
    db.session.add_all([own, foreign])
    db.session.commit()
    assert [n.id for n in run(api.list_notifications(50, db, owner))] == [own.id]
    with pytest.raises(HTTPException) as error:
        run(api.mark_notification_read(foreign.id, db, owner))
    assert error.value.status_code == 404
    if country == "GB":
        assert error.value.detail == "Notification not found."
    assert run(api.get_unread_count(db, owner)).unread_count == 1
    run(api.mark_notification_read(own.id, db, owner))
    run(api.mark_notification_read(own.id, db, owner))
    assert run(api.get_unread_count(db, owner)).unread_count == 0
    assert run(api.get_unread_count(db, other)).unread_count == 1
    run(api.mark_all_notifications_read(db, owner))
    assert run(api.get_unread_count(db, other)).unread_count == 1


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_device_token_moves_to_new_account_and_old_logout_cannot_remove_it(db, country):
    first, second = users(db, country)
    payload = api.DeviceTokenRequest(token="  isolated-qa-device-token  ", platform="android")
    run(api.register_device_token(payload, db, first))
    run(api.register_device_token(payload, db, first))
    assert db.session.scalar(select(func.count()).select_from(DeviceToken)) == 1
    run(api.register_device_token(payload, db, second))
    token = db.session.scalar(select(DeviceToken))
    assert token.user_id == second.id and token.token == payload.token.strip()
    run(api.unregister_device_token(payload, db, first))
    assert db.session.scalar(select(func.count()).select_from(DeviceToken)) == 1
    run(api.unregister_device_token(payload, db, second))
    assert db.session.scalar(select(func.count()).select_from(DeviceToken)) == 0
