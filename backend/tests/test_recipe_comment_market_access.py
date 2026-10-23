"""Comment routes obey recipe permissions and market availability.

Only ephemeral SQLite and disabled notification delivery are used. No external
database, account credentials, AI, FCM or other network service is accessed.
"""

from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.api.v1 import recipe_comments
from app.core.exceptions import NotFoundException
from app.models import Base, Friendship, Notification, Product, Recipe, RecipeIngredient, User
from app.models.friendship import canonical_friend_ids
from app.models.recipe_comment import RecipeComment, RecipeCommentLike
from app.models.recipe_favorite import RecipeFavorite
from app.schemas.moderation import ContentReportCreate
from app.schemas.recipe_comment import RecipeCommentCreate
from tests.uk_regional_fixtures import reviewed_offer, uk_store


class AsyncSessionAdapter:
    def __init__(self, session):
        self.session = session
        self.executed_queries = []

    async def execute(self, query):
        self.executed_queries.append(query)
        return self.session.execute(query)

    async def get(self, model, identifier):
        return self.session.get(model, identifier)

    def add(self, value):
        if getattr(value, "id", None) is None:
            value.id = uuid4()
        self.session.add(value)

    async def commit(self):
        self.session.commit()

    async def refresh(self, value):
        self.session.refresh(value)

    async def rollback(self):
        self.session.rollback()

    async def delete(self, value):
        self.session.delete(value)


@pytest.fixture
def context(monkeypatch, request):
    monkeypatch.setattr(recipe_comments, "_send_pushes", AsyncMock())
    monkeypatch.setattr(
        "app.services.admin_notifications.notify_admins_pending_review",
        AsyncMock(return_value=0),
    )
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    parameters = getattr(getattr(request.node, "callspec", None), "params", {})
    allowed = parameters.get("allowed")
    owner_country = "GB" if allowed == "owner_gb" else "PL"
    admin_country = "GB" if allowed == "admin_gb" else "PL"
    viewer_country = "GB" if (allowed == "gb_available" or parameters.get("inaccessible") in {"gb_unavailable", "gb_friend_unavailable"}) else "PL"
    with Session(engine, expire_on_commit=False) as session:
        owner = User(id=uuid4(), email="owner@example.invalid", country_code=owner_country, password_hash="test")
        viewer = User(id=uuid4(), email="viewer@example.invalid", country_code=viewer_country, password_hash="test")
        admin = User(id=uuid4(), email="admin@example.invalid", country_code=admin_country, password_hash="test", role="admin")
        product = Product(id=uuid4(), name="Ingredient", unit="g")
        recipe = Recipe(
            id=uuid4(), name="Private recipe", meal_type="obiad",
            created_by_user_id=owner.id, visibility="private", is_active=True,
        )
        comment = RecipeComment(id=uuid4(), recipe_id=recipe.id, user_id=owner.id, text="Private note")
        session.add_all([owner, viewer, admin, product, recipe, comment])
        session.flush()
        session.add(RecipeIngredient(
            id=uuid4(), recipe_id=recipe.id, product_id=product.id,
            quantity=Decimal("100"), unit="g", is_optional=False,
        ))
        session.commit()
        yield session, AsyncSessionAdapter(session), owner, viewer, admin, product, recipe, comment
    engine.dispose()


