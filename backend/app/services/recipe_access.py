"""Visibility checks shared by direct and indirect recipe access."""

from sqlalchemy import and_, exists, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundException
from app.core.language import account_text
from app.core.markets import account_country
from app.models import Friendship, Recipe, User


def recipe_origin_in_market(country_code: str):
    """Only system recipes are shared; user recipes follow the author's market.

    The account market is immutable. Reuse the author's persisted country,
    not device language, ingredient availability, title or moderation status.
    Explicit correlation keeps this safe in queries already joining User.
    """
    author_in_market = exists(select(User.id).where(
        User.id == Recipe.created_by_user_id,
        func.coalesce(User.country_code, "PL") == country_code,
    ).correlate(Recipe))
    return or_(Recipe.created_by_user_id.is_(None), author_in_market)


async def ensure_recipe_access(db: AsyncSession, recipe: Recipe | None, user: User) -> None:
    """Hide inaccessible recipes before attaching them to another resource."""
    denied = NotFoundException(detail=account_text(user, "Przepis nie został znaleziony.", "Recipe not found."))
    if recipe is None or not getattr(recipe, "is_active", True):
        raise denied
    author = recipe.created_by_user_id
    if author is None or author == user.id or user.role == "admin":
        return
    if recipe.visibility not in {"private", "public"}:
        raise denied
    # A public approval or a friendship must not merge PL and GB catalogues.
    origin = await db.execute(select(User.id).where(
        User.id == author,
        func.coalesce(User.country_code, "PL") == account_country(user),
    ))
    if origin.scalar_one_or_none() is None:
        raise denied
    if recipe.visibility == "public":
        return
    connection = await db.execute(select(Friendship.id).where(
        Friendship.status == "accepted",
        or_(
            and_(Friendship.user_a_id == user.id, Friendship.user_b_id == author),
            and_(Friendship.user_b_id == user.id, Friendship.user_a_id == author),
        ),
    ))
    if connection.scalar_one_or_none() is None:
        raise denied
