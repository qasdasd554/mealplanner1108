"""Existing friendship actions keep their permissions; only copy is localised."""

import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import Session

from app.api.v1 import friends
from app.models import Base, Notification, User
from app.schemas.friendship import FriendInvitationCreate
from app.services import push
from tests.sqlite_uuid_compat import supply_sqlite_uuid_defaults


@pytest.fixture(params=[False, True], ids=["native", "without_returning"])
def database(request, monkeypatch):
    engine = create_engine("sqlite://")
    @event.listens_for(engine, "connect")
    def uuid_function(connection, record):
        connection.create_function("gen_random_uuid", 0, lambda: uuid4().hex)
    Base.metadata.create_all(engine)
    if request.param:
        engine.dialect.insert_returning = False
    monkeypatch.setattr(push, "is_push_enabled", lambda: True)
    send = AsyncMock(return_value=1)
    monkeypatch.setattr(push, "send_push_to_user", send)
    with Session(engine, expire_on_commit=False) as db:
        supply_sqlite_uuid_defaults(db)
        class Adapter:
            async def execute(self, query): return db.execute(query)
            async def commit(self): db.commit()
            def add(self, value): db.add(value)
        yield db, Adapter(), send
    engine.dispose()


@pytest.mark.parametrize("sender_country,recipient_country", [
    ("PL", "GB"), ("GB", "PL"), ("PL", "PL"), ("GB", "GB"),
])
def test_invitation_and_acceptance_use_recipient_country_not_actor_country(database, sender_country, recipient_country):
    db, adapter, send = database
    sender = User(id=uuid4(), email="sender@example.invalid", password_hash="test",
                  display_name="Alex", country_code=sender_country)
    recipient = User(id=uuid4(), email="recipient@example.invalid", password_hash="test",
                     display_name="Robin", country_code=recipient_country)
    db.add_all([sender, recipient])
    db.commit()
    result = asyncio.run(friends.send_invitation(
        FriendInvitationCreate(identifier=recipient.email), sender, adapter))
    assert result.status == "pending" and result.direction == "outgoing"
    notice = db.scalar(select(Notification).where(Notification.user_id == recipient.id))
    assert notice.notification_type == "friend_invitation"
    assert notice.message == ("Alex sent you a friend request." if recipient_country == "GB"
                              else "Alex wysłał(a) Ci zaproszenie do znajomych.")
    _, actor, title, message, data = send.await_args.args
    assert actor == recipient.id and message == notice.message
    assert title == ("New friend request" if recipient_country == "GB" else "Nowe zaproszenie do znajomych")
    assert data == {"type": "friend_invitation"}
    result = asyncio.run(friends.accept_invitation(result.connection_id, recipient, adapter))
    assert result.status == "accepted"
    notice = db.scalar(select(Notification).where(Notification.user_id == sender.id))
    assert notice.notification_type == "friend_accepted"
    assert notice.message == ("Robin accepted your friend request." if sender_country == "GB"
                              else "Robin przyjął(-ęła) Twoje zaproszenie do znajomych.")
    assert send.await_count == 2
    assert send.await_args.args[1] == sender.id
    assert send.await_args.args[2] == ("Friend request accepted" if sender_country == "GB" else "Zaproszenie przyjęte")
    assert sender.country_code == sender_country and recipient.country_code == recipient_country


@pytest.mark.parametrize("country,expected", [
    ("PL", "Nie znaleziono użytkownika o tej nazwie lub adresie e-mail."),
    ("GB", "No user was found with this username or email address."),
])
def test_missing_user_error_keeps_status_and_query_count(country, expected):
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    db = SimpleNamespace(execute=AsyncMock(return_value=result), commit=AsyncMock())
    user = SimpleNamespace(id=uuid4(), country_code=country)
    with pytest.raises(HTTPException) as error:
        asyncio.run(friends.send_invitation(FriendInvitationCreate(identifier="missing@example.invalid"), user, db))
    assert error.value.status_code == 404 and error.value.detail == expected
    assert db.execute.await_count == 1
    db.commit.assert_not_awaited()


@pytest.mark.parametrize("country,expected", [
    ("PL", "Ta osoba nie jest na Twojej liście znajomych."),
    ("GB", "This person is not on your friends list."),
])
def test_friend_permission_remains_mandatory_before_recipe_query(country, expected):
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    db = SimpleNamespace(execute=AsyncMock(return_value=result))
    with pytest.raises(HTTPException) as error:
        asyncio.run(friends.friend_recipes(uuid4(), SimpleNamespace(id=uuid4(), country_code=country), db))
    assert error.value.status_code == 403 and error.value.detail == expected
    assert db.execute.await_count == 1


def test_push_disabled_keeps_the_same_zero_io_path(monkeypatch):
    monkeypatch.setattr(push, "is_push_enabled", lambda: False)
    send = AsyncMock()
    monkeypatch.setattr(push, "send_push_to_user", send)
    asyncio.run(push.push_for_notification(object(), object(), country_code="GB"))
    send.assert_not_awaited()
