"""Exact UK package quotes, independent of Polish default package quantities.

This pure, non-network calculator does not mutate products, rates or stock.
The GB plan/list/comparison paths use it with persisted local SKU snapshots;
the legacy Polish costing path remains separate and unchanged.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Iterable
from uuid import UUID

from pydantic import ValidationError

from app.db.uk_product_catalog import UKProductProposal
from app.db.uk_store_catalog import UK_STORES


_STORE_SLUGS = {store.id: store.slug for store in UK_STORES}
_MAX_BASE_QUANTITY = Decimal("1000000000")


def _positive_decimal(value: Any) -> Decimal:
    if isinstance(value, (bool, float)) or value is None:
        raise ValueError("An exact positive decimal quantity is required")
    try:
        amount = Decimal(value)
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise ValueError("An exact positive decimal quantity is required") from exc
    if not amount.is_finite() or amount <= 0:
        raise ValueError("Quantity must be finite and greater than zero")
    return amount


def normalize_requirement(quantity: Any, unit: str) -> tuple[Decimal, str]:
    """Only explicit mass/volume units; never infer a pack, piece or density.

    A caller needing cups/pieces/packs must first resolve a trusted product-
    specific measure, retaining its base dimension. Unknown is not 100 g.
    """
    amount = _positive_decimal(quantity)
    if unit not in {"g", "kg", "ml", "l"}:
        raise ValueError("A proven g/kg/ml/l requirement is required")
    if unit in {"kg", "l"}:
        # A decimal exponent shift is exact even beyond the active arithmetic
        # context precision. Multiplication could erase a small pack remainder.
        sign, digits, exponent = amount.as_tuple()
        amount = Decimal((sign, digits, exponent + 3))
    if amount > _MAX_BASE_QUANTITY:
        raise ValueError("Requirement exceeds the supported quantity range")
    return amount, "g" if unit in {"g", "kg"} else "ml"


@dataclass(frozen=True, slots=True)
class RegionalOfferQuote:
    offer_id: UUID
    store_id: UUID
    product_id: UUID
    name_en: str
    required_quantity: Decimal
    unit: str
    package_quantity: Decimal
    package_count: int
    purchased_quantity: Decimal
    price_per_package: Decimal
    total_price: Decimal
    currency_code: str
    price_is_estimated: bool
    last_verified: date | None
    price_source: dict[str, Any]
    availability_scope: str = "online_catalogue"
    availability_status: str = "available_online"


def reviewed_uk_offer(offer: Any, *, as_of: date, max_age: int = 30) -> UKProductProposal | None:
    """Do not trust a malformed/changed legacy row merely because it has an ID."""
    try:
        if offer.country_code != "GB" or offer.currency_code != "GBP":
            return None
        reviewed = offer.reviewed_at
        if not isinstance(reviewed, datetime):
            return None
        # PostgreSQL returns aware UTC. SQLite drops tzinfo on round-trip;
        # the writer only accepts UTC-aware input, so a naive DB value is UTC.
        reviewed_day = (
            reviewed.astimezone(timezone.utc).date() if reviewed.tzinfo else reviewed.date()
        )
        if reviewed_day > as_of:
            return None
        proposal = UKProductProposal.model_validate({
            "country_code": offer.country_code,
            "retailer_slug": _STORE_SLUGS.get(offer.store_id, ""),
            "retailer_sku": offer.retailer_sku,
            "canonical_product_id": offer.product_id,
            "name_en": offer.name_en,
            "package": {"quantity": offer.package_quantity, "unit": offer.package_unit,
                        "source": offer.package_source},
            "price": {"amount": offer.price, "kind": offer.price_kind,
                      "currency_code": offer.currency_code, "source": offer.price_source,
                      "estimate_reason": offer.estimate_reason},
            "availability_status": offer.availability_status,
            "availability_scope": offer.availability_scope,
            "availability_source": offer.availability_source,
        })
        if proposal.proposal_id != offer.id or proposal.fingerprint != offer.fingerprint:
            return None
        if (proposal.availability_scope, proposal.availability_status) not in {
                ("online_catalogue", "available_online"), ("store_observation", "reported_available"),
                ("user_submission", "reported_available")}:
            return None
        for source in proposal.sources:
            age = (as_of - source.checked_on).days
            if age < 0 or age > max_age or source.checked_on > reviewed_day:
                return None
        return proposal
    except (AttributeError, ValueError, TypeError, ValidationError):
        return None


def select_uk_offer_quote(
    offers: Iterable[Any], *, product_id: UUID, store_id: UUID,
    quantity: Any, unit: str, as_of: date, max_evidence_age_days: int = 30,
) -> RegionalOfferQuote | None:
    """Choose one SKU with the lowest cost of enough WHOLE local packages.

    Ties are deterministic. This deliberately does not solve combinations of
    different pack sizes, multipack deals or loyalty prices. Each quote uses
    one reviewed SKU; empty/mismatched/stale evidence yields None, not £0.
    Availability refers to the evidenced online catalogue, not every branch.
    """
    if type(as_of) is not date:
        raise ValueError("An explicit calendar date is required")
    if type(max_evidence_age_days) is not int or not 1 <= max_evidence_age_days <= 365:
        raise ValueError("Evidence freshness must be between 1 and 365 days")
    required, base_unit = normalize_requirement(quantity, unit)
    quotes: list[RegionalOfferQuote] = []
    for offer in offers:
        if getattr(offer, "store_id", None) != store_id or getattr(offer, "product_id", None) != product_id:
            continue
        proposal = reviewed_uk_offer(offer, as_of=as_of, max_age=max_evidence_age_days)
        if proposal is None or proposal.package.unit != base_unit:
            continue
        # Decimal division rounds to the arithmetic context *before* ceiling:
        # 500.000...0001 / 500 may become exactly 1. Use exact integer ratios so
        # even a tiny remainder always requires another whole package.
        required_numerator, required_denominator = required.as_integer_ratio()
        pack_numerator, pack_denominator = proposal.package.quantity.as_integer_ratio()
        numerator = required_numerator * pack_denominator
        denominator = required_denominator * pack_numerator
        count = (numerator + denominator - 1) // denominator
        total = (proposal.price.amount * count).quantize(Decimal("0.01"))
        if total > Decimal("99999999.99"):
            continue
        quotes.append(RegionalOfferQuote(
            offer_id=proposal.proposal_id, store_id=proposal.store_id,
            product_id=product_id, name_en=proposal.name_en,
            required_quantity=required, unit=base_unit,
            package_quantity=proposal.package.quantity, package_count=count,
            purchased_quantity=proposal.package.quantity * count,
            price_per_package=proposal.price.amount, total_price=total,
            currency_code="GBP", price_is_estimated=proposal.price.kind == "estimate",
            last_verified=proposal.price.source.checked_on if proposal.price.kind == "observed" else None,
            price_source=proposal.price.source.model_dump(mode="json"),
            availability_scope=proposal.availability_scope, availability_status=proposal.availability_status,
        ))
    return min(quotes, key=lambda value: (value.total_price, value.purchased_quantity, str(value.offer_id))) if quotes else None
