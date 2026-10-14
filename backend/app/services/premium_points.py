"""Spend points using a database condition instead of an auth snapshot."""

from fastapi import HTTPException
from sqlalchemy import update

from app.models.user import User


async def spend_points(db, user_id, amount: int) -> None:
    result = await db.execute(update(User).where(
        User.id == user_id, User.premium_points >= amount,
    ).values(premium_points=User.premium_points - amount).execution_options(synchronize_session=False))
    if result.rowcount != 1:
        raise HTTPException(status_code=402, detail=f"Brakuje {amount} punktów premium.")
