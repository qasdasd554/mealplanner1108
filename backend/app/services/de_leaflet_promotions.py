"""Read supported groceries from the retailer's published weekly offers."""

import json
import re
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

import httpx
from bs4 import BeautifulSoup

from app.core.market_clock import market_today

ALDI_NORD_LEAFLET_URL = "https://www.aldi-nord.de/angebote.html"
DE_PROMOTION_STORES = ("ALDI Nord",)

# Retailer leaflet variants can have a different identifier from the
# same product in the regular catalogue. Only reviewed pairs may set a price.
_CATALOGUE_SKUS = {"lachsfiletportion-18700000003": "lachsfilet-1870"}
_LEAFLET_FOODS = {
    "orangen-6143", "knollensellerie-6207", "wirsingkohl-6213",
    "zitronen-6219", "clementinen-6222", "bananen-fairtrade-6307",
    "gurke-7024", "cherrydatteltomaten-1005532", "kakis-1007112",
    "speisemoehren-1029249", "lachsfiletportion-18700000003",
}


@dataclass(frozen=True)
class LeafletOffer:
    sku: str
    catalogue_sku: str | None
    name: str
    brand: str
    pack: str
    quantity: Decimal | None
    unit: str | None
    regular: Decimal
    discount: Decimal
    start: date
    end: date


def _package(label: str) -> tuple[Decimal | None, str | None]:
    if label == "Stück":
        return Decimal(1), "szt"
    match = re.fullmatch(r"([0-9.,]+)-(g|kg|ml|L)-[A-Za-zÄÖÜäöüß]+", label)
    if match is None:
        return None, None
    amount = Decimal(match[1].replace(".", "").replace(",", "."))
    return amount, match[2].lower()


def _unconditional_price_cut(promo: dict) -> tuple[Decimal, Decimal] | None:
    strike = promo.get("strikePrice") or {}
    tags = promo.get("priceTagLabels") or {}
    # Compare with the retailer's own previous price, not a manufacturer's
    # recommended price. Skip bundles, app coupons and unknown price labels.
    if (strike.get("strikePriceLabel") or set(tags) - {"promoText1", "additionalPromoTileText1"}
            or not re.fullmatch(r"-\d{1,2}\s*%", tags.get("promoText1", ""))
            or not re.fullmatch(r"(?:|XXL|Preis-Highlight|\d+(?:,\d+)?\s*kg)", tags.get("additionalPromoTileText1", ""))):
        return None
    regular = Decimal(str(strike.get("strikePriceValue")))
    discount = Decimal(str(promo.get("priceValue")))
    if (regular.is_finite() and discount.is_finite() and 0 < discount < regular <= 10_000
            and all(price == price.quantize(Decimal("0.01")) for price in (regular, discount))):
        return regular, discount
    return None


def _parse_offer(row: dict, today: date, catalogue_skus: set[str]):
    sku = row.get("productSlug")
    catalogue_sku = _CATALOGUE_SKUS.get(sku, sku)
    if sku not in _LEAFLET_FOODS and catalogue_sku not in catalogue_skus:
        return
    if row.get("isAvailable") is not True or any(row.get(flag) for flag in (
        "isRecall", "isComingSoon", "isDepositProduct", "isBiocidalProduct",
    )):
        return
    if any(entry.get("type") not in {"footnote1", "footnote2"} or entry.get("legalText") != "true"
           for entry in row.get("legalInformation", [])):
        return
    pack = row.get("salesUnit")
    name = row.get("name")
    if not isinstance(name, str) or not 0 < len(name.strip()) <= 300 or not isinstance(pack, str):
        return
    quantity, unit = _package(pack)
    if not (quantity and quantity > 0) and pack != "kg-Preis":
        return
    for promo in row.get("promotionPrices", []):
        prices = _unconditional_price_cut(promo)
        if prices is None:
            continue
        start = date.fromisoformat(promo["validFromLocalDate"])
        end = date.fromisoformat(promo["validUntilLocalDate"])
        if start <= today <= end <= start + timedelta(days=14):
            yield LeafletOffer(
                sku, catalogue_sku if catalogue_sku in catalogue_skus else None,
                name.strip(), str(row.get("brandName") or "").strip(), pack,
                quantity, unit, *prices, start, end,
            )


def parse_aldi_nord_leaflet(html: bytes, *, today: date, catalogue_skus: set[str]) -> list[LeafletOffer]:
    script = BeautifulSoup(html, "html.parser").find("script", id="__NEXT_DATA__")
    if script is None or script.string is None:
        raise ValueError("ALDI Nord leaflet data is missing")
    try:
        data = json.loads(json.loads(script.string)["props"]["pageProps"]["apiData"])
    except (ValueError, TypeError, KeyError) as exc:
        raise ValueError("ALDI Nord leaflet data format has changed") from exc
    offers = {}
    ambiguous = set()
    records = 0
    stack = [data]
    while stack:
        value = stack.pop()
        if isinstance(value, list):
            stack.extend(value)
        elif isinstance(value, dict) and "productSlug" not in value:
            stack.extend(value.values())
        elif isinstance(value, dict):
            records += 1
            try:
                for offer in _parse_offer(value, today, catalogue_skus):
                    old = offers.setdefault(offer.sku, offer)
                    if old != offer:
                        ambiguous.add(offer.sku)
            except (ValueError, TypeError, ArithmeticError, AttributeError, KeyError):
                continue
    if not records:
        raise ValueError("ALDI Nord leaflet contains no product records")
    return [offer for sku, offer in offers.items() if sku not in ambiguous]


async def fetch_aldi_nord_promotions(catalogue_skus: set[str]) -> list[LeafletOffer]:
    html = bytearray()
    async with httpx.AsyncClient(timeout=15) as client:
        async with client.stream("GET", ALDI_NORD_LEAFLET_URL) as response:
            response.raise_for_status()
            async for chunk in response.aiter_bytes():
                html.extend(chunk)
                if len(html) > 4_000_000:
                    raise ValueError("ALDI Nord leaflet exceeds the expected size")
    return parse_aldi_nord_leaflet(bytes(html), today=market_today("DE"), catalogue_skus=catalogue_skus)