async def _operate(operation, db, user, recipe, comment):
    kwargs = {"recipe_id": recipe.id, "db": db, "current_user": user}
    if operation == "read":
        return await recipe_comments.list_recipe_comments(**kwargs)
    if operation == "create":
        return await recipe_comments.create_recipe_comment(
            **kwargs, payload=RecipeCommentCreate(text="Reply"),
        )
    kwargs["comment_id"] = comment.id
    if operation == "like":
        return await recipe_comments.like_recipe_comment(**kwargs)
    if operation == "unlike":
        return await recipe_comments.unlike_recipe_comment(**kwargs)
    return await recipe_comments.report_recipe_comment(
        **kwargs, payload=ContentReportCreate(reason="other", details="Test report"),
    )


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["read", "create", "like", "unlike", "report"])
@pytest.mark.parametrize("inaccessible", ["private", "pending", "rejected", "inactive", "gb_unavailable", "gb_friend_unavailable"])
async def test_comment_routes_reject_inaccessible_recipes(context, operation, inaccessible):
    session, db, owner, viewer, _, _, recipe, comment = context
    if inaccessible == "inactive":
        recipe.is_active = False
        recipe.visibility = "public"
    elif inaccessible == "gb_unavailable":
        recipe.visibility = "public"
    elif inaccessible == "gb_friend_unavailable":
        first, second = canonical_friend_ids(owner.id, viewer.id)
        session.add(Friendship(
            id=uuid4(), user_a_id=first, user_b_id=second,
            requested_by_id=owner.id, status="accepted",
        ))
    else:
        recipe.visibility = inaccessible
    session.commit()
    with pytest.raises(NotFoundException):
        await _operate(operation, db, viewer, recipe, comment)
    assert session.query(RecipeComment).count() == 1
    assert session.query(RecipeCommentLike).count() == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["read", "create", "like", "unlike", "report"])
async def test_missing_recipe_returns_not_found_before_comment_actions(context, operation):
    session, db, _, viewer, _, _, _, comment = context
    missing = SimpleNamespace(id=uuid4())
    with pytest.raises(NotFoundException):
        await _operate(operation, db, viewer, missing, comment)
    assert session.query(RecipeComment).count() == 1


@pytest.mark.asyncio
async def test_unlike_cannot_mutate_hidden_comment(context):
    session, db, _, viewer, _, _, recipe, comment = context
    session.add(RecipeCommentLike(id=uuid4(), comment_id=comment.id, user_id=viewer.id))
    session.commit()
    with pytest.raises(NotFoundException):
        await _operate("unlike", db, viewer, recipe, comment)
    assert session.query(RecipeCommentLike).count() == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["read", "create", "like", "unlike", "report"])
@pytest.mark.parametrize("allowed", ["owner_gb", "admin_gb", "pl_public", "pl_friend", "gb_available"])
async def test_comment_routes_keep_author_admin_friend_and_local_access(context, operation, allowed):
    session, db, owner, viewer, admin, product, recipe, comment = context
    user = viewer
    if allowed == "owner_gb":
        user = owner
    elif allowed == "admin_gb":
        recipe.visibility = "pending"
        user = admin
    elif allowed == "pl_public":
        recipe.visibility = "public"
    elif allowed == "pl_friend":
        first, second = canonical_friend_ids(owner.id, viewer.id)
        session.add(Friendship(
            id=uuid4(), user_a_id=first, user_b_id=second,
            requested_by_id=owner.id, status="accepted",
        ))
    else:
        recipe.visibility = "public"
        reviewed_offer(session, product, uk_store(session), price="1.00")
    session.commit()
    response = await _operate(operation, db, user, recipe, comment)
    if operation == "read":
        assert [item.text for item in response] == ["Private note"]
    if operation == "create":
        assert response.text == "Reply"
        assert session.query(RecipeComment).count() == 2


@pytest.mark.asyncio
@pytest.mark.parametrize("actor", ["author", "admin"])
async def test_comment_deletion_remains_possible_after_recipe_becomes_unavailable(context, actor):
    session, db, owner, _, admin, _, recipe, comment = context
    recipe.is_active = False
    session.commit()
    user = owner if actor == "author" else admin
    await recipe_comments.delete_recipe_comment(recipe.id, comment.id, db=db, current_user=user)
    assert session.query(RecipeComment).count() == 0


@pytest.mark.asyncio
async def test_stranger_cannot_delete_a_comment(context):
    session, db, _, viewer, _, _, recipe, comment = context
    with pytest.raises(HTTPException) as failure:
        await recipe_comments.delete_recipe_comment(recipe.id, comment.id, db=db, current_user=viewer)
    assert failure.value.status_code == 403
    assert session.query(RecipeComment).count() == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("visibility", ["private", "pending", "rejected"])
