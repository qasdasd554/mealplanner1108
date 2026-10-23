"""Zaproszenia do znajomych oraz bezpieczny, tylko do odczytu podgląd danych znajomego."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.core.rate_limit import enforce_user_rate_limit, friend_invitation_limiter
from app.core.markets import account_country
from app.models import (
    BlockedUser,
    Friendship,
    MealPlan,
    Notification,
    Recipe,
    RecipeIngredient,
    ShoppingList,
    ShoppingListItem,
    StoreProduct,
    User,
)
from app.models.friendship import canonical_friend_ids
from app.schemas.friendship import FriendEntry, FriendInvitationCreate
from app.schemas.recipe import RecipeResponse
from app.schemas.shopping_list import ShoppingListResponse
from app.services.market_catalog import apply_recipe_market_filter

router = APIRouter()


def _text(country_code: str, polish: str, english: str) -> str:
    return english if country_code == "GB" else polish


def _pair_filter(first: UUID, second: UUID):
    user_a, user_b = canonical_friend_ids(first, second)
    return and_(Friendship.user_a_id == user_a, Friendship.user_b_id == user_b)


def _other_user(connection: Friendship, current_user_id: UUID) -> User:
    return connection.user_b if connection.user_a_id == current_user_id else connection.user_a


def _entry(connection: Friendship, current_user_id: UUID, *, country_code: str = "PL") -> FriendEntry:
    other = _other_user(connection, current_user_id)
    direction = None
    if connection.status == "pending":
        direction = "outgoing" if connection.requested_by_id == current_user_id else "incoming"
    return FriendEntry(
        connection_id=connection.id,
        user_id=other.id,
        display_name=other.display_name or _text(country_code, "Użytkownik", "User"),
        avatar=other.avatar,
        avatar_photo_base64=other.avatar_photo_base64,
        status=connection.status,
        direction=direction,
        created_at=connection.created_at,
    )


async def _get_connection(db: AsyncSession, current_user_id: UUID, friend_id: UUID,
                          *, country_code: str = "PL") -> Friendship:
    result = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.user_a), selectinload(Friendship.user_b))
        .where(_pair_filter(current_user_id, friend_id), Friendship.status == "accepted")
    )
    connection = result.scalar_one_or_none()
    if connection is None:
        raise HTTPException(status_code=403, detail=_text(country_code,
            "Ta osoba nie jest na Twojej liście znajomych.", "This person is not on your friends list."))
    return connection


async def _notify(db: AsyncSession, user_id: UUID, notification_type: str, message: str,
                  *, country_code: str = "PL") -> None:
    notification = Notification(user_id=user_id, notification_type=notification_type, message=message)
    db.add(notification)
    await db.commit()
    try:
        from app.services.push import push_for_notification

        await push_for_notification(db, notification, country_code=country_code)
    except Exception:
        # Push jest dodatkiem. Zaproszenie pozostaje zapisane nawet przy
        # chwilowym błędzie konfiguracji APNs/FCM.
        pass


@router.post("/invitations", response_model=FriendEntry, status_code=status.HTTP_201_CREATED)
async def send_invitation(
    payload: FriendInvitationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FriendEntry:
    country = account_country(current_user)
    enforce_user_rate_limit(friend_invitation_limiter, current_user.id, "zaproszenie do znajomych")
    identifier = payload.identifier.strip()
    if "@" in identifier:
        result = await db.execute(select(User).where(func.lower(User.email) == identifier.lower()))
        target = result.scalar_one_or_none()
    else:
        result = await db.execute(
            select(User).where(func.lower(User.display_name) == identifier.lower()).limit(2)
        )
        matches = list(result.scalars().all())
        if len(matches) > 1:
            raise HTTPException(status_code=409, detail=_text(country,
                "Ta nazwa nie jest unikalna. Wpisz adres e-mail znajomego.",
                "This username is not unique. Enter your friend's email address."))
        target = matches[0] if matches else None

    if target is None or target.is_banned:
        raise HTTPException(status_code=404, detail=_text(country,
            "Nie znaleziono użytkownika o tej nazwie lub adresie e-mail.",
            "No user was found with this username or email address."))
    if target.id == current_user.id:
        raise HTTPException(status_code=400, detail=_text(country,
            "Nie możesz wysłać zaproszenia do siebie.", "You cannot send yourself a friend request."))

    blocked = await db.execute(
        select(BlockedUser.id).where(
            or_(
                and_(BlockedUser.user_id == current_user.id, BlockedUser.blocked_user_id == target.id),
                and_(BlockedUser.user_id == target.id, BlockedUser.blocked_user_id == current_user.id),
            )
        )
    )
    if blocked.scalar_one_or_none() is not None:
        raise HTTPException(status_code=403, detail=_text(country,
            "Nie można wysłać zaproszenia do tego użytkownika.", "You cannot send a friend request to this user."))

    existing_result = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.user_a), selectinload(Friendship.user_b))
        .where(_pair_filter(current_user.id, target.id))
    )
    existing = existing_result.scalar_one_or_none()
    if existing is not None:
        if existing.status == "accepted":
            raise HTTPException(status_code=409, detail=_text(country,
                "Ta osoba jest już Twoim znajomym.", "This person is already your friend."))
        raise HTTPException(status_code=409, detail=_text(country,
            "Zaproszenie między tymi kontami już oczekuje.", "A friend request between these accounts is already pending."))

    user_a, user_b = canonical_friend_ids(current_user.id, target.id)
    connection = Friendship(
        user_a_id=user_a,
        user_b_id=user_b,
        requested_by_id=current_user.id,
        status="pending",
    )
    db.add(connection)
    await db.commit()
    result = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.user_a), selectinload(Friendship.user_b))
        .where(Friendship.id == connection.id)
    )
    connection = result.scalar_one()
    await _notify(
        db,
        target.id,
        "friend_invitation",
        _text(account_country(target),
            f"{current_user.display_name or 'Ktoś'} wysłał(a) Ci zaproszenie do znajomych.",
            f"{current_user.display_name or 'Someone'} sent you a friend request."),
        country_code=account_country(target),
    )
    return _entry(connection, current_user.id, country_code=country)


@router.get("/", response_model=list[FriendEntry])
async def list_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[FriendEntry]:
    result = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.user_a), selectinload(Friendship.user_b))
        .where(
            or_(Friendship.user_a_id == current_user.id, Friendship.user_b_id == current_user.id),
            Friendship.status == "accepted",
        )
        .order_by(Friendship.updated_at.desc())
    )
    return [_entry(connection, current_user.id, country_code=account_country(current_user)) for connection in result.scalars().all()]


@router.get("/invitations", response_model=list[FriendEntry])
async def list_invitations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[FriendEntry]:
    result = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.user_a), selectinload(Friendship.user_b))
        .where(
            or_(Friendship.user_a_id == current_user.id, Friendship.user_b_id == current_user.id),
            Friendship.status == "pending",
        )
        .order_by(Friendship.created_at.desc())
    )
    return [_entry(connection, current_user.id, country_code=account_country(current_user)) for connection in result.scalars().all()]


@router.post("/invitations/{connection_id}/accept", response_model=FriendEntry)
async def accept_invitation(
    connection_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FriendEntry:
    result = await db.execute(
        select(Friendship)
        .options(selectinload(Friendship.user_a), selectinload(Friendship.user_b))
        .where(
            Friendship.id == connection_id,
            or_(Friendship.user_a_id == current_user.id, Friendship.user_b_id == current_user.id),
            Friendship.status == "pending",
            Friendship.requested_by_id != current_user.id,
        )
    )
    connection = result.scalar_one_or_none()
    if connection is None:
        raise HTTPException(status_code=404, detail=_text(account_country(current_user),
            "Nie znaleziono oczekującego zaproszenia.", "No pending friend request was found."))
    connection.status = "accepted"
    sender_id = connection.requested_by_id
    await db.commit()
    await _notify(
        db,
        sender_id,
        "friend_accepted",
        _text(account_country(_other_user(connection, current_user.id)),
            f"{current_user.display_name or 'Ktoś'} przyjął(-ęła) Twoje zaproszenie do znajomych.",
            f"{current_user.display_name or 'Someone'} accepted your friend request."),
        country_code=account_country(_other_user(connection, current_user.id)),
    )
    return _entry(connection, current_user.id, country_code=account_country(current_user))


@router.delete("/invitations/{connection_id}", status_code=status.HTTP_200_OK)
async def decline_or_cancel_invitation(
    connection_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, bool]:
    result = await db.execute(
        delete(Friendship).where(
            Friendship.id == connection_id,
            or_(Friendship.user_a_id == current_user.id, Friendship.user_b_id == current_user.id),
            Friendship.status == "pending",
        )
    )
    if not result.rowcount:
        raise HTTPException(status_code=404, detail=_text(account_country(current_user),
            "Nie znaleziono oczekującego zaproszenia.", "No pending friend request was found."))
    await db.commit()
    return {"deleted": True}


@router.delete("/{friend_id}", status_code=status.HTTP_200_OK)
async def remove_friend(
    friend_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, bool]:
    result = await db.execute(
        delete(Friendship).where(_pair_filter(current_user.id, friend_id), Friendship.status == "accepted")
    )
    if not result.rowcount:
        raise HTTPException(status_code=404, detail=_text(account_country(current_user),
            "Nie znaleziono znajomego.", "Friend not found."))
    await db.commit()
    return {"deleted": True}


@router.get("/{friend_id}/recipes", response_model=list[RecipeResponse])
async def friend_recipes(
    friend_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Recipe]:
    await _get_connection(db, current_user.id, friend_id, country_code=account_country(current_user))
    query = (
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product),
            selectinload(Recipe.tags),
            selectinload(Recipe.creator),
        )
        .where(
            Recipe.created_by_user_id == friend_id,
            Recipe.is_active.is_(True),
            Recipe.visibility.in_(["private", "public"]),
        )
    )
    # Friendship grants read-only access to the author's private recipes, but
    # does not override the viewing account's local ingredient availability.
    # Filter in SQL before any ordering/pagination; PL remains unchanged.
    query = apply_recipe_market_filter(query, current_user)
    result = await db.execute(query.order_by(Recipe.created_at.desc()))
    recipes = list(result.unique().scalars().all())
    for recipe in recipes:
        recipe.is_favorite = False
        recipe.is_own_recipe = False
    return recipes


@router.get("/{friend_id}/shopping-lists", response_model=list[ShoppingListResponse])
async def friend_shopping_lists(
    friend_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ShoppingList]:
    await _get_connection(db, current_user.id, friend_id, country_code=account_country(current_user))
    result = await db.execute(
        select(ShoppingList)
        .join(MealPlan, MealPlan.id == ShoppingList.meal_plan_id)
        .options(
            selectinload(ShoppingList.items)
            .selectinload(ShoppingListItem.store_product)
            .selectinload(StoreProduct.product),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.department),
            selectinload(ShoppingList.items).selectinload(ShoppingListItem.substituted_for_product),
            selectinload(ShoppingList.store),
        )
        .where(MealPlan.user_id == friend_id, ShoppingList.status != "completed")
        .order_by(ShoppingList.created_at.desc())
        .limit(10)
    )
    return list(result.scalars().all())
