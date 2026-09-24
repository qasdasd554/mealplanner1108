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


def test_accepts_android_subscription_offer():
    payload = _payload(
        platform="android",
        ios_offer_url=None,
        android_base_plan_id="monthly",
        android_offer_id="campaign-30",
    )
    assert CampaignCreate(**payload).android_offer_id == "campaign-30"


def test_accepts_android_global_points_price_campaign():
    payload = _payload(
        platform="android", ios_offer_url=None, kind="points",
        product_id="points_20", audience="all",
    )
    assert CampaignCreate(**payload).kind == "points"


def test_accepts_ios_global_points_price_campaign_without_offer_code():
    payload = _payload(
        platform="ios", ios_offer_url=None, kind="points",
        product_id="points_20", audience="all",
    )
    assert CampaignCreate(**payload).ios_offer_url is None


@pytest.mark.parametrize("changes", [
    {"ios_offer_url": "https://apps.apple.com.evil.example/redeem"},
    {"product_id": "points_20"},
    {"audience": "user"},
    {"discount_percent": 0},
    {"platform": "android", "ios_offer_url": None},
    {"platform": "android", "ios_offer_url": None, "kind": "points", "product_id": "points_20", "audience": "user", "target_email": "a@b.pl"},
    {"platform": "ios", "ios_offer_url": None, "kind": "points", "product_id": "points_20", "audience": "user", "target_email": "a@b.pl"},
])
def test_rejects_invalid_campaign(changes):
    with pytest.raises(ValidationError):
        CampaignCreate(**_payload(**changes))
