"""Account-market calendar boundaries, independent of server/device timezone."""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from app.core.markets import account_country


def market_timezone(user_or_country=None) -> ZoneInfo:
    country = user_or_country if isinstance(user_or_country, str) else account_country(user_or_country)
    return ZoneInfo("Europe/London" if country == "GB" else "Europe/Warsaw")


def market_today(user_or_country=None, *, now: datetime | None = None):
    instant = now or datetime.now(timezone.utc)
    if instant.tzinfo is None:
        instant = instant.replace(tzinfo=timezone.utc)
    return instant.astimezone(market_timezone(user_or_country)).date()
