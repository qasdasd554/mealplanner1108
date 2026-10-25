"""Bounded UK OFF discovery: search index is not a fresh full GTIN snapshot."""

import asyncio
from unittest.mock import AsyncMock

import httpx
import pytest

from app.services import ai_recipe_import, barcode_lookup, uk_off_search
from tests.test_regional_shopping import db, run


CODE = "5901234123457"


def hit(**changes):
    return {"code": CODE, "product_name": "Natural yoghurt", "brands": ["Brand"],
        "countries_tags": ["en:united-kingdom"], "quantity": "450 g",
        "nutrition_data_per": "100g", "last_modified_t": 1700000000,
        "nutriments": {"energy-kcal_100g": 60, "proteins_100g": 4,
            "fat_100g": 2, "carbohydrates_100g": 6}, **changes}


@pytest.fixture(autouse=True)
def reset_cache(monkeypatch):
    monkeypatch.setattr(barcode_lookup, "_text_search_cache", {})
    for kind in ("search", "product"):
        uk_off_search._windows[kind].clear()
        uk_off_search._active[kind] = 0
        uk_off_search._backoff_until[kind] = 0
    yield
    for kind in ("search", "product"):
        uk_off_search._windows[kind].clear()
        uk_off_search._active[kind] = 0
        uk_off_search._backoff_until[kind] = 0


def fake_http(monkeypatch, payload):
    factory = httpx.AsyncClient
    calls = []
    def handler(request):
        calls.append(request)
        if request.url.host != "search.openfoodfacts.org":
            return httpx.Response(503)
        return httpx.Response(200, json=payload)
    monkeypatch.setattr(barcode_lookup.httpx, "AsyncClient", lambda **kwargs:
        factory(transport=httpx.MockTransport(handler), **kwargs))
    return calls


def install_transport(monkeypatch, handler):
    factory = httpx.AsyncClient
    monkeypatch.setattr(barcode_lookup.httpx, "AsyncClient", lambda **kwargs:
        factory(transport=httpx.MockTransport(handler), **kwargs))


def test_uk_uses_working_off_search_in_one_request_not_failed_legacy(monkeypatch):
    calls = fake_http(monkeypatch, {"hits": [hit()], "timed_out": False})
    rows = asyncio.run(barcode_lookup.search_products_external("Natural yoghurt", country_code="GB"))
    assert len(rows) == 1
    assert rows[0].name == "Natural yoghurt" and rows[0].kcal_per_100 == 60
    assert rows[0].serving_quantity == 450
    assert rows[0].off_product is None and rows[0].off_retrieved_at is None
    assert rows[0].off_search_projection is True
    assert len(calls) == 1 and calls[0].url.host == "search.openfoodfacts.org"
    assert calls[0].url.params["langs"] == "en"


@pytest.mark.parametrize("query", ['milk OR countries_tags:"en:poland"', 'milk (NOT water)', 'brand:foo*'])
def test_user_terms_cannot_override_the_fixed_uk_filter(monkeypatch, query):
    calls = fake_http(monkeypatch, {"hits": [hit()]})
    asyncio.run(barcode_lookup.search_products_external(query, country_code="GB"))
    sent = calls[0].url.params["q"]
    assert sent.startswith('countries_tags:"en:united-kingdom" ')
    assert " OR " not in sent and " NOT " not in sent
    assert 'countries_tags:"en:poland"' not in sent


def test_single_word_uses_full_text_not_the_providers_empty_wildcard_phrase(monkeypatch):
    factory = httpx.AsyncClient
    def respond(request):
        # Captured live behaviour: an unfielded quoted phrase is translated
        # by this service to match_phrase on literal field '*', yielding 0.
        rows = [hit(product_name="Carrots")] if request.url.params["q"] == (
            'countries_tags:"en:united-kingdom" carrots') else []
        return httpx.Response(200, json={"hits": rows})
    monkeypatch.setattr(barcode_lookup.httpx, "AsyncClient", lambda **kwargs:
        factory(transport=httpx.MockTransport(respond), **kwargs))
    rows = asyncio.run(barcode_lookup.search_products_external("carrots", country_code="GB"))
    assert len(rows) == 1 and rows[0].name == "Carrots"


