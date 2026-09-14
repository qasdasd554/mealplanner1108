"""Wyszukiwanie produktu i orientacyjnej ceny po kodzie EAN/UPC.

Metadane i wartości odżywcze pobieramy z Open Food Facts. Cenę próbujemy
odczytać z Open Prices (wyłącznie obserwacje w PLN), a gdy dla danego kodu
nie ma polskiego wpisu, obliczamy jawnie orientacyjną cenę opakowania na
podstawie kategorii i gramatury. Brak zewnętrznego API nie blokuje aplikacji.
"""

from __future__ import annotations

import asyncio
import logging
from statistics import median

import httpx

OFF_API_URLS = (
    "https://world.openfoodfacts.org/api/v2/product/{barcode}.json",
    "https://pl.openfoodfacts.org/api/v2/product/{barcode}.json",
)
OPEN_PRICES_API_URL = "https://prices.openfoodfacts.org/api/v1/prices"
USER_AGENT = "MealPlannerPolska/1.0"

logger = logging.getLogger(__name__)


class BarcodeLookupResult:
    """Znormalizowany wynik z Open Food Facts i Open Prices."""

    def __init__(
        self,
        *,
        name: str,
        brand: str | None,
        unit: str,
        kcal_per_100: float | None,
        protein_per_100: float | None,
        fat_per_100: float | None,
        carbs_per_100: float | None,
        suggested_price: float | None,
        source: str,
    ) -> None:
        self.name = name
        self.brand = brand
        self.unit = unit
        self.kcal_per_100 = kcal_per_100
        self.protein_per_100 = protein_per_100
        self.fat_per_100 = fat_per_100
        self.carbs_per_100 = carbs_per_100
        self.suggested_price = suggested_price
        self.source = source


def normalize_barcode(value: str) -> str | None:
    """Usuwa formatowanie skanera i odrzuca wartości niebędące GTIN."""
    digits = "".join(char for char in value if char.isdigit())
    return digits if 8 <= len(digits) <= 14 else None


def _number(mapping: dict, *keys: str) -> float | None:
    for key in keys:
        value = mapping.get(key)
        if value is None:
            continue
        try:
            return float(value)
        except (TypeError, ValueError):
            continue
    return None


def _unit_from_product(product: dict) -> str:
    unit = str(product.get("product_quantity_unit") or "").lower()
    if unit in {"ml", "cl", "dl", "l"}:
        return "ml"
    if unit in {"piece", "pieces", "szt", "szt."}:
        return "szt"
    return "g"


def _quantity_in_base_unit(product: dict) -> float:
    """Zwraca gramaturę w kg/l do oszacowania ceny całego opakowania."""
    quantity = _number(product, "product_quantity", "serving_quantity")
    if quantity is None or quantity <= 0:
        return 0.5
    unit = str(product.get("product_quantity_unit") or "g").lower()
    if unit in {"kg", "l"}:
        return quantity
    if unit == "cl":
        return quantity / 100.0
    if unit == "dl":
        return quantity / 10.0
    if unit in {"g", "ml"}:
        return quantity / 1000.0
    return 0.5


def _estimate_price_pln(product: dict) -> float:
    """Konserwatywny szacunek ceny opakowania na podstawie kategorii."""
    tags = " ".join(str(tag).lower() for tag in product.get("categories_tags") or [])
    price_per_kg_or_litre = 20.0
    category_rates = (
        (("spice", "seasoning", "herb"), 160.0),
        (("fish", "seafood", "salmon", "tuna"), 48.0),
        (("meat", "poultry", "beef", "pork"), 32.0),
        (("cheese",), 38.0),
        (("chocolate", "cocoa"), 55.0),
        (("nuts", "seeds"), 45.0),
        (("oil", "vinegar"), 22.0),
        (("sauce", "condiment", "pesto"), 28.0),
        (("bread", "bakery"), 12.0),
        (("pasta", "rice", "cereal", "flour", "legume"), 13.0),
        (("milk", "yogurt", "dairy"), 10.0),
        (("fruit",), 10.0),
        (("vegetable",), 9.0),
    )
    for keywords, rate in category_rates:
        if any(keyword in tags for keyword in keywords):
            price_per_kg_or_litre = rate
            break

    estimate = price_per_kg_or_litre * _quantity_in_base_unit(product)
    return round(min(max(estimate, 1.49), 99.99), 2)


