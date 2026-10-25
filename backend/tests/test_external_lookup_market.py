"""Account market context must not change nutrition identity or invent GBP prices."""

import asyncio
import base64
import json
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import httpx
import pytest
from fastapi import BackgroundTasks

from app.api.v1 import products
from app.services import barcode_lookup, product_label_ai


CODE = "5901234123457"


def off_product():
    return {
        "code": CODE,
        "product_name_pl": "Jogurt naturalny",
        "product_name_en": "Natural yoghurt",
        "product_name": "Original label name",
        "brands": "Brand",
        "product_quantity": 500,
        "product_quantity_unit": "ml",
        "nutriments": {"energy-kcal_100g": 60, "proteins_100g": 4, "fat_100g": 2, "carbohydrates_100g": 6},
    }


@pytest.mark.parametrize("country,name,cc,lc", [("GB", "Natural yoghurt", "uk", "en"), ("PL", "Jogurt naturalny", "pl", "pl")])
def test_off_barcode_uses_market_language_in_same_single_request(country, name, cc, lc):
    class Client:
        calls = []

        async def get(self, url, *, params):
            self.calls.append((url, params))
            return httpx.Response(200, request=httpx.Request("GET", url), json={
                "status": "success", "result": {"id": "product_found"}, "product": off_product(),
            })

    client = Client()
    client.calls = []
    result = asyncio.run(barcode_lookup._fetch_off(client, CODE, country_code=country))
    assert len(client.calls) == 1
    assert client.calls[0][1]["cc"] == cc
    assert client.calls[0][1]["lc"] == lc
    assert "nutrition_data_per" in client.calls[0][1]["fields"].split(",")
    assert result.name == name
    assert result.kcal_per_100 == 60
    assert result.serving_quantity == 500 and result.unit == "ml"


def test_name_search_cache_is_partitioned_by_market_with_same_request_budget(monkeypatch):
    from app.services import uk_off_search
    uk_off_search._windows["search"].clear()
    uk_off_search._active["search"] = 0
    uk_off_search._backoff_until["search"] = 0
    calls = []
    factory = httpx.AsyncClient
    def respond(request):
        calls.append(request)
        if request.url.host == "search.openfoodfacts.org":
            return httpx.Response(200, json={"hits": [{**off_product(),
                "countries_tags": ["en:united-kingdom"]}]})
        return httpx.Response(200, json={"products": [off_product()]})
    monkeypatch.setattr(barcode_lookup.httpx, "AsyncClient", lambda **kwargs:
        factory(transport=httpx.MockTransport(respond), **kwargs))
    monkeypatch.setattr(barcode_lookup, "_text_search_cache", {})
    pl = asyncio.run(barcode_lookup.search_products_external("Brand", country_code="PL"))
    gb = asyncio.run(barcode_lookup.search_products_external("Brand", country_code="GB"))
    again = asyncio.run(barcode_lookup.search_products_external("Brand", country_code="GB"))
    assert len(calls) == 2
    assert (calls[0].url.params["cc"], calls[0].url.params["lc"]) == ("pl", "pl")
    assert calls[1].url.host == "search.openfoodfacts.org"
    assert calls[1].url.params["langs"] == "en"
    assert all("nutrition_data_per" in x.url.params["fields"].split(",") for x in calls)
    assert pl[0].name == "Jogurt naturalny"
    assert gb[0].name == again[0].name == "Natural yoghurt"


def test_internet_nutrition_fallback_retains_market_and_exact_gtin(monkeypatch):
    candidate = barcode_lookup._result_from_off_product(off_product())
    search = AsyncMock(return_value=[candidate])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    result = asyncio.run(barcode_lookup.find_nutrition_by_name("Natural yoghurt", "Brand", barcode=CODE, country_code="GB"))
    assert result is candidate
    search.assert_awaited_once_with("Brand Natural yoghurt", limit=10, country_code="GB")


def database_results(*rows):
    values = []
    for row in rows:
        result = MagicMock()
        result.scalar_one_or_none.return_value = row
        result.scalars.return_value.all.return_value = row if isinstance(row, list) else []
        values.append(result)
    return SimpleNamespace(execute=AsyncMock(side_effect=values), commit=AsyncMock(), rollback=AsyncMock())


