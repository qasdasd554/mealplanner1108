"""Real-ORM coverage for invitation -> collaboration -> revoked access, PL/GB."""
import asyncio
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from app.api.v1 import shopping_lists as api
from app.core.exceptions import NotFoundException
from app.models import Notification, ShoppingListShare, User
from tests.test_meal_plan_lifecycle import db, make_plan


def run(task):
    return asyncio.run(task)


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_sharing_requires_acceptance_and_revocation_takes_effect_immediately(db, country, monkeypatch):
    owner, plan, _, shopping, item, _ = make_plan(db, country=country)
    receiver = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                    display_name="Receiver", country_code=country)
    stranger = User(id=uuid4(), email=f"{uuid4()}@example.invalid", password_hash="test",
                    display_name="Stranger", country_code=country)
    db.session.add_all([receiver, stranger])
    db.session.commit()
    monkeypatch.setattr("app.services.push.is_push_enabled", lambda: False)

    # Public plan ID and technical list ID both identify the same invitation.
    payload = api.ShareShoppingListRequest(email=receiver.email)
    invitation = run(api.share_shopping_list(shopping.id, payload, owner, db))
    retry = run(api.share_shopping_list(plan.id, payload, owner, db))
    assert retry.id == invitation.id
    assert db.session.scalar(select(func.count()).select_from(ShoppingListShare)) == 1
    assert db.session.scalar(select(func.count()).select_from(Notification)) == 1
    assert len(run(api.get_pending_shares(receiver, db))) == 1
    assert run(api.get_shared_with_me(receiver, db)) == []
    for account in (receiver, stranger):
        with pytest.raises(NotFoundException):
            run(api._get_shopping_list_or_404(plan.id, account, db))
    for account in (owner, stranger):
        with pytest.raises(NotFoundException):
            run(api.accept_share(invitation.id, account, db))

    assert run(api.accept_share(invitation.id, receiver, db)).status == "accepted"
    run(api.accept_share(invitation.id, receiver, db))
    assert db.session.scalar(select(func.count()).select_from(Notification)) == 2
    assert run(api.get_pending_shares(receiver, db)) == []
    assert len(run(api.get_shared_with_me(receiver, db))) == 1
    assert run(api._get_shopping_list_or_404(plan.id, receiver, db)).id == shopping.id
    # Sharing does not allow forwarding the owner's list.
    with pytest.raises(NotFoundException):
        run(api.share_shopping_list(plan.id, api.ShareShoppingListRequest(email=stranger.email), receiver, db))
    # The recipient can check an item; request retry must not uncheck it.
    for _ in range(2):
        result = run(api.toggle_item_checked(plan.id, item.id, receiver, db, api.ItemCheckUpdate(is_checked=True)))
        assert result.is_checked

    async def remove(row):
        db.session.delete(row)
    db.delete = remove
    with pytest.raises(NotFoundException):
        run(api.delete_share(invitation.id, stranger, db))
    run(api.delete_share(invitation.id, owner, db))
    assert run(api.get_shared_with_me(receiver, db)) == []
    with pytest.raises(NotFoundException):
        run(api._get_shopping_list_or_404(plan.id, receiver, db))
    assert run(api._get_shopping_list_or_404(plan.id, owner, db)).id == shopping.id
