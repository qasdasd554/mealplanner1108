"""Visibility checks shared by direct and indirect recipe access."""

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundException
from app.core.language import account_text
from app.models import Friendship, Recipe, User


async def ensure_recipe_access(db: AsyncSession, recipe: Recipe | None, user: User) -> None:
    """Hide inaccessible recipes before attaching them to another resource."""
    denied = NotFoundException(detail=account_text(user, "Przepis nie został znaleziony.", "Recipe not found."))
    if recipe is None or not getattr(recipe, "is_active", True):
        raise denied
    author = recipe.created_by_user_id
    if author is None or author == user.id or recipe.visibility == "public" or user.role == "admin":
        return
    if recipe.visibility != "private":
        raise denied
    connection = await db.execute(select(Friendship.id).where(
        Friendship.status == "accepted",
        or_(
            and_(Friendship.user_a_id == user.id, Friendship.user_b_id == author),
            and_(Friendship.user_b_id == user.id, Friendship.user_a_id == author),
        ),
    ))
    if connection.scalar_one_or_none() is None:
        raise denied
