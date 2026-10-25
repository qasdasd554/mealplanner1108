"""Wyszukiwanie produktów po GTIN/EAN/UPC w kilku niezależnych bazach."""

from __future__ import annotations

import logging
import math
import asyncio
import time
import re
import json
from datetime import datetime, timezone

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
EXPLICIT_NUTRITION_SOURCES = frozenset({
    "open_food_facts", "usda_fooddata_central", "product_label_ai", "product_label_ai_confirmed",
})
_TEXT_SEARCH_CACHE_TTL_SECONDS = 300
_TEXT_SEARCH_CACHE_MAX_ENTRIES = 200
_text_search_cache: dict[str, tuple[float, list["BarcodeLookupResult"]]] = {}
_text_search_unavailable_until = 0.0


def _off_locale(country_code: str = "PL") -> tuple[str, str]:
    """OFF uses UK rather than ISO GB; context is not stock availability."""
    return ("uk", "en") if country_code == "GB" else ("pl", "pl")


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
        off_product: dict | None = None,
        off_retrieved_at: str | None = None,
        off_search_projection: bool = False,
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
        self.off_product = off_product
        # Keep this JSON-safe: some background jobs serialize __dict__.
        # Cached results must retain the time of this exact OFF snapshot,
        # not the later time when a user receives it from memory cache.
        self.off_retrieved_at = None
        self.off_search_projection = off_search_projection
        if isinstance(off_product, dict):
            if off_retrieved_at is None:
                fetched_at = datetime.now(timezone.utc)
            else:
                if not isinstance(off_retrieved_at, str):
                    raise ValueError("OFF retrieval time must be a timezone-aware ISO8601 string")
                fetched_at = datetime.fromisoformat(off_retrieved_at)
                if fetched_at.tzinfo is None:
                    raise ValueError("OFF retrieval time must include a timezone")
            self.off_retrieved_at = fetched_at.astimezone(timezone.utc).isoformat()


def _has_complete_nutrition(result: BarcodeLookupResult) -> bool:
    values = (
        result.kcal_per_100, result.protein_per_100,
        result.fat_per_100, result.carbs_per_100,
    )
    # Stare rekordy i niektóre niepełne odpowiedzi zewnętrzne zapisują
    # brak makro jako cztery zera. Nie wolno uznać takiego zestawu za
    # kompletne dane, bo wtedy wynik trafia do Neon i blokuje USDA/OCR.
    known_values = all(
        value is not None and math.isfinite(value) and value >= 0 for value in values
    )
    # Exact external responses have explicit missing fields (None), so four
    # real zeros are valid for e.g. water. Legacy caches lack that provenance.
    explicit_source = result.source in EXPLICIT_NUTRITION_SOURCES
    return known_values and (explicit_source or any(value > 0 for value in values))


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
    primary_has_placeholder_nutrition = not _has_complete_nutrition(primary) and all(
        value == 0 for value in primary_nutrition
    )

    def merge_nutrition(
        primary_value: float | None, supplementary_value: float | None,
    ) -> float | None:
        if primary_has_placeholder_nutrition:
            return supplementary_value
        return primary_value if primary_value is not None else supplementary_value

    off_source = primary if primary.off_product else (
        supplementary
        if (supplementary.off_product and primary.barcode
            and supplementary.barcode in barcode_variants(primary.barcode))
        else None
    )
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
        off_product=off_source.off_product if off_source is not None else None,
        off_retrieved_at=off_source.off_retrieved_at if off_source is not None else None,
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
    # Remove only GTIN padding, never the meaningful first digit of UPC-A.
    for length in (14, 13, 12, 8):
        if len(normalized) > length and set(normalized[:-length]) == {"0"}:
            variants.append(normalized[-length:])
    return tuple(dict.fromkeys(value for value in variants if 8 <= len(value) <= 14))


def _number(mapping: dict, *keys: str) -> float | None:
    for key in keys:
        value = mapping.get(key)
        if value is None or isinstance(value, bool):
            continue
        try:
            number = float(value)
            if math.isfinite(number) and number >= 0:
                return number
        except (TypeError, ValueError, OverflowError):
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


_METRIC_PACKAGE_QUANTITY = re.compile(
    r"(?<![\w.,+\-−])(?:([+\-−]?\d+(?:[.,]\d+)?)\s*[x×]\s*)?"
    r"([+\-−]?\d+(?:[.,]\d+)?)\s*(kg|mg|g|ml|cl|dl|l)\b"
)


