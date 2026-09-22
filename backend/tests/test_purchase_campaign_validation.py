"""Kampania nie może wskazać innego produktu ani dowolnej domeny."""

from datetime import datetime, timedelta, timezone

import pytest
from pydantic import ValidationError

from app.api.v1.purchase_campaigns import CampaignCreate


def _payload(**changes):
    now = datetime.now(timezone.utc)
    data = {
        "name": "Rabat wrzesień",
        "kind": "premium",
        "product_id": "premium_monthly",
        "discount_percent": 30,
        "audience": "all",
        "starts_at": now,
        "ends_at": now + timedelta(days=7),
        "ios_offer_url": "https://apps.apple.com/redeem?ctx=offercodes&id=123",
    }
    data.update(changes)
    return data


def test_accepts_apple_offer_url_for_matching_product():
    assert CampaignCreate(**_payload()).discount_percent == 30


@pytest.mark.parametrize("changes", [
    {"ios_offer_url": "https://apps.apple.com.evil.example/redeem"},
    {"product_id": "points_20"},
    {"audience": "user"},
    {"discount_percent": 0},
])
def test_rejects_invalid_campaign(changes):
    with pytest.raises(ValidationError):
        CampaignCreate(**_payload(**changes))
