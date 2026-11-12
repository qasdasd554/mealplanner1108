"""Read documented GBP discounts from Lidl GB's current grocery campaign."""

import json
import re
from datetime import date, datetime, timedelta
from decimal import Decimal

from bs4 import BeautifulSoup

from app.core.market_clock import market_timezone, market_today
from app.services.retailer_leaflet import LeafletOffer, download_leaflet

LIDL_GB_HOME = "https://www.lidl.co.uk"


def _lidl_campaign_url(html: bytes) -> str:
    page = BeautifulSoup(html, "html.parser")
    paths = {
        link["href"] for link in page.select(".AHeroStage__Body-Current_Sales_Week a[href]")
        if re.fullmatch(r"/c/store/pick-of-the-week/a\d+", link["href"])
    }
    if len(paths) != 1:
        raise ValueError("Lidl GB current weekly campaign link is missing or ambiguous")
    return LIDL_GB_HOME + paths.pop()


def _lidl_offer(tile, today: date, catalogue_skus: set[str], source_url: str) -> LeafletOffer | None:
    data = json.loads(tile["data-grid-data"], parse_float=Decimal)
    if (data.get("store") is not True or data.get("productType") != "RETAIL"
            or any(data.get(flag) for flag in ("multipack", "flashSales", "ageRestriction", "preventSelling"))):
        return None
    region_prices = data["regionsPrices"]
    if len(region_prices) != 1:
        return None
    price_id, prices = next(iter(region_prices.items()))
    regions = data["regionsV2"]
    if not regions or any(
        region["regionPriceId"] != price_id or region["status"] != "ONLINE" for region in regions.values()
    ):
        return None
    if prices.get("currentLidlPlusPrice"):
        return None
    current = prices["currentPrice"]
    discount = current["discount"]
    if (current["currencyCode"] != "GBP" or current.get("hasStar") or current.get("variantsHaveDifferentPrices")
            or not discount.get("showDiscount") or any(discount.get(flag) for flag in (
                "fromRecommendedPrice", "fromNormalPriceForLidlPlus", "showFrom", "showUpTo", "discountHasStar",
            ))):
        return None
    regular, reduced = Decimal(current["oldPrice"]), Decimal(current["price"])
    if (not regular.is_finite() or not reduced.is_finite() or not 0 < reduced < regular <= 10_000
            or discount.get("deletedPrice") != regular
            or any(price != price.quantize(Decimal("0.01")) for price in (regular, reduced))):
        return None

    london = market_timezone("GB")
    store_start = datetime.fromtimestamp(data["storeStartDate"], tz=london).date()
    store_end = datetime.fromtimestamp(data["storeEndDate"], tz=london).date()
    price_start = datetime.fromisoformat(current["startDate"])
    price_end = datetime.fromisoformat(current["endDateExclusive"])
    if price_start.tzinfo is None or price_end.tzinfo is None:
        return None
    start = max(store_start, price_start.astimezone(london).date())
    end = min(store_end, (price_end - timedelta(microseconds=1)).astimezone(london).date())
    if not start <= today <= end <= start + timedelta(days=14):
        return None

    name = data["title"].strip()
    brand = (data.get("brand") or {}).get("name", "").strip().removeprefix("-").strip()
    pack = current["packaging"]["text"].strip()
    sku = str(data["productId"])
    if not 0 < len(name) <= 300 or not re.fullmatch(r"\d{5,12}", sku):
        return None
    if not re.fullmatch(rf"/p/[a-z0-9-]+/p{sku}", data["canonicalPath"]):
        return None
    measurement = re.fullmatch(r"(\d+(?:\.\d+)?)\s*(g|kg|ml|l)", pack, re.I)
    pieces = re.fullmatch(r"(\d+)\s*Pack", pack, re.I)
    if measurement:
        quantity, unit = Decimal(measurement[1]), measurement[2].lower()
    elif pieces or pack.casefold() == "each":
        quantity, unit = Decimal(pieces[1] if pieces else 1), "szt"
    else:
        return None
    if not 0 < quantity <= 10_000:
        return None
    return LeafletOffer(
        sku, sku if sku in catalogue_skus else None, name, brand, pack, quantity, unit,
        regular, reduced, start, end, source_url,
    )


def parse_lidl_gb_leaflet(
    html: bytes, *, today: date, catalogue_skus: set[str], source_url: str,
) -> list[LeafletOffer]:
    page = BeautifulSoup(html, "html.parser")
    tiles = page.select('main [data-grid-data][data-country="GB"][listname="Pick of the Week"]')
    if not tiles:
        raise ValueError("Lidl GB leaflet contains no grocery records")
    offers = {}
    ambiguous = set()
    for tile in tiles:
        if tile.get("category") not in {"Food", "F+V"}:
            continue
        try:
            offer = _lidl_offer(tile, today, catalogue_skus, source_url)
        except (KeyError, ValueError, TypeError, ArithmeticError, AttributeError, OSError):
            continue
        if offer is not None and offers.setdefault(offer.sku, offer) != offer:
            ambiguous.add(offer.sku)
    return [offer for sku, offer in offers.items() if sku not in ambiguous]


async def fetch_lidl_gb_promotions(catalogue_skus: set[str]) -> list[LeafletOffer]:
    url = _lidl_campaign_url(await download_leaflet(LIDL_GB_HOME + "/"))
    return parse_lidl_gb_leaflet(
        await download_leaflet(url), today=market_today("GB"), catalogue_skus=catalogue_skus, source_url=url,
    )
