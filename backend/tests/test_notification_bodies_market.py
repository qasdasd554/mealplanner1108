"""Existing notification events retain their semantics in both account markets."""

from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest

from app.api.v1 import billing, products, recipe_comments, recipes, shopping_lists
from app.models import Product, Recipe, User
from app.services import admin_notifications, push, weekly_contest


def _user(country, name="Robin"):
    return SimpleNamespace(id=uuid4(), country_code=country, display_name=name)


def _database(*, get=None, execute=None):
    return SimpleNamespace(get=AsyncMock(side_effect=get), execute=AsyncMock(side_effect=execute),
        add=MagicMock(), commit=AsyncMock(), refresh=AsyncMock(), rollback=AsyncMock())


@pytest.fixture(autouse=True)
def no_external_push(monkeypatch):
    monkeypatch.setattr(push, "is_push_enabled", lambda: False)


@pytest.mark.asyncio
@pytest.mark.parametrize("preview", ["Hello", "", "X" * 100])
async def test_comment_fanout_localises_each_recipient_not_the_author(monkeypatch, preview):
    polish, english = _user("PL"), _user("GB")
    actor = _user("PL", None)
    recipe = SimpleNamespace(id=uuid4(), name="Original dish", created_by_user_id=english.id)
    result = MagicMock()
    result.scalars.return_value.all.return_value = []
    db = _database(execute=lambda query: result)
    monkeypatch.setattr(recipe_comments, "_notification_recipients", AsyncMock(return_value=[polish, english]))
    send = AsyncMock()
    monkeypatch.setattr(recipe_comments, "_send_pushes", send)
    comment = SimpleNamespace(id=uuid4(), text=preview)
    await recipe_comments._notify_thread_participants(db, recipe, comment, actor)
    notices = [call.args[0] for call in db.add.call_args_list]
    assert len(notices) == 2
    pl_preview = preview[:80] + "…" if len(preview) > 80 else preview or "dodał(a) zdjęcie"
    en_preview = preview[:80] + "…" if len(preview) > 80 else preview or "added a photo"
    assert notices[0].message == f'Ktoś skomentował(a) "Original dish": {pl_preview}'
    assert notices[1].message == f'Someone commented on "Original dish": {en_preview}'
    assert [(n.user_id, n.recipe_id, n.comment_id, n.notification_type) for n in notices] == [
        (user.id, recipe.id, comment.id, "recipe_comment") for user in (polish, english)]
    db.commit.assert_awaited_once()
    send.assert_awaited_once_with(db, notices)


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_comment_like_uses_comment_owner_country(monkeypatch, country):
    recipient = _user(country)
    actor = _user("GB" if country == "PL" else "PL", "Alex")
    recipe = SimpleNamespace(id=uuid4())
    comment = SimpleNamespace(id=uuid4(), recipe_id=recipe.id, user_id=recipient.id)
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    db = _database(get=lambda model, key: comment, execute=lambda query: result)
    monkeypatch.setattr(recipe_comments, "_accessible_recipe", AsyncMock(return_value=recipe))
    monkeypatch.setattr(recipe_comments, "_notification_recipients", AsyncMock(return_value=[recipient]))
    send = AsyncMock()
    monkeypatch.setattr(recipe_comments, "_send_pushes", send)
    await recipe_comments.like_recipe_comment(recipe.id, comment.id, db=db, current_user=actor)
    notice = db.add.call_args_list[-1].args[0]
    assert notice.message == ("Alex liked your comment." if country == "GB" else "Alex polubił(a) Twój komentarz.")
    assert notice.user_id == recipient.id and notice.notification_type == "comment_like"
    send.assert_awaited_once_with(db, [notice])


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("approved", [True, False])
async def test_product_review_uses_submitter_not_admin_market(country, approved):
    recipient = _user(country)
    product = SimpleNamespace(id=uuid4(), review_status="pending", requested_store_ids=None,
        submitted_price=None, created_by_user_id=recipient.id, name="Original product")
    db = _database(get=lambda model, key: product if model is Product else recipient)
    await products.review_product(product.id, approve=approved, db=db,
        current_user=_user("GB" if country == "PL" else "PL"))
    notice = db.add.call_args_list[-1].args[0]
    assert notice.user_id == recipient.id and notice.notification_type == "product_reviewed"
    assert notice.message == (
        'Your product "Original product" has been ' + ("added to the catalogue." if approved else "rejected.")
        if country == "GB" else 'Twój produkt "Original product" został ' + ("dodany do katalogu." if approved else "odrzucony."))
    assert product.review_status == ("approved" if approved else "rejected")


