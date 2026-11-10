"""Fixed server copy selected from an account's persisted market, never IP."""

from functools import lru_cache
import json
from pathlib import Path

from app.core.markets import account_country


@lru_cache(maxsize=1)
def _german_messages() -> dict[str, str]:
    path = Path(__file__).resolve().parents[1] / "data" / "messages_de.json"
    return json.loads(path.read_text(encoding="utf-8"))


def message_for_country(country: str, polish: str, english: str) -> str:
    if country == "DE":
        return _german_messages().get(english, english)
    return english if country == "GB" else polish


def account_text(user: object, polish: str, english: str) -> str:
    return message_for_country(account_country(user), polish, english)
