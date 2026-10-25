"""Small admin-initiated refresh of existing reviewed UK price observations.

Never a public-user importer, a catalogue crawl or an identity approval. It
reuses the current authenticated admin and a previously reviewed as-sold SKU.
HTTP occurs after the catalogue response and outside every DB transaction.
"""

import asyncio
from collections import OrderedDict, deque
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import json
import logging
from types import SimpleNamespace
import time
from uuid import UUID

import httpx
from sqlalchemy import select

from app.db.uk_store_catalog import UK_STORES
from app.models import OffCatalogueProduct, OffIngredientMapping, Product, RegionalProductOffer, User
from app.services.barcode_lookup import USER_AGENT
from app.services.off_on_demand import refresh_requested_off_product
from app.services.open_prices_reference import prepare_open_prices_reference, community_price_proposal
from app.services.regional_offer_pricing import reviewed_uk_offer
from app.services.uk_catalogue_import import import_reviewed_uk_catalogue, _normalised_utc


logger = logging.getLogger(__name__)
_active: set[UUID] = set()
_attempts: OrderedDict[UUID, float] = OrderedDict()
_offer_attempts: OrderedDict[UUID, float] = OrderedDict()
_window: deque[float] = deque()
_backoff_until = 0.0
_client_factory = httpx.AsyncClient
_STORES = {row.id for row in UK_STORES}
_URL = "https://prices.openfoodfacts.org/api/v1/prices"


def _session_factory():
    from app.db.session import async_session_factory
    return async_session_factory()


def _snapshot(obj, fields):
    return SimpleNamespace(**{name: getattr(obj, name) for name in fields.split()})


async def _identity(proposal, clock):
    async with _session_factory() as session:
        product = await session.get(Product, proposal.canonical_product_id)
        link = await session.get(OffIngredientMapping,
            (proposal.canonical_product_id, proposal.price.source.product_code))
        off = await session.get(OffCatalogueProduct, proposal.price.source.product_code)
        if (product is None or link is None or off is None
                or link.off_fingerprint != proposal.price.source.off_fingerprint
                or off.fingerprint != proposal.price.source.off_fingerprint
                or _normalised_utc(link.reviewed_at) > clock):
            return None
        mapping = {name: getattr(link, name) for name in (
            "product_id", "product_name", "product_unit", "product_brand", "off_barcode",
            "off_fingerprint", "review_note", "country_code")}
        return (mapping, _snapshot(off,
            "barcode name country_code licence source_url fingerprint retrieved_at base_unit package_quantity"),
            _snapshot(product, "id name brand unit review_status created_by_user_id barcode measure_options"))


