"""The OFF snapshot and its real fetch time travel together; no live HTTP."""

import asyncio
from datetime import datetime, timedelta, timezone
import json

import httpx
import pytest

from app.services import barcode_lookup


NOW = datetime(2026, 10, 24, 9, 0, tzinfo=timezone.utc)
CODE = "5025125000006"


def result(**changes):
    values = dict(name="Yoghurt", brand=None, unit="g", kcal_per_100=60,
                  protein_per_100=4, fat_per_100=2, carbs_per_100=6,
                  price_min=2, price_max=7, source="open_food_facts", barcode=CODE)
    values.update(changes)
    return barcode_lookup.BarcodeLookupResult(**values)


def clock(monkeypatch):
    current = [NOW]

    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return current[0].astimezone(tz) if tz else current[0].replace(tzinfo=None)

    monkeypatch.setattr(barcode_lookup, "datetime", FrozenDateTime, raising=False)
    return current


def test_raw_off_gets_original_utc_string_and_is_json_safe(monkeypatch):
    clock(monkeypatch)
    value = result(off_product={"code": CODE})
    assert value.off_retrieved_at == NOW.isoformat()
    assert json.loads(json.dumps(value.__dict__))["off_retrieved_at"] == NOW.isoformat()


def test_non_off_result_has_no_fetch_time():
    assert result(source="usda_fooddata_central").off_retrieved_at is None


def test_explicit_timestamp_normalizes_timezone_without_changing_the_instant():
    value = result(off_product={"code": CODE}, off_retrieved_at="2026-10-24T11:00:00+02:00")
    assert value.off_retrieved_at == NOW.isoformat()


@pytest.mark.parametrize("timestamp", [NOW, True, "not a date", "2026-10-24T09:00:00"])
def test_raw_off_rejects_non_string_or_timezone_free_explicit_timestamp(timestamp):
    with pytest.raises(ValueError):
        result(off_product={"code": CODE}, off_retrieved_at=timestamp)


def test_memory_text_cache_does_not_turn_index_projection_into_a_full_snapshot(monkeypatch):
    from app.services import uk_off_search
    uk_off_search._windows["search"].clear()
    uk_off_search._active["search"] = 0
    uk_off_search._backoff_until["search"] = 0
    current = clock(monkeypatch)
    monkeypatch.setattr(barcode_lookup, "_text_search_cache", {})
    calls = []

    factory = httpx.AsyncClient
    def respond(request):
        calls.append(request.url)
        return httpx.Response(200, json={"hits": [{
            "code": CODE, "product_name_en": "Yoghurt",
            "countries_tags": ["en:united-kingdom"],
            "last_modified_t": 1700000000,
        }]})
    monkeypatch.setattr(barcode_lookup.httpx, "AsyncClient", lambda **kwargs:
        factory(transport=httpx.MockTransport(respond), **kwargs))
    first, = asyncio.run(barcode_lookup.search_products_external("yoghurt", country_code="GB"))
    current[0] += timedelta(minutes=4)
    second, = asyncio.run(barcode_lookup.search_products_external("yoghurt", country_code="GB"))
    assert len(calls) == 1
    assert first.off_product is second.off_product is None
    assert first.off_retrieved_at is second.off_retrieved_at is None
    assert first.off_search_projection and second.off_search_projection


@pytest.mark.parametrize("has_primary_raw,same_code", [(True, True), (False, True), (False, False)])
def test_merge_keeps_time_of_the_selected_raw_off_snapshot(has_primary_raw, same_code):
    first_time = (NOW - timedelta(hours=1)).isoformat()
    second_time = NOW.isoformat()
    primary_raw = {"code": CODE, "revision": "primary"} if has_primary_raw else None
    other_code = CODE if same_code else "5449000000996"
    supplementary_raw = {"code": other_code, "revision": "supplementary"}
    primary = result(off_product=primary_raw, off_retrieved_at=first_time if has_primary_raw else None)
    supplementary = result(barcode=other_code, off_product=supplementary_raw,
                           off_retrieved_at=second_time)
    merged = barcode_lookup.merge_lookup_results(primary, supplementary)
    expected_raw = primary_raw if has_primary_raw else supplementary_raw if same_code else None
    expected_time = first_time if has_primary_raw else second_time if same_code else None
    assert merged.off_product is expected_raw
    assert merged.off_retrieved_at == expected_time
    json.dumps(merged.__dict__)


def test_polish_result_keeps_no_raw_country_evidence():
    value = barcode_lookup._result_from_off_product({
        "code": CODE, "product_name_pl": "Jogurt", "countries_tags": ["en:poland"],
    }, country_code="PL")
    assert value.off_product is None
    assert value.off_retrieved_at is None


def test_merge_same_upc_ean_identity_keeps_supplementary_fetch_time():
    primary = result(barcode="123456789012")
    raw = {"code": "0123456789012"}
    supplementary = result(barcode="0123456789012", off_product=raw,
                           off_retrieved_at=NOW.isoformat())
    merged = barcode_lookup.merge_lookup_results(primary, supplementary)
    assert merged.off_product is raw
    assert merged.off_retrieved_at == NOW.isoformat()