def user(country="GB"):
    return SimpleNamespace(id=uuid.uuid4(), country_code=country)


@pytest.mark.parametrize("country,suppressed", [("GB", True), ("PL", False)])
@pytest.mark.parametrize("origin", ["catalog", "cache", "external"])
def test_barcode_route_suppresses_only_gb_legacy_prices_in_every_source(monkeypatch, country, suppressed, origin):
    row = SimpleNamespace(id=uuid.uuid4(), name="Yoghurt", brand="Brand", unit="ml", serving_quantity=500,
        barcode=CODE, nutrition_per_100={"kcal": 60, "protein": 4, "fat": 2, "carbs": 6},
        source="open_food_facts", price_min=2, price_max=8)
    db = database_results(row if origin == "catalog" else None, row if origin != "external" else None)
    lookup = AsyncMock(return_value=barcode_lookup._result_from_off_product(off_product()))
    monkeypatch.setattr(products, "lookup_barcode_external", lookup)
    response = asyncio.run(products.lookup_barcode(CODE, BackgroundTasks(), db, user(country)))
    assert response.kcal_per_100 == 60 and response.serving_quantity == 500
    assert (response.price_min is None) is suppressed
    assert (response.price_max is None) is suppressed
    if origin == "external":
        assert lookup.await_args.kwargs.get("country_code", "PL") == country
    else:
        lookup.assert_not_awaited()


def test_name_route_uses_account_market_and_suppresses_all_three_price_sources(monkeypatch):
    row = SimpleNamespace(id=uuid.uuid4(), name="Yoghurt", brand="Brand", unit="ml", serving_quantity=500,
        barcode=CODE, nutrition_per_100={"kcal": 60, "protein": 4, "fat": 2, "carbs": 6}, price_min=2, price_max=8)
    cached = SimpleNamespace(**{**row.__dict__, "name": "Cached yoghurt", "barcode": "12345670"})
    db = database_results([row], [cached], [])
    lookup = AsyncMock(return_value=[barcode_lookup._result_from_off_product(off_product())])
    monkeypatch.setattr(barcode_lookup, "search_products_external", lookup)
    response = asyncio.run(products.search_products_by_name("Yoghurt", 10, db, user()))
    assert {x.source for x in response} == {"catalog", "neon_cache", "open_food_facts"}
    assert all(x.price_min is None and x.price_max is None for x in response)
    lookup.assert_awaited_once_with("Yoghurt", limit=8, country_code="GB")


def test_label_route_uses_account_language_without_gbp_estimate(monkeypatch):
    recognize = AsyncMock(return_value={"found": True, "name": "Yoghurt", "barcode": CODE, "unit": "g"})
    monkeypatch.setattr(product_label_ai, "recognize_product_label", recognize)
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *_args: None)
    image = base64.b64encode(b"\xff\xd8\xff" + bytes(100)).decode()
    payload = products.ProductLabelRecognitionRequest(barcode=CODE, front_photo_base64=image, nutrition_photo_base64=image)
    response = asyncio.run(products.recognize_product_from_label(payload, user()))
    assert recognize.await_args.kwargs["country_code"] == "GB"
    assert response.price_min is None and response.price_max is None


def test_label_confirmation_suppresses_prices_but_preserves_shared_gtin_nutrition(monkeypatch):
    persist = AsyncMock()
    monkeypatch.setattr(products, "_upsert_barcode_cache", persist)
    payload = products.ProductLabelConfirmation(barcode=CODE, name="Yoghurt", unit="ml", serving_quantity=500,
        kcal_per_100=60, protein_per_100=4, fat_per_100=2, carbs_per_100=6)
    response = asyncio.run(products.confirm_product_label(payload, SimpleNamespace(), user()))
    assert response.price_min is None and response.price_max is None
    assert persist.await_args.kwargs["serving_quantity"] == 500
    assert persist.await_args.kwargs["kcal_per_100"] == 60