async def _fetch_off_product(client: httpx.AsyncClient, barcode: str) -> dict | None:
    params = {
        "cc": "pl",
        "lc": "pl",
        "fields": (
            "product_name_pl,product_name,generic_name_pl,generic_name,"
            "abbreviated_product_name,brands,nutriments,categories_tags,"
            "product_quantity,product_quantity_unit,serving_quantity"
        ),
    }
    for url_template in OFF_API_URLS:
        try:
            response = await client.get(url_template.format(barcode=barcode), params=params)
            response.raise_for_status()
            data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            logger.warning("Open Food Facts lookup failed for %s: %s", barcode, exc)
            continue

        if str(data.get("status")) == "1" and isinstance(data.get("product"), dict):
            return data["product"]
    return None


async def _fetch_polish_price(client: httpx.AsyncClient, barcode: str) -> float | None:
    try:
        response = await client.get(
            OPEN_PRICES_API_URL,
            params={"product_code": barcode, "currency": "PLN", "size": 50},
        )
        response.raise_for_status()
        items = response.json().get("items") or []
    except (httpx.HTTPError, ValueError, AttributeError) as exc:
        logger.warning("Open Prices lookup failed for %s: %s", barcode, exc)
        return None

    polish_prices: list[float] = []
    for item in items:
        location = item.get("location") or {}
        country = str(location.get("osm_address_country_code") or "").upper()
        if str(item.get("currency") or "").upper() != "PLN":
            continue
        if country and country != "PL":
            continue
        try:
            price = float(item["price"])
        except (KeyError, TypeError, ValueError):
            continue
        if 0.1 <= price <= 1000:
            polish_prices.append(price)

    if not polish_prices:
        return None
    return round(float(median(polish_prices[:10])), 2)


async def lookup_barcode_external(barcode: str) -> BarcodeLookupResult | None:
    """Pobiera nazwę, markę, makro i orientacyjną cenę dla kodu."""
    normalized = normalize_barcode(barcode)
    if normalized is None:
        return None

    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
            product, observed_price = await asyncio.gather(
                _fetch_off_product(client, normalized),
                _fetch_polish_price(client, normalized),
            )
    except httpx.HTTPError as exc:
        logger.warning("Barcode services unavailable for %s: %s", normalized, exc)
        return None

    if product is None:
        return None

    name = (
        product.get("product_name_pl")
        or product.get("product_name")
        or product.get("abbreviated_product_name")
        or product.get("generic_name_pl")
        or product.get("generic_name")
    )
    if not isinstance(name, str) or not name.strip():
        return None

    nutriments = product.get("nutriments") or {}
    kcal = _number(nutriments, "energy-kcal_100g", "energy-kcal")
    if kcal is None:
        energy_kj = _number(nutriments, "energy_100g", "energy")
        kcal = round(energy_kj / 4.184, 1) if energy_kj is not None else None

    brands = product.get("brands")
    if isinstance(brands, list):
        brand = str(brands[0]).strip() if brands else None
    else:
        brand = str(brands or "").split(",")[0].strip() or None

    return BarcodeLookupResult(
        name=name.strip(),
        brand=brand,
        unit=_unit_from_product(product),
        kcal_per_100=kcal,
        protein_per_100=_number(nutriments, "proteins_100g", "proteins"),
        fat_per_100=_number(nutriments, "fat_100g", "fat"),
        carbs_per_100=_number(nutriments, "carbohydrates_100g", "carbohydrates"),
        suggested_price=observed_price or _estimate_price_pln(product),
        source="open_food_facts",
    )