@pytest.mark.parametrize("changes", [
    {"countries_tags": ["en:poland"]}, {"countries_tags": "en:united-kingdom"},
    {"obsolete": True}, {"code": "5901234123458"}, {"product_name": ""},
])
def test_foreign_obsolete_or_invalid_index_hits_are_not_uk_products(monkeypatch, changes):
    calls = fake_http(monkeypatch, {"hits": [hit(**changes)]})
    assert asyncio.run(barcode_lookup.search_products_external("yoghurt", country_code="GB")) == []
    assert len(calls) == 1


def test_cached_search_keeps_projection_status_and_makes_no_second_request(monkeypatch):
    calls = fake_http(monkeypatch, {"hits": [hit()]})
    first = asyncio.run(barcode_lookup.search_products_external("yoghurt", country_code="GB"))
    again = asyncio.run(barcode_lookup.search_products_external("yoghurt", country_code="GB"))
    assert len(first) == len(again) == 1 and len(calls) == 1
    assert first[0].off_product is again[0].off_product is None


@pytest.mark.parametrize("payload", [[], {"hits": {}}, {"hits": [None, "bad"]},
    {"hits": [hit()], "timed_out": True}, {"hits": [hit()], "errors": [{"status": 400}]}])
def test_partial_or_malformed_search_fails_closed_without_false_country_evidence(monkeypatch, payload):
    fake_http(monkeypatch, payload)
    assert asyncio.run(barcode_lookup.search_products_external("yoghurt", country_code="GB")) == []


@pytest.mark.parametrize("status", [429, 503])
def test_provider_backoff_does_not_retry_other_queries_or_leak_their_text(monkeypatch, caplog, status):
    calls = []
    def respond(request):
        calls.append(request)
        return httpx.Response(status, headers={"Retry-After": "600"})
    install_transport(monkeypatch, respond)
    assert run(barcode_lookup.search_products_external("private user words", country_code="GB")) == []
    assert run(barcode_lookup.search_products_external("another query", country_code="GB")) == []
    assert len(calls) == 1
    assert "private user words" not in caplog.text
    assert uk_off_search._backoff_until["search"] >= uk_off_search.time.monotonic() + 590


def test_search_budget_is_bounded_without_slowing_requests_in_a_queue(monkeypatch):
    calls = fake_http(monkeypatch, {"hits": [hit()]})
    for index in range(8):
        run(barcode_lookup.search_products_external(f"yoghurt {index}", country_code="GB"))
    assert len(calls) == 6 and uk_off_search._active["search"] == 0


@pytest.mark.parametrize("kind", ["timeout", "bad_json", "oversized", "redirect"])
def test_search_failure_makes_no_fallback_fanout_and_cleans_active_slot(monkeypatch, kind):
    calls = []
    def respond(request):
        calls.append(request)
        if kind == "timeout": raise httpx.ReadTimeout("synthetic", request=request)
        if kind == "bad_json": return httpx.Response(200, content=b"invalid")
        if kind == "oversized": return httpx.Response(200, content=b"x" * 1_000_001)
        return httpx.Response(302, headers={"Location": "https://example.invalid/"})
    install_transport(monkeypatch, respond)
    assert run(barcode_lookup.search_products_external("yoghurt", country_code="GB")) == []
    assert len(calls) == 1 and uk_off_search._active["search"] == 0


def test_parallel_limit_and_cancellation_release_the_slot(monkeypatch):
    async def scenario():
        gate = asyncio.Event()
        calls = []
        async def respond(request):
            calls.append(request)
            await gate.wait()
            return httpx.Response(200, json={"hits": [hit()]})
        install_transport(monkeypatch, respond)
        tasks = [asyncio.create_task(uk_off_search.search_uk_index(f"food {i}", limit=1)) for i in range(4)]
        await asyncio.sleep(0)
        assert len(calls) == 3 and uk_off_search._active["search"] == 3
        tasks[0].cancel()
        with pytest.raises(asyncio.CancelledError): await tasks[0]
        gate.set()
        await asyncio.gather(*tasks[1:])
        assert uk_off_search._active["search"] == 0
    run(scenario())


