"""Notification copy follows the persisted recipient, without contacting FCM."""

from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.services import push


def test_every_existing_notification_title_has_a_british_translation():
    assert set(push._TITLES_EN) == set(push._TITLES)


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB", None, "US"])
@pytest.mark.parametrize("kind,polish,english", [
    ("recipe_comment", "Nowy komentarz", "New comment"),
    ("comment_like", "Ktoś polubił Twój komentarz", "Someone liked your comment"),
    ("shopping_list_share", "Udostępniono Ci listę zakupów", "A shopping list has been shared with you"),
    ("recipe_approved", "Przepis zaakceptowany", "Recipe approved"),
    ("recipe_photo", "Zdjęcie przepisu", "Recipe photo"),
    ("product_reviewed", "Zgłoszony produkt", "Your submitted product"),
    ("recipe_import_ready", "Przepis jest gotowy", "Your recipe is ready"),
    ("recipe_import_failed", "Nie udało się dodać przepisu", "Recipe import failed"),
    ("weekly_plan_ready", "Twój plan na tydzień jest gotowy", "Your weekly plan is ready"),
    ("meal_plan_expiring", "Twój plan wkrótce się kończy", "Your meal plan ends soon"),
    ("friend_invitation", "Nowe zaproszenie do znajomych", "New friend request"),
    ("broadcast", "Meal Planner Polska", "Meal Planner Polska"),
])
async def test_push_title_uses_persisted_recipient_and_preserves_payload(monkeypatch, country, kind, polish, english):
    recipient_id, recipe_id, plan_id = uuid4(), uuid4(), uuid4()
    db = SimpleNamespace(get=AsyncMock(return_value=SimpleNamespace(country_code=country)))
    notification = SimpleNamespace(user_id=recipient_id, notification_type=kind,
        recipe_id=recipe_id, meal_plan_id=plan_id, message="Original user text")
    send = AsyncMock(return_value=1)
    monkeypatch.setattr(push, "is_push_enabled", lambda: True)
    monkeypatch.setattr(push, "send_push_to_user", send)
    await push.push_for_notification(db, notification)
    assert send.await_count == 1
    assert send.await_args.args == (db, recipient_id,
        english if country == "GB" else polish, "Original user text",
        {"type": kind, "recipe_id": str(recipe_id), "meal_plan_id": str(plan_id)})
    db.get.assert_awaited_once()


@pytest.mark.asyncio
async def test_push_disabled_does_not_read_account_or_send(monkeypatch):
    db = SimpleNamespace(get=AsyncMock())
    send = AsyncMock()
    monkeypatch.setattr(push, "is_push_enabled", lambda: False)
    monkeypatch.setattr(push, "send_push_to_user", send)
    await push.push_for_notification(db, object())
    db.get.assert_not_awaited()
    send.assert_not_awaited()
