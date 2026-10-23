"""Fixed server copy selected from an account's persisted market, never IP."""

from app.core.markets import account_country


def account_text(user: object, polish: str, english: str) -> str:
    return english if account_country(user) == "GB" else polish