def _unit_from_product(product: dict) -> str:
    package = _metric_package_info(product)
    if package is not None:
        return package[1]
    unit = str(product.get("product_quantity_unit") or "").strip().lower()
    if unit not in {"g", "kg", "mg", "ml", "cl", "dl", "l"}:
        # Choose the same metric label segment as the whole-pack parser.
        # An ounce label may contain a reliable ml equivalent; a serving's
        # g unit must not turn that whole-pack volume into grams.
        match = _METRIC_PACKAGE_QUANTITY.search(
            str(product.get("quantity") or "").strip().lower()
        )
        if match:
            unit = match.group(3)
        elif not unit:
            unit = str(product.get("serving_quantity_unit") or "").strip().lower()
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


def _bounded_package_quantity(value: float) -> float | None:
    """Match the confirmed-label limit, after every metric conversion."""
    return value if math.isfinite(value) and 0 < value <= 100_000 else None


def _metric_package_info(product: dict) -> tuple[float, str] | None:
    """Zwraca masę/objętość CAŁEGO produktu w g/ml.

    OFF rozróżnia pełne `product_quantity` i zalecaną porcję
    `serving_quantity`. Skaner dodaje jedno opakowanie, dlatego porcji nigdy
    nie używamy jako zastępczej masy całego produktu.
    """
    quantity_text = str(product.get("quantity") or "").strip().lower()
    # OFF's numeric quantity may be a parser's upper endpoint, not the
    # measured weight of this variable package (e.g. cucumber "300/350g").
    # Keep per-100 nutrition, but do not offer an invented fixed package.
    if re.search(r"\d+(?:[.,]\d+)?\s*(?:kg|mg|g|ml|cl|dl|l)?\s*"
            r"(?:[-–—/]|\bto\b)\s*\d+(?:[.,]\d+)?\s*(?:kg|mg|g|ml|cl|dl|l)\b",
            quantity_text):
        return None
    package_quantity = _number(product, "product_quantity")
    package_unit = str(product.get("product_quantity_unit") or "").strip().lower()
    if package_quantity is not None and package_quantity > 0 and package_unit in {"g", "kg", "mg", "ml", "cl", "dl", "l"}:
        converted = _quantity_in_base_unit(
            package_quantity, product.get("product_quantity_unit")
        )
        if _bounded_package_quantity(converted) is not None:
            return converted, "ml" if package_unit in {"ml", "cl", "dl", "l"} else "g"
    if quantity_text:
        # Przykłady spotykane w OFF: "150 g", "1,5 l", "6 x 100 g".
        match = _METRIC_PACKAGE_QUANTITY.search(quantity_text)
        if match:
            multiplier = float((match.group(1) or "1").replace(",", ".").replace("−", "-"))
            amount = float(match.group(2).replace(",", ".").replace("−", "-"))
            if not all(math.isfinite(value) and value > 0 for value in (multiplier, amount)):
                return None
            converted = _bounded_package_quantity(multiplier * _quantity_in_base_unit(amount, match.group(3)))
            if converted is not None:
                return converted, "ml" if match.group(3) in {"ml", "cl", "dl", "l"} else "g"
    # `serving_quantity` oznacza porcję, nie całe opakowanie.
    return None


def _package_quantity_in_base_unit(product: dict) -> float | None:
    package = _metric_package_info(product)
    return package[0] if package is not None else None


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


