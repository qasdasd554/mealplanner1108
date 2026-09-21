"""Testy odporności odpowiedzi zewnętrznej bazy kodów kreskowych."""

import asyncio
import time

import httpx

from app.services import barcode_lookup
from app.services.barcode_lookup import (
    _product_from_off_response,
    _result_from_off_product,
    _results_from_off_search_response,
    _product_from_upcitemdb_response,
    _product_from_usda_response,
    barcode_variants,
    normalize_barcode,
    price_range_for_product,
)


def test_normalize_barcode_removes_scanner_formatting() -> None:
    assert normalize_barcode("]E0 5449-0000-0099-6") == "5449000000996"


def test_upc_and_ean_aliases_match_same_product() -> None:
    assert "00123456789012" in barcode_variants("0123456789012")
    assert "123456789012" in barcode_variants("0123456789012")
    assert "0123456789012" in barcode_variants("123456789012")


def test_reads_current_v3_product_response() -> None:
    product = {"product_name": "Przykładowy produkt"}
    response = {
        "status": "success",
        "result": {"id": "product_found"},
        "product": product,
    }
    assert _product_from_off_response(response, "v3") == product


def test_keeps_v2_fallback_compatible() -> None:
    product = {"product_name": "Starsza odpowiedź"}
    assert _product_from_off_response({"status": 1, "product": product}, "v2") == product


def test_rejects_not_found_without_throwing() -> None:
    response = {
        "status": "success",
        "result": {"id": "product_not_found"},
        "product": {},
    }
    assert _product_from_off_response(response, "v3") is None


def test_butter_has_fixed_price_range() -> None:
    assert price_range_for_product("Masło ekstra 200 g") == (6.0, 10.0)


def test_name_search_result_keeps_barcode_and_macros() -> None:
    result = _result_from_off_product({
        "code": "5901234123457",
        "product_name_pl": "Jogurt naturalny",
        "brands": "Przykładowa marka",
        "nutriments": {
            "energy-kcal_100g": 62,
            "proteins_100g": 4.2,
            "fat_100g": 2.0,
            "carbohydrates_100g": 6.1,
        },
    })
    assert result is not None
    assert result.barcode == "5901234123457"
    assert result.name == "Jogurt naturalny"
    assert result.kcal_per_100 == 62


def test_name_search_deduplicates_products_and_respects_limit() -> None:
    payload = {
        "products": [
            {"code": "5901234123457", "product_name": "Jogurt", "brands": "Marka"},
            {"code": "5901234123458", "product_name": "jogurt", "brands": "marka"},
            {"code": "5901234123459", "product_name": "Kefir", "brands": "Druga"},
            {"code": "5901234123460", "product_name": "Maślanka", "brands": "Trzecia"},
        ]
    }
    results = _results_from_off_search_response(payload, limit=2)
    assert [result.name for result in results] == ["Jogurt", "Kefir"]


def test_reads_exact_usda_gtin_and_macros() -> None:
    response = {
        "foods": [
            {
                "gtinUpc": "085239268179",
                "description": "CHICKEN BREAST",
                "brandName": "Good & Gather",
                "brandedFoodCategory": "Meat/Poultry",
                "foodNutrients": [
                    {"nutrientId": 1008, "value": 117},
                    {"nutrientId": 1003, "value": 18.8},
                    {"nutrientId": 1004, "value": 4.69},
                    {"nutrientId": 1005, "value": 1.56},
                ],
            }
        ]
    }
    result = _product_from_usda_response(response, "085239268179")
    assert result is not None
    assert result.brand == "Good & Gather"
    assert result.kcal_per_100 == 117
    assert result.protein_per_100 == 18.8
    assert result.source == "usda_fooddata_central"


def test_usda_rejects_fuzzy_non_matching_code() -> None:
    response = {"foods": [{"gtinUpc": "12345678", "description": "Wrong"}]}
    assert _product_from_usda_response(response, "87654321") is None


def test_reads_upcitemdb_identity() -> None:
    response = {
        "items": [
            {
                "ean": "5901234123457",
                "title": "Pomidory krojone",
                "brand": "Przykładowa marka",
                "category": "Food > Vegetables",
            }
        ]
    }
    result = _product_from_upcitemdb_response(response, "5901234123457")
    assert result is not None
    assert result.name == "Pomidory krojone"
    assert result.brand == "Przykładowa marka"
    assert (result.price_min, result.price_max) == (2.0, 15.0)


def test_lookup_returns_fast_complete_result_without_waiting_for_slow_providers(monkeypatch) -> None:
    async def fast_off(client, barcode):
        await asyncio.sleep(0.01)
        return barcode_lookup.BarcodeLookupResult(
            name="Sok", brand="Marka", unit="ml", kcal_per_100=40,
            protein_per_100=0, fat_per_100=0, carbs_per_100=10,
            price_min=3, price_max=12, source="open_food_facts",
        )

    async def slow_provider(client, barcode):
        await asyncio.sleep(1)
        return None

    monkeypatch.setattr(barcode_lookup, "_fetch_off", fast_off)
    monkeypatch.setattr(barcode_lookup, "_fetch_usda", slow_provider)
    monkeypatch.setattr(barcode_lookup, "_fetch_upcitemdb", slow_provider)
    started = time.monotonic()
    result = asyncio.run(barcode_lookup.lookup_barcode_external("5901234123457"))
    assert result is not None and result.name == "Sok"
    assert time.monotonic() - started < 0.5


def test_off_not_found_does_not_repeat_lookup_in_second_api_version() -> None:
    class MissingClient:
        def __init__(self):
            self.calls = []

        async def get(self, url, *, params):
            self.calls.append(url)
            request = httpx.Request("GET", url)
            response = httpx.Response(404, request=request)
            raise httpx.HTTPStatusError("not found", request=request, response=response)

    client = MissingClient()
    result = asyncio.run(barcode_lookup._fetch_off(client, "5901234123457"))
    assert result is None
    assert len(client.calls) == 1


def test_partial_off_product_can_take_macros_from_second_source() -> None:
    off = barcode_lookup.BarcodeLookupResult(
        name="Jogurt naturalny", brand="Polska marka", unit="g",
        kcal_per_100=None, protein_per_100=None,
        fat_per_100=None, carbs_per_100=None,
        price_min=2, price_max=7, source="open_food_facts",
    )
    usda = barcode_lookup.BarcodeLookupResult(
        name="Natural yogurt", brand=None, unit="g",
        kcal_per_100=62, protein_per_100=4.2,
        fat_per_100=2, carbs_per_100=6.1,
        price_min=2, price_max=7, source="usda_fooddata_central",
    )
    merged = barcode_lookup._merge_lookup_results(off, usda)
    assert merged.name == "Jogurt naturalny"
    assert merged.brand == "Polska marka"
    assert merged.kcal_per_100 == 62
    assert merged.protein_per_100 == 4.2