@pytest.mark.parametrize("changes", [
    {"countries_tags": ["en:poland"]}, {"code": "5449000000996"},
    {"obsolete": True}, {"product_name": "Changed yoghurt label"},
])
def test_changed_full_gtin_record_is_not_silently_shared_as_the_old_ingredient(monkeypatch, changes):
    from app.services.recipe_ingredient_catalogue import _external_ingredient
    requests = []
    def respond(request):
        requests.append(request)
        if request.url.host == "search.openfoodfacts.org":
            return httpx.Response(200, json={"hits": [hit()]})
        raw = hit(**changes)
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": raw})
    install_transport(monkeypatch, respond)
    assert run(_external_ingredient("Natural yoghurt", country="GB")) is None
    assert len(requests) == 2
    assert requests[1].url.path.endswith(f"/{CODE}.json")


def test_index_missing_macros_can_recover_from_the_chosen_full_record(monkeypatch):
    from app.services.recipe_ingredient_catalogue import _external_ingredient
    requests = []
    def respond(request):
        requests.append(request)
        if request.url.host == "search.openfoodfacts.org":
            return httpx.Response(200, json={"hits": [hit(nutriments={})]})
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": hit()})
    install_transport(monkeypatch, respond)
    product = run(_external_ingredient("Natural yoghurt", country="GB"))
    assert product.nutrition_per_100["kcal"] == 60
    assert product._used_off_snapshot[0]["nutriments"]["energy-kcal_100g"] == 60
    assert len(requests) == 2


def test_recipe_uses_only_fresh_exact_record_and_persists_just_the_chosen_product(db, monkeypatch):
    from sqlalchemy import func, select
    from app.api.v1.recipes import _create_ai_recipe
    from app.models import OffCatalogueProduct, Product
    from app.schemas.recipe import AIRecipeImportRequest

    session, adapter, user, _, _ = db
    before = session.scalar(select(func.count()).select_from(Product))
    requests = []
    def respond(request):
        requests.append(request)
        if request.url.host == "search.openfoodfacts.org":
            first = hit(product_name="Filo pastry", nutriments={"energy-kcal_100g": 999})
            # A different search hit is not bulk-imported alongside the one
            # recipe ingredient the user actually requested.
            return httpx.Response(200, json={"hits": [first, hit(code="5449000000996", product_name="Cola")]})
        raw = hit(product_name="Filo pastry", product_quantity=250,
            product_quantity_unit="g", quantity="250 g")
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": raw})
    install_transport(monkeypatch, respond)
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value={
        "name": "Synthetic filo dish", "servings": 1, "meal_type": "obiad",
        "ingredients": [{"product_name": "Filo pastry", "quantity": 100, "unit": "g"}],
        "instructions": ["Prepare the filo pastry."],
    }))
    recipe = run(_create_ai_recipe(AIRecipeImportRequest(text="Synthetic filo dish"), user, adapter, skip_rate_limit=True))
    chosen = recipe.ingredients[0].product
    assert chosen.nutrition_per_100["kcal"] == 60  # Not the stale index's 999.
    assert chosen.serving_quantity == 250 and chosen.barcode == CODE
    assert session.scalar(select(func.count()).select_from(Product)) == before + 1
    cached = session.get(OffCatalogueProduct, CODE)
    assert cached.nutrition_per_100["kcal"] == 60 and cached.package_quantity == 250
    assert session.scalar(select(func.count()).select_from(OffCatalogueProduct)) == 1
    assert len(requests) == 2
    again = run(_create_ai_recipe(AIRecipeImportRequest(text="Synthetic filo dish"), user, adapter, skip_rate_limit=True))
    assert again.ingredients[0].product_id == chosen.id
    assert session.scalar(select(func.count()).select_from(Product)) == before + 1
    assert len(requests) == 2  # Subsequent use comes from Neon, not the index.
