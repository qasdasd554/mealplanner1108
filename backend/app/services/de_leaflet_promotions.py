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
ALDI_SUED_LEAFLET_URL = (
    "https://www.aldi-sued.de/produkte/wochenangebote/frischeprodukte-im-angebot/k/1588161427299187"
)
DE_LEAFLET_SOURCES = {
    "ALDI Nord": ("aldi_nord_leaflet", ALDI_NORD_LEAFLET_URL),
    "ALDI SÜD": ("aldi_sued_leaflet", ALDI_SUED_LEAFLET_URL),
}
DE_PROMOTION_STORES = tuple(DE_LEAFLET_SOURCES)

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


_WEEKDAYS = ("Mo", "Di", "Mi", "Do", "Fr", "Sa", "So")
_SUED_WEEK = re.compile(
    r"Angebote der aktuellen Woche\. (\w{2})\., (\d{2})\.(\d{2})\. [–-] (\w{2})\., (\d{2})\.(\d{2})\."
)
_SUED_LIMITED_STOCK = (
    "² Bitte beachte, dass dieser Artikel nur in begrenzter Anzahl zur Verfügung stehen kann "
    "und daher zu bestimmten Zeiten der Aktion ausverkauft sein könnte."
)


def _aldi_sued_current_week(label: str, today: date) -> tuple[date, date] | None:
    match = _SUED_WEEK.fullmatch(label)
    if match is None:
        return None
    for year in (today.year - 1, today.year):
        try:
            start = date(year, int(match[3]), int(match[2]))
            end = date(year + (int(match[6]) < start.month), int(match[6]), int(match[5]))
        except ValueError:
            continue
        if (start <= today <= end <= start + timedelta(days=6)
                and _WEEKDAYS[start.weekday()] == match[1] and _WEEKDAYS[end.weekday()] == match[4]):
            return start, end
    return None


def _aldi_sued_offer(tile, window: tuple[date, date], catalogue_skus: set[str], footnotes: set[str]):
    name = tile.select_one(".product-tile__name")
    brand = tile.select_one(".product-tile__brandname")
    pack = tile.select_one(".product-tile__unit-of-measurement")
    link = tile.select_one("a.product-tile__link[href]")
    prices = tile.select(".base-price")
    if name is None or pack is None or link is None or len(prices) != 1:
        return None
    sku_match = re.fullmatch(r"/produkt/[a-z0-9-]+-(\d{18})", link["href"])
    amount_match = re.fullmatch(r"(\d+(?:,\d+)?)\s*(g|kg|ml|l)", pack.get_text(strip=True), re.I)
    if sku_match is None or amount_match is None:
        return None

    price = prices[0]
    discounted = price.select("ins.base-price__discounted")
    original = price.select(".base-price__was-price del")
    tags = price.select(".base-price__discount-tag__wrapper")
    markers = price.select(".base-price__superscript")
    if ("base-price--on-sale" not in price.get("class", ()) or len(discounted) != 1 or len(original) != 1
            or len(tags) != 1 or not re.fullmatch(r"(?:|Spare \d{1,2} %)", tags[0].get_text(" ", strip=True))
            or len(markers) != 1 or markers[0].get_text(strip=True) != "²"
            or footnotes != {_SUED_LIMITED_STOCK}):
        return None

    discount, regular = (
        re.fullmatch(r"(\d{1,5},\d{2})\s*€", element.get_text(strip=True))
        for element in (discounted[0], original[0])
    )
    if (discount is None or regular is None
            or discounted[0].get("aria-label") != f"Reduzierter Preis: {discounted[0].get_text(strip=True)}"
            or original[0].get("aria-label") != f"Originalpreis: {original[0].get_text(strip=True)}"):
        return None
    discount_price = Decimal(discount[1].replace(",", "."))
    regular_price = Decimal(regular[1].replace(",", "."))
    quantity = Decimal(amount_match[1].replace(",", "."))
    title = name.get_text(" ", strip=True)
    if not (0 < discount_price < regular_price <= 10_000 and 0 < quantity and 0 < len(title) <= 300):
        return None
    sku = sku_match[1]
    return LeafletOffer(
        sku, sku if sku in catalogue_skus else None, title, brand.get_text(" ", strip=True) if brand else "",
        pack.get_text(" ", strip=True), quantity, amount_match[2].lower(), regular_price, discount_price, *window,
    )


def parse_aldi_sued_leaflet(html: bytes, *, today: date, catalogue_skus: set[str]) -> list[LeafletOffer]:
    page = BeautifulSoup(html, "html.parser")
    viewers = page.select("main .product-listing-viewer")
    dates = [p.get_text(" ", strip=True) for p in page.select("main .base-rich-text p")
             if p.get_text(strip=True).startswith("Angebote der aktuellen Woche.")]
    if len(viewers) != 1 or len(dates) != 1 or not _SUED_WEEK.fullmatch(dates[0]):
        raise ValueError("ALDI SÜD fresh offers or published dates are missing")
    window = _aldi_sued_current_week(dates[0], today)
    if window is None:
        return []
    viewer = viewers[0]
    footnotes = {" ".join(p.get_text(" ", strip=True).split())
                 for p in viewer.select(".product-listing-viewer__disclaimers p")}
    tiles = viewer.select(".product-grid .product-tile")
    if not tiles:
        raise ValueError("ALDI SÜD leaflet contains no product records")
    offers = {}
    ambiguous = set()
    for tile in tiles:
        offer = _aldi_sued_offer(tile, window, catalogue_skus, footnotes)
        if offer is not None and offers.setdefault(offer.sku, offer) != offer:
            ambiguous.add(offer.sku)
    return [offer for sku, offer in offers.items() if sku not in ambiguous]


async def _download_leaflet(url: str) -> bytes:
    html = bytearray()
    async with httpx.AsyncClient(timeout=15) as client:
        async with client.stream("GET", url) as response:
            response.raise_for_status()
            async for chunk in response.aiter_bytes():
                html.extend(chunk)
                if len(html) > 4_000_000:
                    raise ValueError("Retailer leaflet exceeds the expected size")
    return bytes(html)


async def fetch_aldi_nord_promotions(catalogue_skus: set[str]) -> list[LeafletOffer]:
    html = await _download_leaflet(ALDI_NORD_LEAFLET_URL)
    return parse_aldi_nord_leaflet(html, today=market_today("DE"), catalogue_skus=catalogue_skus)


async def fetch_aldi_sued_promotions(catalogue_skus: set[str]) -> list[LeafletOffer]:
    html = await _download_leaflet(ALDI_SUED_LEAFLET_URL)
    return parse_aldi_sued_leaflet(html, today=market_today("DE"), catalogue_skus=catalogue_skus)