@pytest.mark.asyncio
async def test_product_review_remains_saved_if_optional_recipient_lookup_fails():
    product = SimpleNamespace(id=uuid4(), review_status="pending", requested_store_ids=None,
        submitted_price=None, created_by_user_id=uuid4(), name="Original product")
    db = _database(get=iter([product, RuntimeError("recipient lookup unavailable")]))
    await products.review_product(product.id, approve=True, db=db, current_user=_user("PL"))
    assert product.review_status == "approved"
    db.commit.assert_awaited_once()
    db.rollback.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("approved", [True, False])
async def test_recipe_photo_review_uses_submitter_country(monkeypatch, country, approved):
    recipient = _user(country)
    recipe = SimpleNamespace(id=uuid4(), name="Original dish", pending_photo_user_id=recipient.id,
        pending_photo_base64="image", pending_photo_submitted_at=datetime.now(timezone.utc))
    db = _database(get=lambda model, key: recipe if model is Recipe else recipient)
    monkeypatch.setattr(recipes, "create_recipe_photo_thumbnail", lambda value: "thumbnail")
    operation = recipes.approve_recipe_photo if approved else recipes.reject_recipe_photo
    await operation(recipe.id, db=db, current_user=_user("GB" if country == "PL" else "PL"))
    notice = db.add.call_args_list[-1].args[0]
    assert notice.notification_type == "recipe_photo" and notice.user_id == recipient.id
    expected = ('Your photo for recipe "Original dish" has been approved.' if approved
        else 'Your photo for recipe "Original dish" was not approved.') if country == "GB" else (
        'Twoje zdjęcie do przepisu "Original dish" zostało zaakceptowane.' if approved
        else 'Twoje zdjęcie do przepisu "Original dish" nie zostało zaakceptowane.')
    assert notice.message == expected
    assert recipe.pending_photo_base64 is None and recipe.pending_photo_user_id is None


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_recipe_approval_uses_author_market(country):
    recipient = _user(country)
    recipe = SimpleNamespace(id=uuid4(), name="Original dish", created_by_user_id=recipient.id)
    result = MagicMock()
    result.scalar_one.return_value = recipe
    db = _database(get=lambda model, key: recipe if model is Recipe else recipient, execute=lambda query: result)
    await recipes.approve_recipe(recipe.id, db=db, current_user=_user("GB" if country == "PL" else "PL"))
    notice = db.add.call_args.args[0]
    assert notice.message == ('Your recipe "Original dish" has been approved and is now public!' if country == "GB"
        else 'Twój przepis "Original dish" został zaakceptowany i jest teraz widoczny dla wszystkich!')
    assert notice.recipe_id == recipe.id and recipe.visibility == "public"