def test_label_english_context_preserves_visible_names_and_numeric_contract(monkeypatch):
    call = AsyncMock(return_value=json.dumps({"name": "Crème fraîche", "brand": "Brand", "unit": "ml", "serving_quantity": 500, "kcal_per_100": None}))
    monkeypatch.setattr(product_label_ai, "_call_gemini", call)
    image = base64.b64encode(b"image").decode()
    result = asyncio.run(product_label_ai.recognize_product_label(barcode=CODE, front_photo_base64=image, nutrition_photo_base64=image, country_code="GB"))
    text = " ".join(part.get("text", "") for part in call.await_args.args[0])
    assert "English" in text and "Do not translate" in text
    assert result["name"] == "Crème fraîche" and result["unit"] == "ml"
    assert result["serving_quantity"] == 500 and result["kcal_per_100"] is None
    assert call.await_args.kwargs == {"timeout_seconds": 22, "max_total_seconds": 40}


@pytest.mark.parametrize("extra,expected_unit,expected_size", [
    ({"product_quantity": 12, "product_quantity_unit": "oz", "quantity": "12 oz"}, "g", None),
    ({"product_quantity": 12, "product_quantity_unit": "oz", "quantity": "12 oz (355 ml)"}, "ml", 355),
    ({"product_quantity": 12, "product_quantity_unit": "oz", "serving_quantity_unit": "g", "quantity": "12 oz (355 ml)"}, "ml", 355),
    ({"product_quantity": 500, "product_quantity_unit": "ml", "serving_quantity_unit": "g"}, "ml", 500),
    ({"quantity": "2 x 250 ml", "serving_quantity_unit": "g"}, "ml", 500),
    ({"product_quantity": 500, "product_quantity_unit": "ml", "quantity": "12 oz"}, "ml", 500),
])
def test_package_never_becomes_wrong_physical_dimension(extra, expected_unit, expected_size):
    product = off_product()
    product.pop("product_quantity", None)
    product.pop("product_quantity_unit", None)
    product.update(extra)
    result = barcode_lookup._result_from_off_product(product, country_code="GB")
    assert result.unit == expected_unit
    assert result.serving_quantity == expected_size


@pytest.mark.parametrize("country,expected", [("GB", "Natural yoghurt"), ("PL", "Jogurt naturalny"), ("unsupported", "Jogurt naturalny")])
def test_market_name_priority_does_not_change_nutrition_or_pack(country, expected):
    result = barcode_lookup._result_from_off_product(off_product(), country_code=country)
    assert result.name == expected
    assert result.kcal_per_100 == 60
    assert result.serving_quantity == 500 and result.unit == "ml"


def test_barcode_orchestrator_passes_gb_context_without_waiting_for_secondary_source(monkeypatch):
    off = AsyncMock(return_value=barcode_lookup._result_from_off_product(off_product(), country_code="GB"))
    usda = AsyncMock(return_value=None)
    monkeypatch.setattr(barcode_lookup, "_fetch_off", off)
    monkeypatch.setattr(barcode_lookup, "_fetch_usda", usda)
    result = asyncio.run(barcode_lookup.lookup_barcode_external(CODE, country_code="GB"))
    assert result.name == "Natural yoghurt"
    assert off.await_args.kwargs == {"country_code": "GB"}
    usda.assert_not_awaited()


def test_name_enrichment_brand_fallback_keeps_market_and_request_count(monkeypatch):
    search = AsyncMock(side_effect=[[], []])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    assert asyncio.run(barcode_lookup.find_nutrition_by_name("Yoghurt", "Brand", country_code="GB")) is None
    assert [(x.args, x.kwargs) for x in search.await_args_list] == [
        (("Brand Yoghurt",), {"limit": 10, "country_code": "GB"}),
        (("Yoghurt",), {"limit": 10, "country_code": "GB"}),
    ]