def _result_from_off_product(
    product: dict, *, country_code: str = "PL",
) -> BarcodeLookupResult | None:
    name_fields = (
        (
            "product_name_en", "product_name",
            "abbreviated_product_name", "generic_name_en", "generic_name",
            "product_name_pl", "generic_name_pl",
        )
        if country_code == "GB"
        else (
            "product_name_pl", "product_name", "product_name_en",
            "abbreviated_product_name", "generic_name_pl", "generic_name",
            "generic_name_en",
        )
    )
    name = next(
        (
            value.strip()
            for key in name_fields
            if isinstance((value := product.get(key)), str) and value.strip()
        ),
        None,
    )
    if name is None:
        return None
    nutriments = product.get("nutriments") or {}
    if not isinstance(nutriments, dict):
        nutriments = {}
    # Raw keys describe the label's basis, which may be a single serving.
    # Only explicit per-100 values are safe without a confirmed label basis.
    raw_basis = re.sub(r"\s+", "", str(product.get("nutrition_data_per") or "").lower())
    raw_per_100 = raw_basis in {"100g", "100ml"}

    def nutrient(per_100_key: str, raw_key: str) -> float | None:
        return _number(nutriments, per_100_key, *([raw_key] if raw_per_100 else []))

    kcal = nutrient("energy-kcal_100g", "energy-kcal")
    if kcal is None:
        energy_kj = _number(
            nutriments, "energy-kj_100g", "energy_100g",
            *(["energy-kj", "energy"] if raw_per_100 else []),
        )
        kcal = round(energy_kj / 4.184, 1) if energy_kj is not None else None
    raw_brands = product.get("brands")
    brand = (
        str(raw_brands[0]).strip()
        if isinstance(raw_brands, list) and raw_brands
        else str(raw_brands or "").split(",")[0].strip() or None
    )
    price_min, price_max = price_range_for_product(name, product.get("categories_tags"))
    off_product = None
    if country_code == "GB":
        # Invalid provider JSON must not reintroduce NaN/Infinity through the
        # optional source record after nutrition/pack values were sanitised.
        try:
            json.dumps(product, allow_nan=False)
            off_product = product
        except (TypeError, ValueError, OverflowError):
            pass
    return BarcodeLookupResult(
        name=name,
        brand=brand,
        unit=_unit_from_product(product),
        kcal_per_100=kcal,
        protein_per_100=nutrient("proteins_100g", "proteins"),
        fat_per_100=nutrient("fat_100g", "fat"),
        carbs_per_100=nutrient("carbohydrates_100g", "carbohydrates"),
        price_min=price_min,
        price_max=price_max,
        source="open_food_facts",
        barcode=normalize_barcode(str(product.get("code") or "")),
        serving_quantity=_package_quantity_in_base_unit(product),
        off_product=off_product,
    )


async def search_products_external(
    query: str,
    *,
    limit: int = 10,
    country_code: str = "PL",
) -> list[BarcodeLookupResult]:
    """Wyszukuje produkty po nazwie w tej samej bazie co skaner kodów.

    PL zachowuje starszy endpoint v1. UK używa oficjalnego Search-a-licious;
    jego projekcje nie udają pełnego, aktualnego odczytu kodu produktu.
    Ograniczamy pola, liczbę wyników i czas odpowiedzi, żeby
    podpowiedzi w formularzu pozostały lekkie i nie blokowały ręcznego
    wpisywania nazwy przy chwilowej awarii zewnętrznej usługi.
    """
    global _text_search_unavailable_until
    normalized_query = " ".join(query.strip().split())
    if len(normalized_query) < 2:
        return []
    cc, lc = _off_locale(country_code)
    cache_key = f"{cc}\0{lc}\0{normalized_query.casefold()}\0{limit}"
    cached = _text_search_cache.get(cache_key)
    now = time.monotonic()
    cache_ttl = 30 if country_code == "GB" and cached is not None and not cached[1] else _TEXT_SEARCH_CACHE_TTL_SECONDS
    if cached is not None and now - cached[0] < cache_ttl:
        return list(cached[1][:limit])

    if country_code == "GB":
        from app.services.uk_off_search import search_uk_index

        results = await search_uk_index(normalized_query, limit=limit)
        if len(_text_search_cache) >= _TEXT_SEARCH_CACHE_MAX_ENTRIES:
            _text_search_cache.pop(min(_text_search_cache, key=lambda key: _text_search_cache[key][0]), None)
        _text_search_cache[cache_key] = (now, list(results))
        return results

    # A provider outage affects all ingredient names. Do not send another
    # request for each missing ingredient or queue slow retries in the UI.
    # Cached successful results above remain usable during this cooldown.
    if now < _text_search_unavailable_until:
        return []

    fields = (
        "code,product_name_pl,product_name,product_name_en,"
        "generic_name_pl,generic_name,generic_name_en,"
        "abbreviated_product_name,brands,nutriments,nutrition_data_per,categories_tags,"
        "quantity,product_quantity,product_quantity_unit,serving_quantity,"
        "serving_quantity_unit,countries_tags,stores,last_modified_t,obsolete"
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
        "lc": lc,
        "cc": cc,
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
        cooldown = 30
        response = getattr(exc, "response", None)
        status_code = response.status_code if response is not None else None
        if status_code in (429, 503):
            cooldown = 60
            retry = response.headers.get("Retry-After", "")
            if retry.isdigit():
                cooldown = max(cooldown, min(int(retry), 300))
        _text_search_unavailable_until = time.monotonic() + cooldown
        # No query/URL, which can contain user-entered text or provider details.
        logger.warning("Open Food Facts text search unavailable (%s, status=%s); cooldown=%ss",
            type(exc).__name__, status_code, cooldown)
        return []

    results = _results_from_off_search_response(payload, limit=limit, country_code=country_code)
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
    *,
    barcode: str | None = None,
    country_code: str = "PL",
) -> BarcodeLookupResult | None:
    """Uzupełnia makro przez wyszukiwanie internetowe po nazwie.

    Ta ścieżka uruchamia się tylko wtedy, gdy wyszukiwanie po kodzie dało
    nazwę, ale nie wartości odżywcze. Wymagamy bliskiego dopasowania nazwy
    i marki; dla skanu także zgodnego GTIN. Podobny wariant produktu może
    mieć inne makro, więc nie stanowi automatycznego uzupełnienia.
    """
    clean_name = " ".join(name.strip().split())
    clean_brand = " ".join((brand or "").strip().split())
    if len(clean_name) < 2:
        return None
    query = " ".join(part for part in (clean_brand, clean_name) if part)
    context = {"country_code": "GB"} if country_code == "GB" else {}
    results = await search_products_external(query, limit=10, **context)
    if not results and clean_brand:
        results = await search_products_external(clean_name, limit=10, **context)

    for candidate in results:
        if not _has_complete_nutrition(candidate):
            continue
        if barcode:
            # An automatically enriched scan must still refer to its exact
            # GTIN. A similar flavour or "light" product has different macros.
            if candidate.barcode in barcode_variants(barcode):
                return candidate
            continue
        candidate_name = " ".join(candidate.name.split()).casefold()
        candidate_brand = " ".join((candidate.brand or "").split()).casefold()
        if candidate_name == clean_name.casefold() and (
            not clean_brand or candidate_brand == clean_brand.casefold()
        ):
            return candidate
    return None