@pytest.mark.asyncio
async def test_admin_fanout_uses_each_admin_country_in_one_lookup():
    polish, english = _user("PL"), _user("GB")
    result = MagicMock()
    result.all.return_value = [(polish.id, "PL"), (english.id, "GB")]
    db = _database(execute=lambda query: result)
    count = await admin_notifications.notify_admins_pending_review(db,
        notification_type="product_pending_approval", message="Polski opis",
        english_message="English description", recipe_id=None)
    notices = [call.args[0] for call in db.add.call_args_list]
    assert count == 2 and [n.message for n in notices] == ["Polski opis", "English description"]
    assert [n.user_id for n in notices] == [polish.id, english.id]
    db.execute.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_billing_notification_translates_copy_without_touching_purchase_state(country):
    recipient = _user(country)
    db = _database(get=lambda model, key: recipient)
    await billing._notify(db, recipient.id, "Polskie potwierdzenie", english_message="English confirmation")
    notice = db.add.call_args.args[0]
    assert notice.user_id == recipient.id and notice.notification_type == "billing"
    assert notice.message == ("English confirmation" if country == "GB" else "Polskie potwierdzenie")
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_share_acceptance_uses_original_sender_country(country):
    sender = _user(country)
    receiver = _user("GB" if country == "PL" else "PL", "Alex")
    share = SimpleNamespace(id=uuid4(), meal_plan_id=uuid4(), status="pending",
        shared_by_user_id=sender.id, shared_by=sender, created_at=datetime.now(timezone.utc))
    result = MagicMock()
    result.scalar_one_or_none.return_value = share
    db = _database(execute=lambda query: result)
    response = await shopping_lists.accept_share(share.id, current_user=receiver, db=db)
    notice = db.add.call_args.args[0]
    assert response.status == "accepted"
    assert notice.user_id == sender.id and notice.notification_type == "shopping_list_accepted"
    assert notice.message == ("Alex accepted your shopping list invitation." if country == "GB"
        else "Alex przyjął(-ęła) Twoje zaproszenie do listy zakupów.")


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_new_share_uses_target_country_and_keeps_duplicate_noop(monkeypatch, country):
    recipient = _user(country)
    recipient.email = "recipient@example.invalid"
    actor = _user("GB" if country == "PL" else "PL", "Alex")
    plan = SimpleNamespace(id=uuid4())
    result = MagicMock()
    result.scalar_one_or_none.return_value = plan
    target = MagicMock()
    target.scalar_one_or_none.return_value = recipient
    empty = MagicMock()
    empty.scalar_one_or_none.return_value = None
    db = _database(execute=iter([result, target, empty, empty]))
    def add(value):
        value.id = uuid4()
        value.created_at = datetime.now(timezone.utc)
    db.add.side_effect = add
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    payload = shopping_lists.ShareShoppingListRequest(email=recipient.email)
    response = await shopping_lists.share_shopping_list(plan.id, payload, current_user=actor, db=db)
    notice = db.add.call_args.args[0]
    assert response.status == "pending" and response.meal_plan_id == plan.id
    assert notice.user_id == recipient.id and notice.notification_type == "shopping_list_share"
    assert notice.message == ("Alex shared a shopping list with you. Open Shopping → Invitations to accept it." if country == "GB"
        else "Alex udostępnił(a) Ci listę zakupów. Otwórz Zakupy → Zaproszenia, żeby ją przyjąć.")
    existing = MagicMock()
    existing.scalar_one_or_none.return_value = SimpleNamespace(id=response.id,
        meal_plan_id=plan.id, status="pending", created_at=response.created_at)
    db.execute.side_effect = iter([result, target, empty, existing])
    db.add.reset_mock()
    second = await shopping_lists.share_shopping_list(plan.id, payload, current_user=actor, db=db)
    assert second.id == response.id
    db.add.assert_not_called()


@pytest.mark.asyncio
@pytest.mark.parametrize("with_winners", [True, False])
async def test_contest_announcement_localises_without_changing_winners_or_awards(with_winners):
    polish, english = _user("PL", "Alex"), _user("GB")
    polish.premium_points = 4
    existing = MagicMock()
    existing.scalar_one_or_none.return_value = None
    winners = MagicMock()
    winners.all.return_value = [(polish.id, "Alex", 2)] if with_winners else []
    recipients = MagicMock()
    recipients.all.return_value = [(polish.id, "PL"), (english.id, "GB")]
    db = _database(get=lambda model, key: polish, execute=iter([existing, winners, recipients]))
    payout = await weekly_contest.process_weekly_contest_payout(db)
    notices = [call.args[0] for call in db.add.call_args_list if hasattr(call.args[0], "notification_type")]
    assert payout is not None and len(notices) == 2
    assert notices[0].message.startswith("Nowy tydzień konkursu przepisów właśnie się zaczął!")
    assert notices[1].message.startswith("A new week of the recipe contest has started!")
    assert ("Alex" in notices[0].message) == with_winners
    assert ("Alex" in notices[1].message) == with_winners
    assert polish.premium_points == (7 if with_winners else 4)
    db.commit.assert_awaited_once()
