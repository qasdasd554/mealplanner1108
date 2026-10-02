"""Wyszukiwanie produktów po GTIN/EAN/UPC w kilku niezależnych bazach."""

from __future__ import annotations

import logging
import asyncio
import time
import re
from difflib import SequenceMatcher

import httpx

from app.core.config import settings

# Jedno, stabilne API całej światowej bazy. Nie pytamy kolejno v2 i v3 o
# ten sam kod, ponieważ obie wersje korzystają z tych samych danych, a każde
# dodatkowe żądanie tylko zużywa limit Open Food Facts i wydłuża skan.
# Endpoint /api/v3.6 ma obecnie błąd projekcji pola `nutriments`: dla części
# produktów zwraca nazwę, markę i gramaturę, ale pusty słownik wartości
# odżywczych. /api/v3 zwraca dla tych samych kodów pełne makro.
OFF_API_URLS = (
    ("v3", "https://world.openfoodfacts.org/api/v3/product/{barcode}.json"),
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
        serving_quantity: float | None = None,
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
        self.serving_quantity = serving_quantity


def _has_complete_nutrition(result: BarcodeLookupResult) -> bool:
    values = (
        result.kcal_per_100, result.protein_per_100,
        result.fat_per_100, result.carbs_per_100,
    )
    # Stare rekordy i niektóre niepełne odpowiedzi zewnętrzne zapisują
    # brak makro jako cztery zera. Nie wolno uznać takiego zestawu za
    # kompletne dane, bo wtedy wynik trafia do Neon i blokuje USDA/OCR.
    return all(value is not None for value in values) and any(
        value > 0 for value in values if value is not None
    )


def _merge_lookup_results(
    primary: BarcodeLookupResult, supplementary: BarcodeLookupResult,
) -> BarcodeLookupResult:
    """Zachowuje polską nazwę z OFF, uzupełniając brakujące makro."""
    primary_nutrition = (
        primary.kcal_per_100,
        primary.protein_per_100,
        primary.fat_per_100,
        primary.carbs_per_100,
    )
    primary_has_placeholder_nutrition = all(
        value == 0 for value in primary_nutrition
    )

    def merge_nutrition(
        primary_value: float | None, supplementary_value: float | None,
    ) -> float | None:
        if primary_has_placeholder_nutrition:
            return supplementary_value
        return primary_value if primary_value is not None else supplementary_value

    return BarcodeLookupResult(
        name=primary.name,
        brand=primary.brand or supplementary.brand,
        unit=primary.unit,
        kcal_per_100=merge_nutrition(
            primary.kcal_per_100, supplementary.kcal_per_100,
        ),
        protein_per_100=merge_nutrition(
            primary.protein_per_100, supplementary.protein_per_100,
        ),
        fat_per_100=merge_nutrition(
            primary.fat_per_100, supplementary.fat_per_100,
        ),
        carbs_per_100=merge_nutrition(
            primary.carbs_per_100, supplementary.carbs_per_100,
        ),
        price_min=primary.price_min,
        price_max=primary.price_max,
        source=primary.source,
        barcode=primary.barcode or supplementary.barcode,
        # Wyszukiwanie po nazwie może trafić na inną gramaturę tego samego
        # produktu. Uzupełniamy nim makro, ale nigdy rozmiar opakowania.
        serving_quantity=primary.serving_quantity,
    )


def has_complete_nutrition(result: BarcodeLookupResult) -> bool:
    """Publiczny odpowiednik walidacji używany przez endpoint API."""
    return _has_complete_nutrition(result)


def merge_lookup_results(
    primary: BarcodeLookupResult,
    supplementary: BarcodeLookupResult,
) -> BarcodeLookupResult:
    """Publiczne, bezpieczne scalenie wyniku kodu z wynikiem po nazwie."""
    return _merge_lookup_results(primary, supplementary)


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
    if len(digits) not in {8, 12, 13, 14}:
        return None
    return digits if _has_valid_gtin_checksum(digits) else None


def _has_valid_gtin_checksum(code: str) -> bool:
    """Waliduje cyfrę kontrolną tak samo jak skaner mobilny.

    Chroni też wywołania API i importy omijające aparat przed tworzeniem
    rekordów dla przypadkowych, ale poprawnie wyglądających ciągów cyfr.
    """
    if not code.isdigit() or len(code) < 2:
        return False
    total = 0
    for index in range(len(code) - 2, -1, -1):
        distance = len(code) - 1 - index
        total += int(code[index]) * (3 if distance % 2 else 1)
    expected = (10 - total % 10) % 10
    return expected == int(code[-1])


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
    unit = str(
        product.get("product_quantity_unit")
        or product.get("serving_quantity_unit")
        or ""
    ).lower()
    if not unit:
        match = re.search(
            r"\b(kg|mg|g|ml|cl|dl|l)\b",
            str(product.get("quantity") or "").strip().lower(),
        )
        unit = match.group(1) if match else ""
    if unit in {"ml", "cl", "dl", "l"}:
        return "ml"
    if unit in {"piece", "pieces", "szt", "szt."}:
        return "szt"
    return "g"


def _quantity_in_base_unit(value: float, unit: object) -> float:
    normalized_unit = str(unit or "").strip().lower()
    if normalized_unit in {"kg", "l"}:
        return value * 1000
    if normalized_unit == "cl":
        return value * 10
    if normalized_unit == "dl":
        return value * 100
    if normalized_unit == "mg":
        return value / 1000
    return value


def _package_quantity_in_base_unit(product: dict) -> float | None:
    """Zwraca masę/objętość CAŁEGO produktu w g/ml.

    OFF rozróżnia pełne `product_quantity` i zalecaną porcję
    `serving_quantity`. Skaner dodaje jedno opakowanie, więc porcja jest
    wyłącznie zapasem, gdy pełnej gramatury naprawdę brakuje.
    """
    package_quantity = _number(product, "product_quantity")
    if package_quantity is not None and package_quantity > 0:
        return _quantity_in_base_unit(
            package_quantity, product.get("product_quantity_unit")
        )
    quantity_text = str(product.get("quantity") or "").strip().lower()
    if quantity_text:
        # Przykłady spotykane w OFF: "150 g", "1,5 l", "6 x 100 g".
        match = re.search(
            r"(?:(\d+(?:[.,]\d+)?)\s*[x×]\s*)?"
            r"(\d+(?:[.,]\d+)?)\s*(kg|mg|g|ml|cl|dl|l)\b",
            quantity_text,
        )
        if match:
            multiplier = float((match.group(1) or "1").replace(",", "."))
            amount = float(match.group(2).replace(",", "."))
            return multiplier * _quantity_in_base_unit(amount, match.group(3))
    # `serving_quantity` oznacza porcję, nie całe opakowanie.
    return None


def _product_from_off_response(data: object, api_version: str) -> dict | None:
    if not isinstance(data, dict) or not isinstance(data.get("product"), dict):
        return None
    if api_version == "v3":
        result = data.get("result") or {}
        found = (
            data.get("status") in {"success", "success_with_errors"}
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
                "product_name_pl", "product_name", "product_name_en",
                "abbreviated_product_name", "generic_name_pl", "generic_name",
                "generic_name_en",
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
        serving_quantity=_package_quantity_in_base_unit(product),
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
        "code,product_name_pl,product_name,product_name_en,"
        "generic_name_pl,generic_name,generic_name_en,"
        "abbreviated_product_name,brands,nutriments,categories_tags,"
        "quantity,product_quantity,product_quantity_unit,serving_quantity,"
        "serving_quantity_unit"
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


async def find_nutrition_by_name(
    name: str,
    brand: str | None = None,
) -> BarcodeLookupResult | None:
    """Uzupełnia makro przez wyszukiwanie internetowe po nazwie.

    Ta ścieżka uruchamia się tylko wtedy, gdy wyszukiwanie po kodzie dało
    nazwę, ale nie wartości odżywcze. Wymagamy bliskiego dopasowania nazwy
    (lub zgodnej marki), aby nie przypisać makro podobnego produktu.
    """
    clean_name = " ".join(name.strip().split())
    clean_brand = " ".join((brand or "").strip().split())
    if len(clean_name) < 2:
        return None
    query = " ".join(part for part in (clean_brand, clean_name) if part)
    results = await search_products_external(query, limit=10)
    if not results and clean_brand:
        results = await search_products_external(clean_name, limit=10)

    best: BarcodeLookupResult | None = None
    best_score = 0.0
    for candidate in results:
        if not _has_complete_nutrition(candidate):
            continue
        name_score = SequenceMatcher(
            None, clean_name.casefold(), candidate.name.casefold()
        ).ratio()
        brand_matches = bool(
            clean_brand
            and candidate.brand
            and clean_brand.casefold() in candidate.brand.casefold()
        )
        score = name_score + (0.2 if brand_matches else 0.0)
        if name_score >= 0.72 and score > best_score:
            best = candidate
            best_score = score
    return best


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
            "code,product_name_pl,product_name,product_name_en,"
            "generic_name_pl,generic_name,generic_name_en,"
            "abbreviated_product_name,brands,nutriments,categories_tags,"
            "quantity,product_quantity,product_quantity_unit,serving_quantity,"
            "serving_quantity_unit"
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
                if exc.response.status_code in (429, 503):
                    break
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
            barcode=normalize_barcode(gtin),
            serving_quantity=_number(food, "servingSize"),
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
    """OFF jest źródłem głównym, USDA uzupełnia braki bez opóźniania UI.

    Oba bezpłatne źródła startują współbieżnie. To celowe: ścisłe czekanie
    na timeout OFF przed uruchomieniem USDA dodawałoby kilka sekund przy
    każdym brakującym kodzie. Wynik OFF ma pierwszeństwo, a USDA służy jako
    zapas lub uzupełnienie makro.
    """
    normalized = normalize_barcode(barcode)
    if normalized is None:
        return None
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
        async def fetch_usda_after_off_head_start() -> BarcodeLookupResult | None:
            # Większość polskich trafień OFF zwraca się szybko. Krótki start
            # przewagi ogranicza zbędne zapytania USDA, ale 350 ms jest na
            # tyle małe, że przy wolnym/brakującym OFF użytkownik go nie odczuje.
            await asyncio.sleep(0.35)
            return await _fetch_usda(client, normalized)

        tasks = [
            asyncio.create_task(_fetch_off(client, normalized)),
            asyncio.create_task(fetch_usda_after_off_head_start()),
        ]
        fallback: BarcodeLookupResult | None = None
        # Pięć sekund to twardy budżet całego wyszukiwania zewnętrznego.
        # Cache Neon jest sprawdzany wcześniej i nie podlega temu limitowi.
        deadline = asyncio.get_running_loop().time() + 5.0
        pending = set(tasks)
        try:
            while pending:
                remaining = deadline - asyncio.get_running_loop().time()
                if remaining <= 0:
                    break
                # Częściowy wynik jednego źródła dostaje krótką szansę na
                # uzupełnienie makro przez drugie, bez czekania do deadline.
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
