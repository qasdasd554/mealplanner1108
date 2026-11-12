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
from app.services.de_leaflet_promotions import (
    ALDI_SUED_LEAFLET_URL,
    parse_aldi_nord_leaflet,
    parse_aldi_sued_leaflet,
)
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


_SUED_SKU = "000000000000211235"
_SUED_TILE = f"""
<div class="product-tile">
  <a class="product-tile__link" href="/produkt/norwegisches-lachsfilet-{_SUED_SKU}">
    <p class="product-tile__brandname">GOLDEN SEAFOOD</p>
    <p class="product-tile__name">Norwegisches Lachsfilet 300 g</p>
    <p class="product-tile__unit-of-measurement">300 g</p>
    <div class="base-price base-price--on-sale">
      <div class="base-price__discount-tag__wrapper">Spare 22 %</div>
      <ins class="base-price__discounted" aria-label="Reduzierter Preis: 4,49 €">4,49 €</ins>
      <span class="base-price__superscript">²</span>
      <span class="base-price__was-price"><del aria-label="Originalpreis: 5,79 €">5,79 €</del></span>
    </div>
  </a>
</div>
"""


def _parse_sued(*tiles, today=date(2026, 11, 12), dates="Mo., 09.11. – Sa., 14.11."):
    html = f"""
    <meta charset="utf-8">
    <main>
      <div class="base-rich-text"><p>Angebote der aktuellen Woche. {dates}</p></div>
      <div class="product-listing-viewer">
        <div class="product-grid">{''.join(tiles)}</div>
        <div class="product-listing-viewer__disclaimers">
          <p>² Bitte beachte, dass dieser Artikel nur in begrenzter Anzahl zur Verfügung stehen kann
          und daher zu bestimmten Zeiten der Aktion ausverkauft sein könnte.</p>
        </div>
      </div>
    </main>
    """
    return parse_aldi_sued_leaflet(html.encode(), today=today, catalogue_skus={_SUED_SKU})


def test_sued_reads_package_and_explicit_dates_even_at_new_year():
    [offer] = _parse_sued(_SUED_TILE, _SUED_TILE)
    assert offer.catalogue_sku == _SUED_SKU
    assert (offer.quantity, offer.unit, offer.regular, offer.discount) == (300, "g", Decimal("5.79"), Decimal("4.49"))
    assert (offer.start, offer.end) == (date(2026, 11, 9), date(2026, 11, 14))
    [new_year] = _parse_sued(_SUED_TILE, today=date(2027, 1, 1), dates="Mo., 28.12. – Sa., 02.01.")
    assert (new_year.start, new_year.end) == (date(2026, 12, 28), date(2027, 1, 2))
    assert _parse_sued(_SUED_TILE, today=date(2026, 11, 15)) == []
    assert _parse_sued(_SUED_TILE, dates="Di., 09.11. – Sa., 14.11.") == []


@pytest.mark.parametrize("original, replacement", [
    ("Spare 22 %", "Nur mit ALDI App"),
    ("Originalpreis:", "UVP:"),
    (">300 g</p>", ">pro kg</p>"),
    (">²</span>", ">¹</span>"),
])
def test_sued_rejects_unknown_conditions(original, replacement):
    assert _parse_sued(_SUED_TILE.replace(original, replacement)) == []


def test_sued_rejects_conflicting_prices_for_one_sku():
    assert _parse_sued(_SUED_TILE, _SUED_TILE.replace("4,49", "4,59")) == []


class LocalDatabase(Database):
    async def execute(self, statement):
        if "pg_advisory_xact_lock" in str(statement):
            return None
        return await super().execute(statement)


@pytest.mark.parametrize("pack, applied", [(300, True), (600, False)])
@pytest.mark.parametrize("store, sku, fetch_name, fetch, discount, source", [
    ("ALDI Nord", "lachsfilet-1870", "fetch_aldi_nord_promotions", lambda: _parse(_offer()), "4.89", "aldi_nord_leaflet"),
    ("ALDI SÜD", _SUED_SKU, "fetch_aldi_sued_promotions", lambda: _parse_sued(_SUED_TILE), "4.49", "aldi_sued_leaflet"),
])
def test_german_moderation_is_scoped_and_only_updates_matching_packs(
    market_price_db, monkeypatch, pack, applied, store, sku, fetch_name, fetch, discount, source,
):
    today = date(2026, 11, 12)
    for module in (de_promotion_queue, promotion_expiry, promotions):
        monkeypatch.setattr(module, "market_today", lambda _: today)

    async def leaflet(skus):
        assert skus == {sku}
        return fetch()

    monkeypatch.setattr(de_promotion_queue, fetch_name, leaflet)
    db = LocalDatabase(market_price_db)
    admin = SimpleNamespace(country_code="PL", role="admin")
    de_user = SimpleNamespace(country_code="DE")
    de = Store(id=uuid4(), name=store, country_code="DE", currency_code="EUR")
    pl = Store(id=uuid4(), name=store, country_code="PL", currency_code="PLN")
    product = Product(id=uuid4(), name="Lachsfilet", unit="g", default_quantity=100)
    offer = StoreProduct(id=uuid4(), store_id=de.id, product_id=product.id,
        price=Decimal("5.79"), package_quantity=pack, package_unit="g", last_verified=today,
        retailer_sku=sku, store_brand_name="GOLDEN SEAFOOD")
    polish_offer = StoreProduct(id=uuid4(), store_id=pl.id, product_id=product.id,
                              price=Decimal("30.99"))
    market_price_db.add_all([de, pl, product, offer, polish_offer])
    market_price_db.commit()

    async def scenario():
        first = await promotions._scan_and_queue_promotions(store, db, country="DE")
        second = await promotions._scan_and_queue_promotions(store, db, country="DE")
        assert first["queued_for_review"] == 1 and second["queued_for_review"] == 0
        [row] = await promotions.list_pending_promotions(current_user=admin, db=db, market="DE")
        assert row.source == source
        if store == "ALDI SÜD":
            assert row.promo_details["source_url"] == ALDI_SUED_LEAFLET_URL
        assert await promotions.list_promotions(None, None, db=db, current_user=de_user) == []
        with pytest.raises(HTTPException) as error:
            await promotions.approve_promotion(row.id, current_user=admin, db=db, market="PL")
        assert error.value.status_code == 404
        approved = await promotions.approve_promotion(row.id, current_user=admin, db=db, market="DE")
        assert PromotionResponse.model_validate(approved).currency_code == "EUR"
        assert approved.price_applied is applied
        assert offer.price == Decimal(discount if applied else "5.79")
        assert polish_offer.price == Decimal("30.99")
        assert await promotions.list_promotions(None, None, db=db, current_user=admin) == []
        assert await promotions.list_promotions(None, None, db=db, current_user=de_user) == [row]
        monkeypatch.setattr(promotion_expiry, "market_today", lambda _: today + timedelta(days=4))
        assert await promotion_expiry.restore_expired_promotion_prices(db) == int(applied)
        assert offer.price == Decimal("5.79")
        assert not row.price_applied
        assert len(market_price_db.scalars(select(Promotion)).all()) == 1

    asyncio.run(scenario())