def _results_from_off_search_response(
    payload: object,
    *,
    limit: int,
    country_code: str = "PL",
) -> list[BarcodeLookupResult]:
    """Waliduje i deduplikuje odpowiedź pełnotekstowego wyszukiwania."""
    if not isinstance(payload, dict) or not isinstance(payload.get("products"), list):
        return []

    results: list[BarcodeLookupResult] = []
    seen: set[tuple[str, str]] = set()
    for product in payload["products"]:
        if not isinstance(product, dict):
            continue
        result = _result_from_off_product(product, country_code=country_code)
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


async def _fetch_off(
    client: httpx.AsyncClient, barcode: str, *, country_code: str = "PL",
) -> BarcodeLookupResult | None:
    cc, lc = _off_locale(country_code)
    params = {
        "cc": cc, "lc": lc,
        "fields": (
            "code,product_name_pl,product_name,product_name_en,"
            "generic_name_pl,generic_name,generic_name_en,"
            "abbreviated_product_name,brands,nutriments,nutrition_data_per,categories_tags,"
            "quantity,product_quantity,product_quantity_unit,serving_quantity,"
            "serving_quantity_unit"
        ),
    }
    if country_code == "GB":
        # Project country evidence in the same requested product response.
        # The account/cc parameter alone is never evidence of UK sales.
        params["fields"] += ",countries_tags,stores,last_modified_t,obsolete"
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
            if product is not None and (result := _result_from_off_product(product, country_code=country_code)):
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
                value = _number(nutrient, "value")
                if value is not None:
                    nutrient_values[int(nutrient["nutrientId"])] = value
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
            # USDA `servingSize` opisuje porcję żywieniową, a nie masę
            # całego opakowania. Nie pokazujemy na tej podstawie opcji
            # „1 opakowanie”, bo prowadziłoby to do błędnych przeliczeń.
            serving_quantity=None,
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


async def lookup_barcode_external(
    barcode: str, *, country_code: str = "PL",
) -> BarcodeLookupResult | None:
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

        context = {"country_code": "GB"} if country_code == "GB" else {}
        tasks = [
            asyncio.create_task(_fetch_off(client, normalized, **context)),
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
