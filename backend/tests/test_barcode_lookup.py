"""Testy odporności odpowiedzi zewnętrznej bazy kodów kreskowych."""

from app.services.barcode_lookup import (
    _product_from_off_response,
    _product_from_upcitemdb_response,
    _product_from_usda_response,
    normalize_barcode,
    price_range_for_product,
)


def test_normalize_barcode_removes_scanner_formatting() -> None:
    assert normalize_barcode("]E0 5449-0000-0099-6") == "5449000000996"


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