async def test_historical_participants_cannot_receive_private_comment_notifications(context, visibility):
    session, db, owner, viewer, _, _, recipe, _ = context
    recipe.visibility = visibility
    session.add(RecipeComment(id=uuid4(), recipe_id=recipe.id, user_id=viewer.id, text="Old participation"))
    session.add(RecipeFavorite(id=uuid4(), recipe_id=recipe.id, user_id=viewer.id))
    fresh = RecipeComment(id=uuid4(), recipe_id=recipe.id, user_id=owner.id, text="Private update")
    session.add(fresh)
    session.commit()
    await recipe_comments._notify_thread_participants(db, recipe, fresh, owner)
    assert session.query(Notification).filter(Notification.user_id == viewer.id).count() == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("market_available", [False, True])
async def test_gb_comment_notifications_require_availability_but_recipe_author_is_kept(context, market_available):
    session, db, owner, _, admin, product, recipe, _ = context
    gb_user = User(id=uuid4(), email="gb-recipient@example.invalid", country_code="GB", password_hash="test")
    session.add(gb_user)
    session.flush()
    recipe.visibility = "public"
    session.add(RecipeFavorite(id=uuid4(), recipe_id=recipe.id, user_id=gb_user.id))
    if market_available:
        reviewed_offer(session, product, uk_store(session), price="1.00")
    fresh = RecipeComment(id=uuid4(), recipe_id=recipe.id, user_id=admin.id, text="Public update")
    session.add(fresh)
    session.commit()
    await recipe_comments._notify_thread_participants(db, recipe, fresh, admin)
    ids = {item.user_id for item in session.query(Notification).all()}
    assert owner.id in ids
    assert (gb_user.id in ids) is market_available


@pytest.mark.asyncio
async def test_private_comment_notifications_keep_current_friend_and_admin(context):
    session, db, owner, viewer, admin, _, recipe, _ = context
    first, second = canonical_friend_ids(owner.id, viewer.id)
    session.add(Friendship(
        id=uuid4(), user_a_id=first, user_b_id=second,
        requested_by_id=owner.id, status="accepted",
    ))
    for user in (viewer, admin):
        session.add(RecipeFavorite(id=uuid4(), recipe_id=recipe.id, user_id=user.id))
    fresh = RecipeComment(id=uuid4(), recipe_id=recipe.id, user_id=owner.id, text="Allowed update")
    session.add(fresh)
    session.commit()
    await recipe_comments._notify_thread_participants(db, recipe, fresh, owner)
    assert {item.user_id for item in session.query(Notification).all()} == {viewer.id, admin.id}


@pytest.mark.asyncio
async def test_like_does_not_notify_a_former_private_recipe_participant(context):
    session, db, owner, viewer, _, _, recipe, comment = context
    comment.user_id = viewer.id
    session.commit()
    await recipe_comments.like_recipe_comment(recipe.id, comment.id, db=db, current_user=owner)
    assert session.query(RecipeCommentLike).count() == 1
    assert session.query(Notification).count() == 0


@pytest.mark.asyncio
async def test_uk_notification_availability_is_not_queried_per_recipient(context):
    session, db, _, _, _, product, recipe, _ = context
    recipe.visibility = "public"
    reviewed_offer(session, product, uk_store(session), price="1.00")
    recipients = [User(
        id=uuid4(), email=f"recipient-{number}@example.invalid", country_code="GB", password_hash="test",
    ) for number in range(12)]
    session.add_all(recipients)
    session.commit()
    one = await recipe_comments._notification_recipients(db, recipe, {recipients[0].id})
    single_count = len(db.executed_queries)
    db.executed_queries.clear()
    many = await recipe_comments._notification_recipients(db, recipe, {user.id for user in recipients})
    assert len(one) == 1
    assert len(many) == 12
    assert len(db.executed_queries) == single_count