@pytest.mark.parametrize("origin", ["catalog", "cache", "external"])
def test_gb_incomplete_barcode_fallback_keeps_account_context_and_unknown_package(monkeypatch, origin):
    row = SimpleNamespace(id=uuid.uuid4(), name="Yoghurt", brand="Brand", unit="ml", serving_quantity=None,
        barcode=CODE, nutrition_per_100={"kcal": None}, source="open_food_facts", price_min=2, price_max=8)
    db = database_results(row if origin == "catalog" else None, row if origin != "external" else None)
    partial = barcode_lookup._result_from_off_product({"code": CODE, "product_name_en": "Yoghurt", "product_quantity_unit": "ml"})
    monkeypatch.setattr(products, "lookup_barcode_external", AsyncMock(return_value=partial if origin == "external" else None))
    search = AsyncMock(return_value=barcode_lookup._result_from_off_product(off_product()))
    monkeypatch.setattr(products, "find_nutrition_by_name", search)
    response = asyncio.run(products.lookup_barcode(CODE, BackgroundTasks(), db, user()))
    assert search.await_args.kwargs == {"barcode": CODE, "country_code": "GB"}
    assert response.kcal_per_100 == 60
    assert response.serving_quantity is None
    assert response.price_min is None and response.price_max is None


@pytest.mark.parametrize("text", ["not json", "[]", '{"name": null}'])
def test_label_parse_errors_use_account_english(text):
    with pytest.raises(product_label_ai.ProductLabelRecognitionError) as exc:
        product_label_ai._parse_label_json(text, CODE, country_code="GB")
    assert "could not be read" in str(exc.value)


@pytest.mark.parametrize("unit", ["oz", "fl oz", "kg", "l", "szt"])
def test_label_invalid_explicit_basis_never_invents_grams_or_per100_macros(unit):
    result = product_label_ai._parse_label_json(json.dumps({
        "name": "Yoghurt", "unit": unit, "serving_quantity": 12,
        "kcal_per_100": 60, "protein_per_100": 4, "fat_per_100": 2, "carbs_per_100": 6,
    }), CODE, country_code="GB")
    assert result["name"] == "Yoghurt"
    assert result["serving_quantity"] is None
    assert all(result[key] is None for key in ("kcal_per_100", "protein_per_100", "fat_per_100", "carbs_per_100"))


def test_label_legacy_missing_unit_stays_compatible_without_extra_inference():
    result = product_label_ai._parse_label_json('{"name":"Yoghurt","serving_quantity":500,"kcal_per_100":60}', CODE)
    assert result["unit"] == "g" and result["serving_quantity"] == 500 and result["kcal_per_100"] == 60


@pytest.mark.parametrize("account,spoofed", [("GB", "PL"), ("PL", "GB")])
def test_http_client_country_cannot_override_persisted_account_market(monkeypatch, account, spoofed):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    db = database_results(None, None)
    lookup = AsyncMock(return_value=barcode_lookup._result_from_off_product(off_product()))
    monkeypatch.setattr(products, "lookup_barcode_external", lookup)
    monkeypatch.setattr(products, "_persist_barcode_cache_in_background", AsyncMock())
    app = FastAPI()
    app.include_router(products.router, prefix="/products")
    app.dependency_overrides[products.get_current_user] = lambda: user(account)
    app.dependency_overrides[products.get_db] = lambda: db
    with TestClient(app) as client:
        response = client.get(f"/products/barcode/{CODE}?country_code={spoofed}&cc={spoofed}&lc=zz")
    assert response.status_code == 200
    assert lookup.await_args.kwargs.get("country_code", "PL") == account
    assert (response.json()["price_min"] is None) is (account == "GB")


@pytest.mark.parametrize("local_unit,local_size,include_package,expected_unit,expected_size", [
    ("g", None, True, "ml", 500),
    ("g", 250, True, "g", 250),
    ("g", None, False, "g", None),
    ("opak", None, True, "ml", 500),
    ("opak", 250, True, "ml", 500),
    ("g", 0, True, "ml", 500),
    ("g", float("nan"), True, "ml", 500),
])
def test_local_barcode_merge_takes_package_and_unit_together(local_unit, local_size, include_package, expected_unit, expected_size):
    local = products.BarcodeLookupResponse(found=True, name="Yoghurt", unit=local_unit, serving_quantity=local_size)
    external = barcode_lookup._result_from_off_product(off_product())
    merged = products._merge_local_barcode_response(local, external, include_package=include_package)
    assert merged.unit == expected_unit and merged.serving_quantity == expected_size


def test_british_generic_name_precedes_polish_only_title():
    result = barcode_lookup._result_from_off_product({"product_name_pl": "Jogurt naturalny", "generic_name_en": "Natural yoghurt"}, country_code="GB")
    assert result.name == "Natural yoghurt"


