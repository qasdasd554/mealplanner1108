"""Bounded on-demand UK discovery through OFF's own search index.

Index hits are suggestions, not fresh Product Opener snapshots. Only the
chosen cooking ingredient is re-read by exact GTIN before shared persistence.
There is no crawl, country/store inference, database access or background job.
"""

import asyncio
from collections import deque
import json
import logging
import re
import time

import httpx


SEARCH_URL = "https://search.openfoodfacts.org/search"
logger = logging.getLogger(__name__)
_windows = {"search": deque(), "product": deque()}
_active = {"search": 0, "product": 0}
_backoff_until = {"search": 0.0, "product": 0.0}
_FIELDS = (
    "code,product_name_en,product_name,generic_name_en,generic_name,brands,"
    "countries_tags,categories_tags,quantity,product_quantity,product_quantity_unit,"
    "serving_quantity,serving_quantity_unit,nutriments,nutrition_data_per,"
    "last_modified_t,obsolete,stores,ingredients_text_en,ingredients_text"
)


async def _get_json(url, params, *, kind):
    from app.services.barcode_lookup import USER_AGENT

    tick = time.monotonic()
    window = _windows[kind]
    while window and tick - window[0] >= 60:
        window.popleft()
    if tick < _backoff_until[kind] or len(window) >= 6 or _active[kind] >= 3:
        return None
    window.append(tick)
    _active[kind] += 1
    try:
        timeout = 2.0 if kind == "search" else 1.5
        async with asyncio.timeout(timeout):
            async with httpx.AsyncClient(timeout=timeout, follow_redirects=False,
                headers={"User-Agent": USER_AGENT, "Accept": "application/json"}) as client:
                async with client.stream("GET", url, params=params) as response:
                    if response.status_code in (429, 503):
                        cooldown = 300
                        retry = response.headers.get("Retry-After", "")
                        if retry.isdigit():
                            cooldown = max(cooldown, min(int(retry), 86400))
                        _backoff_until[kind] = time.monotonic() + cooldown
                    response.raise_for_status()
                    body = bytearray()
                    async for part in response.aiter_bytes(chunk_size=65_536):
                        body.extend(part)
                        if len(body) > 1_000_000:
                            raise ValueError("OFF response exceeds the field projection limit")
                return json.loads(body)
    except (httpx.HTTPError, TimeoutError, ValueError, TypeError, UnicodeError) as error:
        # No user-entered text, provider body, auth token or database URL.
        logger.warning("UK OFF %s unavailable (%s)", kind, type(error).__name__)
        return None
    finally:
        _active[kind] -= 1


def _uk_hit(raw):
    return (isinstance(raw, dict)
        and isinstance(raw.get("countries_tags"), list)
        and "en:united-kingdom" in raw["countries_tags"]
        and raw.get("obsolete") not in (True, 1, "1", "on"))


async def search_uk_index(query, *, limit):
    from app.services.barcode_lookup import _result_from_off_product, normalize_barcode

    # Use the documented `fixed_field:"value" free text` form. The deployed
    # parser returns no full-text hits inside parentheses/quoted phrases.
    # Strip user punctuation and uppercase Lucene operators; the response
    # country check below is mandatory independently of provider filtering.
    terms = re.findall(r"\w+", query[:300].casefold(), flags=re.UNICODE)
    if not terms or type(limit) is not int or limit < 1:
        return []
    q = 'countries_tags:"en:united-kingdom" ' + " ".join(terms[:30])
    payload = await _get_json(SEARCH_URL, {
        "q": q, "langs": "en", "page": 1,
        "page_size": min(limit, 20), "fields": _FIELDS,
    }, kind="search")
    if (not isinstance(payload, dict) or not isinstance(payload.get("hits"), list)
            or payload.get("timed_out") is True or payload.get("errors")):
        return []
    results, seen = [], set()
    for raw in payload["hits"][:20]:
        if not _uk_hit(raw) or not isinstance(raw.get("code"), str):
            continue
        code = normalize_barcode(raw["code"])
        if code is None or code != raw["code"] or code.zfill(14) in seen:
            continue
        result = _result_from_off_product(raw, country_code="GB")
        if result is None or len(result.name) > 300 or len(result.brand or "") > 200:
            continue
        # Index projections may omit fields present in the full product API,
        # or lag behind it. Do not stamp these as today's full country proof.
        result.off_product = result.off_retrieved_at = None
        result.off_search_projection = True
        seen.add(code.zfill(14))
        results.append(result)
        if len(results) >= limit:
            break
    return results


async def verify_chosen_search_hit(item):
    """At most one exact read for a chosen ingredient; caller checks its name.

    Country evidence and nutrition come from this full response together, never
    from mixing an index revision with a newer fetch time or another SKU.
    """
    from app.services.barcode_lookup import (
        OFF_API_URLS, _product_from_off_response, _result_from_off_product,
        barcode_variants, normalize_barcode,
    )
    from app.services.off_catalogue import catalogue_values
    from datetime import datetime, timezone

    code = normalize_barcode(getattr(item, "barcode", None))
    if code is None:
        return None
    version, template = OFF_API_URLS[0]
    payload = await _get_json(template.format(barcode=code),
        {"cc": "uk", "lc": "en", "fields": _FIELDS}, kind="product")
    raw = _product_from_off_response(payload, version)
    now = datetime.now(timezone.utc)
    if (not _uk_hit(raw) or raw.get("code") not in barcode_variants(code)
            or catalogue_values(raw, retrieved_at=now) is None):
        return None
    result = _result_from_off_product(raw, country_code="GB")
    if result is not None:
        result.off_retrieved_at = now.isoformat()
    return result
