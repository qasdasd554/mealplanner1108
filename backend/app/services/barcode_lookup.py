"""Wyszukiwanie produktów po GTIN/EAN/UPC w kilku niezależnych bazach."""

from __future__ import annotations

import logging
import asyncio
import time

import httpx

from app.core.config import settings

OFF_API_URLS = (
    ("v2", "https://world.openfoodfacts.org/api/v2/product/{barcode}.json"),
    ("v3", "https://world.openfoodfacts.org/api/v3/product/{barcode}"),
)
USDA_SEARCH_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"
UPCITEMDB_LOOKUP_URL = "https://api.upcitemdb.com/prod/trial/lookup"
OFF_TEXT_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl"
USER_AGENT = "MealPlannerPolska/1.0 (https://github.com/qasdasd554/mealplanner1108)"

logger = logging.getLogger(__name__)
_TEXT_SEARCH_CACHE_TTL_SECONDS = 300
_TEXT_SEARCH_CACHE_MAX_ENTRIES = 200
_text_search_cache: dict[str, tuple[float, list["BarcodeLookupResult"]]] = {}


class BarcodeLookupResult:
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
        price_min: float,
        price_max: float,
        source: str,
        barcode: str | None = None,
    ) -> None:
        self.name = name
        self.brand = brand
        self.unit = unit
        self.kcal_per_100 = kcal_per_100
        self.protein_per_100 = protein_per_100
        self.fat_per_100 = fat_per_100
        self.carbs_per_100 = carbs_per_100
        self.price_min = price_min
        self.price_max = price_max
        self.source = source
        self.barcode = barcode


def _has_complete_nutrition(result: BarcodeLookupResult) -> bool:
    return all(value is not None for value in (
        result.kcal_per_100, result.protein_per_100,
        result.fat_per_100, result.carbs_per_100,
    ))


def _merge_lookup_results(
    primary: BarcodeLookupResult, supplementary: BarcodeLookupResult,
) -> BarcodeLookupResult:
    """Zachowuje polską nazwę z OFF, uzupełniając brakujące makro."""
    return BarcodeLookupResult(
        name=primary.name,
        brand=primary.brand or supplementary.brand,
        unit=primary.unit,
        kcal_per_100=primary.kcal_per_100 if primary.kcal_per_100 is not None
        else supplementary.kcal_per_100,
        protein_per_100=primary.protein_per_100 if primary.protein_per_100 is not None
        else supplementary.protein_per_100,
        fat_per_100=primary.fat_per_100 if primary.fat_per_100 is not None
        else supplementary.fat_per_100,
        carbs_per_100=primary.carbs_per_100 if primary.carbs_per_100 is not None
        else supplementary.carbs_per_100,
        price_min=primary.price_min,
        price_max=primary.price_max,
        source=primary.source,
        barcode=primary.barcode or supplementary.barcode,
    )


def normalize_barcode(value: str) -> str | None:
    """Usuwa formatowanie skanera i odrzuca wartości niebędące GTIN."""
    cleaned = value.strip()
    if (
        len(cleaned) >= 3
        and cleaned[0] == "]"
        and cleaned[1].isalpha()
        and cleaned[2].isdigit()
    ):
        cleaned = cleaned[3:]
    digits = "".join(char for char in cleaned if char.isdigit())
    return digits if 8 <= len(digits) <= 14 else None


def barcode_variants(barcode: str) -> tuple[str, ...]:
    """Równoważne zapisy GTIN (skanery różnie zwracają UPC-A/EAN-13)."""
    normalized = normalize_barcode(barcode)
    if normalized is None:
        return ()
    variants = [normalized]
    if len(normalized) in (12, 13):
        variants.append(normalized.zfill(14))
    if len(normalized) == 12:
        variants.append("0" + normalized)
    if len(normalized) in (13, 14) and normalized.startswith("0"):
        variants.append(normalized.lstrip("0"))
    return tuple(dict.fromkeys(value for value in variants if 8 <= len(value) <= 14))


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