@pytest.mark.parametrize("quantity,unit,expected", [
    (-10, "g", None), (0, "g", None), (float("nan"), "g", None),
    (float("inf"), "g", None), ("NaN", "g", None), ("Infinity", "g", None),
    (10 ** 400, "g", None), (1e308, "kg", None),
    (100000.01, "g", None), (100000, "g", 100000),
    (100, "l", 100000), (100.00001, "l", None),
    (100000000, "mg", 100000), (100000001, "mg", None),
])
def test_off_numeric_package_is_positive_finite_and_within_confirmation_limit(quantity, unit, expected):
    product = {"product_name_en": "Product", "product_quantity": quantity, "product_quantity_unit": unit}
    result = barcode_lookup._result_from_off_product(product, country_code="GB")
    assert result.serving_quantity == expected
    # Prove an invalid package can never leak Infinity/NaN into JSON/cache.
    json.dumps(result.__dict__, allow_nan=False)


@pytest.mark.parametrize("label,expected", [
    ("-10 g", None), ("−10 g", None), ("-2 x 250 ml", None),
    ("2 x -250 ml", None), ("0 g", None), ("0 x 500 g", None),
    ("-2 x -250 ml", None),
    ("500001 g", None), ("1e309 g", None), ("1e-309 g", None),
    ("9" * 400 + " kg", None), ("9" * 200 + " x " + "9" * 200 + " kg", None),
    ("1,5 l", 1500), ("100 kg", 100000), ("100.1 kg", None),
])
def test_off_metric_text_package_never_strips_sign_or_overflows(label, expected):
    result = barcode_lookup._result_from_off_product({"product_name_en": "Product", "quantity": label}, country_code="GB")
    assert result.serving_quantity == expected
    json.dumps(result.__dict__, allow_nan=False)


@pytest.mark.parametrize("basis", [" 100g ", "100 ML", "100\tml"])
def test_explicit_per100_basis_can_be_trimmed_without_changing_numbers(basis):
    result = barcode_lookup._result_from_off_product({
        "product_name_en": "Product", "nutrition_data_per": basis,
        "nutriments": {"energy-kcal": 60, "proteins": 4, "fat": 2, "carbohydrates": 6},
    }, country_code="GB")
    assert result.kcal_per_100 == 60 and result.protein_per_100 == 4


@pytest.mark.parametrize("basis,key,expected", [("serving", "energy-kj_100g", 100), ("100ml", "energy-kj", 100), ("serving", "energy-kj", None)])
def test_explicit_kj_field_respects_per100_basis(basis, key, expected):
    result = barcode_lookup._result_from_off_product({"product_name_en": "Product", "nutrition_data_per": basis, "nutriments": {key: 418.4}})
    assert result.kcal_per_100 == expected


def test_kcal_per100_keeps_precedence_over_kj_fallback():
    result = barcode_lookup._result_from_off_product({"product_name_en": "Product", "nutriments": {"energy-kcal_100g": 60, "energy-kj_100g": 418.4}})
    assert result.kcal_per_100 == 60


@pytest.mark.parametrize("numeric", [100001, 0, float("nan"), float("inf"), -1])
@pytest.mark.parametrize("numeric_unit,label,expected_unit", [("ml", "250 g", "g"), ("g", "250 ml", "ml")])
def test_rejected_numeric_pack_cannot_attach_its_unit_to_metric_label(numeric, numeric_unit, label, expected_unit):
    result = barcode_lookup._result_from_off_product({
        "product_name_en": "Product", "product_quantity": numeric,
        "product_quantity_unit": numeric_unit, "quantity": label,
    }, country_code="GB")
    assert result.serving_quantity == 250 and result.unit == expected_unit


def test_accepted_numeric_pack_retains_both_values_over_conflicting_label():
    result = barcode_lookup._result_from_off_product({
        "product_name_en": "Product", "product_quantity": 100000,
        "product_quantity_unit": "ml", "quantity": "250 g",
    }, country_code="GB")
    assert result.serving_quantity == 100000 and result.unit == "ml"
