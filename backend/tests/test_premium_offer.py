from datetime import datetime, timedelta, timezone

from app.services.premium_offer import (
    PREMIUM_OFFER_COOLDOWN,
    is_premium_offer_due,
    premium_offer_next_eligible_at,
)


def test_first_contextual_offer_is_due() -> None:
    now = datetime(2026, 10, 5, 10, tzinfo=timezone.utc)
    assert is_premium_offer_due(None, now=now)


def test_offer_is_not_due_before_seven_days() -> None:
    now = datetime(2026, 10, 5, 10, tzinfo=timezone.utc)
    last_shown = now - PREMIUM_OFFER_COOLDOWN + timedelta(seconds=1)
    assert not is_premium_offer_due(last_shown, now=now)


def test_offer_is_due_exactly_after_seven_days() -> None:
    now = datetime(2026, 10, 5, 10, tzinfo=timezone.utc)
    last_shown = now - PREMIUM_OFFER_COOLDOWN
    assert is_premium_offer_due(last_shown, now=now)
    assert premium_offer_next_eligible_at(last_shown) == now