def price_range_for_product(name: str, categories: object = None) -> tuple[float, float]:
    """Stałe, szerokie widełki detaliczne zamiast udawanej dokładnej ceny."""
    category_text = (
        " ".join(str(value) for value in categories)
        if isinstance(categories, list)
        else str(categories or "")
    )
    text = f"{name} {category_text}".lower()
    rules: tuple[tuple[tuple[str, ...], tuple[float, float]], ...] = (
        (("masło", "butter"), (6.0, 10.0)),
        (("jaj", "egg"), (8.0, 18.0)),
        (("mleko", "milk"), (3.0, 6.0)),
        (("jogurt", "yogurt"), (2.0, 7.0)),
        (("ser ", "sery", "sera", "twaróg", "cheese"), (5.0, 18.0)),
        (("pieczywo", "chleb", "bread", "bakery"), (3.0, 9.0)),
        (("ryba", "fish", "seafood", "salmon", "tuna"), (10.0, 40.0)),
        (("mięso", "meat", "poultry", "beef", "pork"), (10.0, 35.0)),
        (("makaron", "ryż", "mąka", "pasta", "rice", "flour", "cereal", "legume"), (3.0, 12.0)),
        (("oliwa", "olej", "oil", "vinegar"), (7.0, 30.0)),
        (("przypraw", "zioł", "spice", "seasoning", "herb"), (2.0, 10.0)),
        (("warzyw", "owoc", "vegetable", "fruit"), (2.0, 15.0)),
        (("sos", "ketchup", "mustard", "pesto", "condiment"), (3.0, 15.0)),
        (("napój", "sok", "drink", "soda", "juice"), (3.0, 12.0)),
    )
    for keywords, price_range in rules:
        if any(keyword in text for keyword in keywords):
            return price_range
    return (3.0, 25.0)


def _unit_from_product(product: dict) -> str:
    unit = str(product.get("product_quantity_unit") or "").lower()
    if unit in {"ml", "cl", "dl", "l"}:
        return "ml"
    if unit in {"piece", "pieces", "szt", "szt."}:
        return "szt"
    return "g"


def _product_from_off_response(data: object, api_version: str) -> dict | None:
    if not isinstance(data, dict) or not isinstance(data.get("product"), dict):
        return None
    if api_version == "v3":
        result = data.get("result") or {}
        found = (
            data.get("status") == "success"
            and isinstance(result, dict)
            and result.get("id") == "product_found"
        )
    else:
        found = str(data.get("status")) == "1"
    return data["product"] if found else None


def _result_from_off_product(product: dict) -> BarcodeLookupResult | None:
    name = next(
        (
            value.strip()
            for key in (
                "product_name_pl", "product_name", "abbreviated_product_name",
                "generic_name_pl", "generic_name",
            )
            if isinstance((value := product.get(key)), str) and value.strip()
        ),
        None,
    )
    if name is None:
        return None
    nutriments = product.get("nutriments") or {}
    kcal = _number(nutriments, "energy-kcal_100g", "energy-kcal")
    if kcal is None:
        energy_kj = _number(nutriments, "energy_100g", "energy")
        kcal = round(energy_kj / 4.184, 1) if energy_kj is not None else None
    raw_brands = product.get("brands")
    brand = (
        str(raw_brands[0]).strip()
        if isinstance(raw_brands, list) and raw_brands
        else str(raw_brands or "").split(",")[0].strip() or None
    )
    price_min, price_max = price_range_for_product(name, product.get("categories_tags"))
    return BarcodeLookupResult(
        name=name,
        brand=brand,
        unit=_unit_from_product(product),
        kcal_per_100=kcal,
        protein_per_100=_number(nutriments, "proteins_100g", "proteins"),
        fat_per_100=_number(nutriments, "fat_100g", "fat"),
        carbs_per_100=_number(nutriments, "carbohydrates_100g", "carbohydrates"),
        price_min=price_min,
        price_max=price_max,
        source="open_food_facts",
        barcode=normalize_barcode(str(product.get("code") or "")),
    )


