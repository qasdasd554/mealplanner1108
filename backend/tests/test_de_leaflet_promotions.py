"""German leaflet evidence, moderation and exact-price restoration."""

import asyncio
import json
from datetime import date, timedelta
from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1 import promotions
from app.models import Product, Store, StoreProduct
from app.models.promotion import Promotion
from app.schemas.promotion import PromotionResponse
from app.services import de_promotion_queue, promotion_expiry
from app.services.de_leaflet_promotions import parse_aldi_nord_leaflet
from tests.test_market_prices_promotions import Database, market_price_db


def _offer(**overrides):
    return {
        "productSlug": "lachsfiletportion-18700000003",
        "brandName": "GOLDEN SEAFOOD",
        "name": "Lachsfiletportion",
        "salesUnit": "300-g-Packung",
        "isAvailable": True,
        "promotionPrices": [{
            "priceValue": 4.89, "strikePrice": {"strikePriceValue": 5.79},
            "priceTagLabels": {"promoText1": "-15 %"},
            "validFromLocalDate": "2026-11-09", "validUntilLocalDate": "2026-11-14",
        }],
        **overrides,
    }


def _parse(*items, today=date(2026, 11, 12)):
    payload = json.dumps({"props": {"pageProps": {"apiData": json.dumps([{"products": items}])}}})
    html = f'<script id="__NEXT_DATA__" type="application/json">{payload}</script>'
    return parse_aldi_nord_leaflet(html.encode(), today=today, catalogue_skus={"lachsfilet-1870"})


def test_leaflet_uses_published_dates_and_deduplicates():
    [offer] = _parse(_offer(), _offer())
    assert offer.catalogue_sku == "lachsfilet-1870"
    assert (offer.quantity, offer.unit) == (300, "g")
    assert (offer.regular, offer.discount) == (Decimal("5.79"), Decimal("4.89"))
    assert _parse(_offer(), today=date(2026, 11, 15)) == []
    assert _parse(_offer(), _offer(salesUnit="600-g-Packung")) == []


def test_rejects_unknown_products_and_conditional_or_reference_prices():
    coupon = _offer()
    coupon["promotionPrices"][0]["priceTagLabels"]["appOffer"] = True
    reference = _offer()
    reference["promotionPrices"][0]["strikePrice"]["strikePriceLabel"] = "UVP"
    assert _parse(coupon, reference, _offer(productSlug="unreviewed-promotion")) == []
    with pytest.raises(ValueError):
        parse_aldi_nord_leaflet(b"<html>Unexpected response</html>",
                               today=date(2026, 11, 12), catalogue_skus=set())


class LocalDatabase(Database):
    async def execute(self, statement):
        if "pg_advisory_xact_lock" in str(statement):
            return None
        return await super().execute(statement)


@pytest.mark.parametrize("pack, applied", [(300, True), (600, False)])
def test_german_moderation_is_scoped_and_only_updates_matching_packs(market_price_db, monkeypatch, pack, applied):
    today = date(2026, 11, 12)
    for module in (de_promotion_queue, promotion_expiry, promotions):
        monkeypatch.setattr(module, "market_today", lambda _: today)
    monkeypatch.setattr(de_promotion_queue, "fetch_aldi_nord_promotions", _fixture_leaflet)
    db = LocalDatabase(market_price_db)
    admin = SimpleNamespace(country_code="PL", role="admin")
    de_user = SimpleNamespace(country_code="DE")
    de = Store(id=uuid4(), name="ALDI Nord", country_code="DE", currency_code="EUR")
    pl = Store(id=uuid4(), name="ALDI Nord", country_code="PL", currency_code="PLN")
    product = Product(id=uuid4(), name="Lachsfilet", unit="g", default_quantity=100)
    offer = StoreProduct(id=uuid4(), store_id=de.id, product_id=product.id,
        price=Decimal("5.79"), package_quantity=pack, package_unit="g", last_verified=today,
        retailer_sku="lachsfilet-1870", store_brand_name="GOLDEN SEAFOOD")
    polish_offer = StoreProduct(id=uuid4(), store_id=pl.id, product_id=product.id,
                              price=Decimal("30.99"))
    market_price_db.add_all([de, pl, product, offer, polish_offer])
    market_price_db.commit()

    async def scenario():
        first = await promotions._scan_and_queue_promotions("ALDI Nord", db, country="DE")
        second = await promotions._scan_and_queue_promotions("ALDI Nord", db, country="DE")
        assert first["queued_for_review"] == 1 and second["queued_for_review"] == 0
        [row] = await promotions.list_pending_promotions(current_user=admin, db=db, market="DE")
        assert await promotions.list_promotions(None, None, db=db, current_user=de_user) == []
        with pytest.raises(HTTPException) as error:
            await promotions.approve_promotion(row.id, current_user=admin, db=db, market="PL")
        assert error.value.status_code == 404
        approved = await promotions.approve_promotion(row.id, current_user=admin, db=db, market="DE")
        assert PromotionResponse.model_validate(approved).currency_code == "EUR"
        assert approved.price_applied is applied
        assert offer.price == Decimal("4.89" if applied else "5.79")
        assert polish_offer.price == Decimal("30.99")
        assert await promotions.list_promotions(None, None, db=db, current_user=admin) == []
        assert await promotions.list_promotions(None, None, db=db, current_user=de_user) == [row]
        monkeypatch.setattr(promotion_expiry, "market_today", lambda _: today + timedelta(days=4))
        assert await promotion_expiry.restore_expired_promotion_prices(db) == int(applied)
        assert offer.price == Decimal("5.79")
        assert not row.price_applied
        assert len(market_price_db.scalars(select(Promotion)).all()) == 1

    asyncio.run(scenario())


async def _fixture_leaflet(skus):
    assert skus == {"lachsfilet-1870"}
    return _parse(_offer())
