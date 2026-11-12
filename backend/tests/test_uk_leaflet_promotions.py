"""Lidl GB scanning, moderation and market separation."""

import asyncio
import json
from dataclasses import replace
from datetime import date, timedelta
from decimal import Decimal
from html import escape
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1 import promotions
from app.models import Product, Store, StoreProduct
from app.schemas.promotion import PromotionResponse
from app.services import promotion_expiry, retailer_promotion_queue as queue
from app.services.uk_leaflet_promotions import _lidl_campaign_url, parse_lidl_gb_leaflet
from tests.test_de_leaflet_promotions import LocalDatabase
from tests.test_market_prices_promotions import market_price_db


TODAY = date(2026, 11, 12)
SOURCE = "https://www.lidl.co.uk/c/store/pick-of-the-week/a10088664"
SKU = "11029903"


def _product(**changes):
    return {
        "store": True,
        "productType": "RETAIL",
        "title": "Ripen at Home Avocados",
        "productId": int(SKU),
        "canonicalPath": f"/p/ripen-at-home-avocados/p{SKU}",
        "storeStartDate": 1794441600,
        "storeEndDate": 1795046399,
        "regionsV2": {"1": {"status": "ONLINE", "regionPriceId": "1"}},
        "regionsPrices": {"1": {"currentPrice": {
            "price": 1.59, "oldPrice": 1.99, "currencyCode": "GBP",
            "startDate": "2026-11-02T11:38:20Z", "endDateExclusive": "2026-11-19T00:00Z",
            "packaging": {"text": "700g"}, "discount": {"showDiscount": True, "deletedPrice": 1.99},
        }}},
        **changes,
    }


def _parse(*products, today=TODAY):
    tiles = "".join(
        '<div data-country="GB" category="Food" listname="Pick of the Week" '
        f'data-grid-data="{escape(json.dumps(product), quote=True)}"></div>'
        for product in products
    )
    return parse_lidl_gb_leaflet(
        f"<main>{tiles}</main>".encode(), today=today, catalogue_skus={SKU}, source_url=SOURCE,
    )


def test_campaign_discovery_stays_on_current_week_and_official_domain():
    current = b'<div class="AHeroStage__Body-Current_Sales_Week"><a href="/c/store/pick-of-the-week/a10088664"></a></div>'
    future = b'<div class="AHeroStage__Body-Next_Sales_Week"><a href="/c/store/pick-of-the-week/a10099999"></a></div>'
    assert _lidl_campaign_url(current + future) == SOURCE
    with pytest.raises(ValueError):
        _lidl_campaign_url(current.replace(b'href="/c/', b'href="//other.example/c/'))


def test_scan_uses_in_store_dates_and_exact_pack():
    [offer] = _parse(_product(), _product())
    assert (offer.quantity, offer.unit, offer.catalogue_sku) == (700, "g", SKU)
    assert (offer.regular, offer.discount, offer.source_url) == (Decimal("1.99"), Decimal("1.59"), SOURCE)
    assert (offer.start, offer.end) == (TODAY, date(2026, 11, 18))
    assert _parse(_product(), today=TODAY - timedelta(days=1)) == []
    assert _parse(_product(), today=TODAY + timedelta(days=7)) == []


@pytest.mark.parametrize("change", ["loyalty", "recommended", "missing_regular", "different_region", "multipack"])
def test_scan_rejects_ambiguous_price_or_eligibility(change):
    product = _product()
    prices = product["regionsPrices"]["1"]
    if change == "loyalty":
        prices["currentLidlPlusPrice"] = {"price": 1.59}
    elif change == "recommended":
        prices["currentPrice"]["discount"]["fromRecommendedPrice"] = True
    elif change == "missing_regular":
        prices["currentPrice"].pop("oldPrice")
    elif change == "different_region":
        product["regionsV2"]["2"] = {"status": "ONLINE", "regionPriceId": "2"}
    else:
        product["multipack"] = True
    assert _parse(product) == []


def test_gb_offer_is_moderated_in_gbp_and_changes_only_the_matching_british_offer(market_price_db, monkeypatch):
    for module in (promotions, promotion_expiry, queue):
        monkeypatch.setattr(module, "market_today", lambda _: TODAY)

    async def fetch(skus):
        assert skus == {SKU}
        return _parse(_product())

    sources = queue.RETAILER_LEAFLETS
    monkeypatch.setitem(sources, ("GB", "Lidl"), replace(sources["GB", "Lidl"], fetch=fetch))
    product = Product(id=uuid4(), name="Avocados", unit="g", default_quantity=100)
    british_store = Store(id=uuid4(), name="Lidl", country_code="GB", currency_code="GBP")
    polish_store = Store(id=uuid4(), name="Lidl", country_code="PL", currency_code="PLN")
    market_price_db.add_all([product, british_store, polish_store])
    market_price_db.flush()
    british, polish = (
        StoreProduct(store_id=store.id, product_id=product.id, price=Decimal("1.99"),
                     retailer_sku=SKU, store_brand_name="", package_quantity=700, package_unit="g",
                     last_verified=TODAY)
        for store in (british_store, polish_store)
    )
    market_price_db.add_all([british, polish])
    market_price_db.commit()
    db = LocalDatabase(market_price_db)
    admin = SimpleNamespace(country_code="PL", role="admin")
    customer = SimpleNamespace(country_code="GB")

    async def scenario():
        first = await promotions._scan_and_queue_promotions("Lidl", db, country="GB")
        second = await promotions._scan_and_queue_promotions("Lidl", db, country="GB")
        assert first["queued_for_review"] == 1 and second["queued_for_review"] == 0
        [offer] = await promotions.list_pending_promotions(current_user=admin, db=db, market="GB")
        assert offer.promo_details["source_url"] == SOURCE
        assert await promotions.list_promotions(None, None, db=db, current_user=customer) == []
        with pytest.raises(HTTPException) as error:
            await promotions.approve_promotion(offer.id, current_user=admin, db=db, market="PL")
        assert error.value.status_code == 404
        approved = await promotions.approve_promotion(offer.id, current_user=admin, db=db, market="GB")
        assert PromotionResponse.model_validate(approved).currency_code == "GBP"
        assert british.price == Decimal("1.59") and polish.price == Decimal("1.99")
        assert await promotions.check_promotion("Avocado", "Lidl", db=db, current_user=customer) == [offer]
        assert await promotions.list_promotions(None, None, db=db, current_user=admin) == []
        monkeypatch.setattr(promotion_expiry, "market_today", lambda _: TODAY + timedelta(days=7))
        assert await promotion_expiry.restore_expired_promotion_prices(db) == 1
        assert british.price == polish.price == Decimal("1.99")

    asyncio.run(scenario())
