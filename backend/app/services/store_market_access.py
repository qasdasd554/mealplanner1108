"""Account-market store lookup shared by every new store-selection flow."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.markets import account_country
from app.models.store import Store


async def get_store_in_account_market(
    db: AsyncSession, store_id: UUID, user: object,
) -> Store | None:
    """Resolve an ID inside the persisted market, never a client country field.

    Filtering in SQL avoids exposing a foreign store even when the caller has
    guessed a valid UUID. Legacy/transient accounts without a persisted market
    keep the Polish default through account_country(). This helper does not
    limit access to an already shared shopping list.
    """
    result = await db.execute(select(Store).where(
        Store.id == store_id,
        Store.country_code == account_country(user),
    ))
    return result.scalar_one_or_none()