async def search_products_external(
    query: str,
    *,
    limit: int = 10,
) -> list[BarcodeLookupResult]:
    """Wyszukuje produkty po nazwie w tej samej bazie co skaner kodów.

    Open Food Facts udostępnia pełnotekstowe wyszukiwanie przez starszy
    endpoint v1. Ograniczamy pola, liczbę wyników i czas odpowiedzi, żeby
    podpowiedzi w formularzu pozostały lekkie i nie blokowały ręcznego
    wpisywania nazwy przy chwilowej awarii zewnętrznej usługi.
    """
    normalized_query = " ".join(query.strip().split())
    if len(normalized_query) < 2:
        return []
    cache_key = f"{normalized_query.casefold()}\0{limit}"
    cached = _text_search_cache.get(cache_key)
    now = time.monotonic()
    if cached is not None and now - cached[0] < _TEXT_SEARCH_CACHE_TTL_SECONDS:
        return list(cached[1][:limit])

    fields = (
        "code,product_name_pl,product_name,generic_name_pl,generic_name,"
        "abbreviated_product_name,brands,nutriments,categories_tags,"
        "product_quantity,product_quantity_unit,serving_quantity"
    )
    params = {
        "search_terms": normalized_query,
        "search_simple": "1",
        "action": "process",
        "json": "1",
        "page": "1",
        "page_size": str(max(1, min(limit, 20))),
        "sort_by": "unique_scans_n",
        "fields": fields,
        "lc": "pl",
        "cc": "pl",
    }
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    try:
        async with httpx.AsyncClient(
            timeout=7.0,
            follow_redirects=True,
            headers=headers,
        ) as client:
            response = await client.get(OFF_TEXT_SEARCH_URL, params=params)
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, ValueError, TypeError) as exc:
        logger.warning("Open Food Facts text search failed for %r: %s", query, exc)
        return []

    results = _results_from_off_search_response(payload, limit=limit)
    if len(_text_search_cache) >= _TEXT_SEARCH_CACHE_MAX_ENTRIES:
        oldest_key = min(
            _text_search_cache,
            key=lambda key: _text_search_cache[key][0],
        )
        _text_search_cache.pop(oldest_key, None)
    _text_search_cache[cache_key] = (now, list(results))
    return results


def _results_from_off_search_response(
    payload: object,
    *,
    limit: int,
) -> list[BarcodeLookupResult]:
    """Waliduje i deduplikuje odpowiedź pełnotekstowego wyszukiwania."""
    if not isinstance(payload, dict) or not isinstance(payload.get("products"), list):
        return []

    results: list[BarcodeLookupResult] = []
    seen: set[tuple[str, str]] = set()
    for product in payload["products"]:
        if not isinstance(product, dict):
            continue
        result = _result_from_off_product(product)
        if result is None:
            continue
        key = (result.name.casefold(), (result.brand or "").casefold())
        if key in seen:
            continue
        seen.add(key)
        results.append(result)
        if len(results) >= limit:
            break
    return results


async def _fetch_off(client: httpx.AsyncClient, barcode: str) -> BarcodeLookupResult | None:
    params = {
        "cc": "pl", "lc": "pl",
        "fields": (
            "product_name_pl,product_name,generic_name_pl,generic_name,"
            "abbreviated_product_name,brands,nutriments,categories_tags,"
            "product_quantity,product_quantity_unit,serving_quantity"
        ),
    }
    # UPC-A jest czasem zapisany w OFF jako EAN-13 z początkowym zerem.
    # Nie pytamy o wszystkie zera GTIN-14: to mnożyłoby ruch bez wartości.
    candidates = [barcode]
    if len(barcode) == 12:
        candidates.append("0" + barcode)
    elif len(barcode) == 13 and barcode.startswith("0"):
        candidates.append(barcode[1:])
    for candidate in candidates:
        for api_version, template in OFF_API_URLS:
            try:
                response = await client.get(template.format(barcode=candidate), params=params)
                response.raise_for_status()
                payload = response.json()
            except httpx.HTTPStatusError as exc:
                # Brak w bazie jest normalny, nie wymaga drugiego żądania
                # do tej samej bazy przez inną wersję API.
                if exc.response.status_code == 404:
                    break
                logger.warning("Open Food Facts lookup failed for %s: %s", candidate, exc)
                continue
            except (httpx.HTTPError, ValueError, TypeError) as exc:
                logger.warning("Open Food Facts lookup failed for %s: %s", candidate, exc)
                continue
            product = _product_from_off_response(payload, api_version)
            if product is not None and (result := _result_from_off_product(product)):
                return result
            if (api_version == "v2" and isinstance(payload, dict) and
                    str(payload.get("status")) == "0") or (
                    api_version == "v3" and isinstance(payload, dict) and
                    isinstance(payload.get("result"), dict) and
                    payload["result"].get("id") == "product_not_found"):
                break
    return None


def _product_from_usda_response(data: object, barcode: str) -> BarcodeLookupResult | None:
    if not isinstance(data, dict) or not isinstance(data.get("foods"), list):
        return None
    normalized = barcode.lstrip("0")
    for food in data["foods"]:
        if not isinstance(food, dict):
            continue
        gtin = "".join(c for c in str(food.get("gtinUpc") or "") if c.isdigit())
        if gtin.lstrip("0") != normalized:
            continue
        name = str(food.get("description") or "").strip()
        if not name:
            continue
        nutrient_values: dict[int, float] = {}
        for nutrient in food.get("foodNutrients") or []:
            if not isinstance(nutrient, dict):
                continue
            try:
                nutrient_values[int(nutrient["nutrientId"])] = float(nutrient["value"])
            except (KeyError, TypeError, ValueError):
                continue
        price_min, price_max = price_range_for_product(name, food.get("brandedFoodCategory"))
        return BarcodeLookupResult(
            name=name,
            brand=str(food.get("brandName") or food.get("brandOwner") or "").strip() or None,
            unit="g",
            kcal_per_100=nutrient_values.get(1008),
            protein_per_100=nutrient_values.get(1003),
            fat_per_100=nutrient_values.get(1004),
            carbs_per_100=nutrient_values.get(1005),
            price_min=price_min, price_max=price_max,
            source="usda_fooddata_central",
        )
    return None