async def _observations(code, clock):
    global _backoff_until
    async with _client_factory(timeout=4, follow_redirects=False,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"}) as client:
        async with client.stream("GET", _URL, params={"product_code": code, "currency": "GBP",
            "date__gte": (clock.date() - timedelta(days=30)).isoformat(), "date__lte": clock.date().isoformat(),
            "price_is_discounted": "false", "type": "PRODUCT", "product__source": "off",
            "page": "1", "size": "10", "order_by": "-date,-id"}) as response:
            if response.status_code in (429, 503):
                _backoff_until = time.monotonic() + 300
            response.raise_for_status()
            body = bytearray()
            async for chunk in response.aiter_bytes(chunk_size=65_536):
                body.extend(chunk)
                if len(body) > 1_000_000:
                    raise ValueError("Price response exceeded the small product sample")
    payload = json.loads(body, parse_float=Decimal)
    rows = payload.get("items") if isinstance(payload, dict) else None
    if not isinstance(rows, list) or len(rows) > 10:
        raise ValueError("Expected one bounded Open Prices page")
    return rows


async def refresh_reviewed_store_prices(store_id: UUID, reviewer_user_id: UUID,
                                        *, now: datetime | None = None) -> str:
    """At most one existing offer per call; recheck admin and source at commit.

    The caller supplies the CURRENT authenticated administrator, never a saved
    reviewer ID impersonated for an ordinary user's request. All other offer,
    approval, food and source checks still run in the existing atomic importer.
    """
    if store_id not in _STORES or not isinstance(reviewer_user_id, UUID):
        return "forbidden"
    tick = time.monotonic()
    if store_id in _active or tick - _attempts.get(store_id, -1e12) < 300:
        return "cooldown"
    if tick < _backoff_until or len(_active) >= 2:
        return "backoff"
    _active.add(store_id)
    _attempts[store_id] = tick
    while len(_attempts) > 32:
        _attempts.popitem(last=False)
    try:
        async with asyncio.timeout(14):
            clock = now or datetime.now(timezone.utc)
            if clock.tzinfo is None or clock.utcoffset() != timedelta(0):
                raise ValueError("An explicit UTC refresh clock is required")
            recent = [key for key, value in _offer_attempts.items() if tick - value < 6 * 3600]
            async with _session_factory() as session:
                actor = (await session.execute(select(User.role, User.is_banned)
                    .where(User.id == reviewer_user_id))).one_or_none()
                if actor is None or actor.role != "admin" or actor.is_banned:
                    return "forbidden"
                offer = (await session.execute(select(RegionalProductOffer).where(
                    RegionalProductOffer.store_id == store_id, RegionalProductOffer.country_code == "GB",
                    RegionalProductOffer.currency_code == "GBP",
                    RegionalProductOffer.availability_scope == "store_observation",
                    RegionalProductOffer.price_source["provider"].as_string() == "open_prices",
                    RegionalProductOffer.id.not_in(recent),
                ).order_by(RegionalProductOffer.reviewed_at, RegionalProductOffer.id).limit(1))).scalar_one_or_none()
                if offer is None or _normalised_utc(offer.reviewed_at) > clock:
                    return "no_reviewed_offer"
                # Verify the ORIGINAL approval, not a claim that its old price
                # is still current. Fresh evidence is independently required below.
                original = reviewed_uk_offer(offer, as_of=_normalised_utc(offer.reviewed_at).date())
                if original is None or original.availability_scope != "store_observation":
                    return "no_reviewed_offer"
                expected_fingerprint = offer.fingerprint
            _offer_attempts[original.proposal_id] = tick
            while len(_offer_attempts) > 256:
                _offer_attempts.popitem(last=False)
            await refresh_requested_off_product(original.price.source.product_code, now=clock)
            identity = await _identity(original, clock)
            if identity is None:
                return "no_identity"
            tick = time.monotonic()
            while _window and tick - _window[0] >= 60:
                _window.popleft()
            if len(_window) >= 6 or tick < _backoff_until:
                return "backoff"
            _window.append(tick)
            candidates = []
            for row in await _observations(original.price.source.product_code, clock):
                try:
                    reference = prepare_open_prices_reference(row, mapping=identity[0], off_product=identity[1],
                        canonical_product=identity[2], as_of=clock.date())
                    candidate = community_price_proposal(reference,
                        package_basis_note=original.price.source.package_basis_note)
                    if (candidate.store_id != original.store_id or candidate.proposal_id != original.proposal_id
                            or candidate.package.quantity != original.package.quantity
                            or candidate.package.unit != original.package.unit
                            or (candidate.price.source.checked_on, candidate.price.source.observation_id)
                               < (original.price.source.checked_on, original.price.source.observation_id)):
                        continue
                    candidates.append(candidate)
                except (ValueError, TypeError):
                    continue
            if not candidates:
                return "no_valid_price"
            newest = max(candidates, key=lambda value: (value.price.source.checked_on,
                value.price.source.observation_id))  # Never cherry-pick the cheapest branch.
            async with _session_factory() as session:
                result = await import_reviewed_uk_catalogue(session, [newest], reviewer_user_id=reviewer_user_id,
                    reviewed_at=clock, as_of=clock.date(), expected_fingerprints={original.proposal_id: expected_fingerprint})
                await session.commit()
            return "updated" if result.updated else "unchanged"
    except Exception as error:
        logger.warning("UK reviewed price refresh skipped (%s)", type(error).__name__)
        return "unavailable"
    finally:
        _active.discard(store_id)
