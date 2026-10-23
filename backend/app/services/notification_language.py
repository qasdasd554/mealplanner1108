"""Notification language belongs to the recipient's immutable account market."""

from app.core.markets import account_country
from app.models.user import User


def notification_text(recipient: object, polish: str, english: str) -> str:
    return country_text(account_country(recipient), polish, english)


def country_text(country: str, polish: str, english: str) -> str:
    return english if country == "GB" else polish


async def recipient_text(db, user_id, polish: str, english: str) -> str:
    return notification_text(await db.get(User, user_id), polish, english)
