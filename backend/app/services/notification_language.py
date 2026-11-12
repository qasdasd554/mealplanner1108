"""Notification language belongs to the recipient's immutable account market."""

from app.core.markets import account_country
from app.core.language import message_for_country
from app.models.user import User


def notification_text(recipient: object, polish: str, english: str, *, german: str | None = None) -> str:
    return country_text(account_country(recipient), polish, english, german=german)


def country_text(country: str, polish: str, english: str, *, german: str | None = None) -> str:
    if country == "DE" and german is not None:
        return german
    return message_for_country(country, polish, english)


async def recipient_text(db, user_id, polish: str, english: str, *, german: str | None = None) -> str:
    return notification_text(await db.get(User, user_id), polish, english, german=german)
