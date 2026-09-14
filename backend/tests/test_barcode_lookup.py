"""Testy odporności odpowiedzi zewnętrznej bazy kodów kreskowych."""

from app.services.barcode_lookup import _product_from_off_response, normalize_barcode


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