async def _fetch_usda(client: httpx.AsyncClient, barcode: str) -> BarcodeLookupResult | None:
    try:
        response = await client.post(
            USDA_SEARCH_URL,
            params={"api_key": settings.USDA_FDC_API_KEY},
            json={"query": barcode, "dataType": ["Branded"], "pageSize": 5},
        )
        response.raise_for_status()
        return _product_from_usda_response(response.json(), barcode)
    except (httpx.HTTPError, ValueError, TypeError) as exc:
        logger.warning("USDA FoodData Central lookup failed for %s: %s", barcode, exc)
        return None


def _product_from_upcitemdb_response(data: object, barcode: str) -> BarcodeLookupResult | None:
    if not isinstance(data, dict) or not isinstance(data.get("items"), list):
        return None
    normalized = barcode.lstrip("0")
    for item in data["items"]:
        if not isinstance(item, dict):
            continue
        codes = (item.get("ean"), item.get("upc"), item.get("gtin"))
        if not any(
            "".join(c for c in str(code or "") if c.isdigit()).lstrip("0") == normalized
            for code in codes
        ):
            continue
        name = str(item.get("title") or item.get("description") or "").strip()
        if not name:
            continue
        price_min, price_max = price_range_for_product(name, item.get("category"))
        return BarcodeLookupResult(
            name=name,
            brand=str(item.get("brand") or "").strip() or None,
            unit="g",
            kcal_per_100=None, protein_per_100=None, fat_per_100=None, carbs_per_100=None,
            price_min=price_min, price_max=price_max, source="upcitemdb",
        )
    return None


async def _fetch_upcitemdb(client: httpx.AsyncClient, barcode: str) -> BarcodeLookupResult | None:
    try:
        response = await client.get(UPCITEMDB_LOOKUP_URL, params={"upc": barcode})
        response.raise_for_status()
        return _product_from_upcitemdb_response(response.json(), barcode)
    except (httpx.HTTPError, ValueError, TypeError) as exc:
        logger.warning("UPCitemdb lookup failed for %s: %s", barcode, exc)
        return None


async def lookup_barcode_external(barcode: str) -> BarcodeLookupResult | None:
    """Zwraca pierwszy pełny wynik, bez czekania na wolniejsze bazy."""
    normalized = normalize_barcode(barcode)
    if normalized is None:
        return None
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
        tasks = [
            asyncio.create_task(provider(client, normalized))
            for provider in (_fetch_off, _fetch_usda, _fetch_upcitemdb)
        ]
        fallback: BarcodeLookupResult | None = None
        # Poprzednie 5 sekund często kończyło skan przed odpowiedzią OFF,
        # mimo że produkt tam istniał. Szybki pełny wynik nadal wraca od razu.
        deadline = asyncio.get_running_loop().time() + 8.0
        pending = set(tasks)
        try:
            while pending:
                remaining = deadline - asyncio.get_running_loop().time()
                if remaining <= 0:
                    break
                # UPCitemdb bez makro może przyjść pierwszy. Pozostałe
                # źródła mają krótką szansę zwrócić również makroskładniki.
                if fallback is not None:
                    remaining = min(remaining, 2.0)
                done, pending = await asyncio.wait(
                    pending, timeout=remaining, return_when=asyncio.FIRST_COMPLETED,
                )
                if not done:
                    break
                for task in done:
                    try:
                        result = task.result()
                    except Exception as exc:
                        logger.warning("Barcode provider failed for %s: %s", normalized, exc)
                        continue
                    if result is None:
                        continue
                    if fallback is not None:
                        if result.source == "open_food_facts":
                            fallback = _merge_lookup_results(result, fallback)
                        else:
                            fallback = _merge_lookup_results(fallback, result)
                        if _has_complete_nutrition(fallback):
                            return fallback
                    if _has_complete_nutrition(result):
                        return result
                    if fallback is None:
                        fallback = result
        finally:
            for task in tasks:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
        return fallback
    return None
