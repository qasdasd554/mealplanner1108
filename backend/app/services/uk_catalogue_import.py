"""Explicit administrator-reviewed UK catalogue write; never a startup seed.

Only RegionalProductOffer is mutated. A caller owns the surrounding transaction
and its commit. Each batch uses one savepoint, with no partial batch on failure.
The legacy apply_uk_product_catalogue entry point remains deliberately blocked.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Iterable, Mapping
from uuid import UUID

from sqlalchemy import or_, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.uk_product_catalog import (
    CanonicalProductReference, UKProductProposal, plan_uk_product_catalogue,
)
from app.models.product import Product
from app.models.regional_product_offer import RegionalProductOffer
from app.models.store import Store
from app.models.user import User


class UKCataloguePermissionError(PermissionError):
    """The reviewer is not an unbanned administrator fetched from this DB."""


@dataclass(frozen=True, slots=True)
class UKCatalogueImportResult:
    created: int
    updated: int
    unchanged: int
    offer_ids: tuple[UUID, ...]


def canonical_base_unit(product: Product) -> str:
    """Require a persisted dimension; never infer g/ml from a translated name."""
    unit = (product.unit or "").strip().lower()
    direct = {"g": "g", "kg": "g", "ml": "ml", "l": "ml"}.get(unit)
    option_units = {
        option.get("base_unit")
        for option in (product.measure_options or [])
        if isinstance(option, dict) and option.get("base_unit") in {"g", "ml"}
    }
    if len(option_units) > 1 or (direct and option_units and option_units != {direct}):
        raise ValueError("Canonical product has conflicting g/ml dimensions")
    if direct:
        return direct
    if unit in {"opak", "opakowanie", "szt", "szt."} and len(option_units) == 1:
        return next(iter(option_units))
    raise ValueError("Canonical product needs an explicit unambiguous g/ml dimension")


def _review_clock(reviewed_at: datetime, as_of: date) -> datetime:
    if (
        not isinstance(reviewed_at, datetime)
        or reviewed_at.tzinfo is None
        or reviewed_at.utcoffset() != timedelta(0)
    ):
        raise ValueError("reviewed_at must be a timezone-aware UTC datetime")
    if type(as_of) is not date or as_of != reviewed_at.date():
        raise ValueError("as_of must be the UTC date of reviewed_at")
    return reviewed_at.astimezone(timezone.utc)


def _offer_values(proposal: UKProductProposal, reviewer: UUID, reviewed_at: datetime) -> dict[str, Any]:
    return {
        "store_id": proposal.store_id,
        "product_id": proposal.canonical_product_id,
        "country_code": "GB",
        "currency_code": "GBP",
        "retailer_sku": proposal.retailer_sku,
        "name_en": proposal.name_en,
        "package_quantity": proposal.package.quantity,
        "package_unit": proposal.package.unit,
        "price": proposal.price.amount,
        "price_kind": proposal.price.kind,
        "estimate_reason": proposal.price.estimate_reason,
        "package_source": proposal.package.source.model_dump(mode="json"),
        "price_source": proposal.price.source.model_dump(mode="json"),
        "availability_source": proposal.availability_source.model_dump(mode="json"),
        "availability_status": proposal.availability_status,
        "availability_scope": proposal.availability_scope,
        "reviewed_by_user_id": reviewer,
        "reviewed_at": reviewed_at,
        "fingerprint": proposal.fingerprint,
    }


def _normalised_utc(value: datetime) -> datetime:
    # SQLite loses offsets when round-tripping DateTime(timezone=True); this
    # tolerance is for existing DB rows only, never for the input review clock.
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


async def import_reviewed_uk_catalogue(
    session: AsyncSession,
    rows: Iterable[UKProductProposal | Mapping[str, Any]],
    *,
    reviewer_user_id: UUID,
    reviewed_at: datetime,
    as_of: date,
    max_evidence_age_days: int = 30,
) -> UKCatalogueImportResult:
    """Validate and atomically stage a reviewed batch; caller must commit.

    The caller supplies the authenticated reviewer ID, not a client-selected
    ID or User.role object. Admin role/ban state is re-read and locked in DB.
    Input dates are explicit trusted server review metadata, not client claims.
    A clean unit-of-work is required because begin_nested flushes pending work.
    Store row locks serialize competing imports for the same retailer in PG;
    store IDs are locked in deterministic order. No all-stores stock is added.
    """
    review_time = _review_clock(reviewed_at, as_of)
    if not isinstance(reviewer_user_id, UUID):
        raise ValueError("reviewer_user_id must be an authenticated UUID")
    if session.new or session.dirty or session.deleted:
        raise ValueError("UK catalogue import requires a clean session unit-of-work")
    proposals = tuple(UKProductProposal.model_validate(row) for row in rows)
    identifiers = {row.canonical_product_id for row in proposals}
    store_ids = {row.store_id for row in proposals}

    async with session.begin_nested():
        reviewer = (await session.execute(
            select(User.id, User.role, User.is_banned)
            .where(User.id == reviewer_user_id)
            .with_for_update()
        )).one_or_none()
        if reviewer is None or reviewer.role != "admin" or reviewer.is_banned:
            raise UKCataloguePermissionError("An unbanned database administrator must review this import")

        # Acquire store locks first, ordered for overlapping concurrent batches.
        stores = (await session.scalars(
            select(Store).where(Store.id.in_(store_ids)).order_by(Store.id)
            .with_for_update().execution_options(populate_existing=True)
        )).all() if store_ids else []
        by_store = {store.id: store for store in stores}
        if any(
            identifier not in by_store
            or by_store[identifier].country_code != "GB"
            or by_store[identifier].currency_code != "GBP"
            for identifier in store_ids
        ):
            raise ValueError("Every proposed retailer must exist in DB as GB/GBP")

        products = (await session.scalars(
            select(Product).where(Product.id.in_(identifiers)).order_by(Product.id)
            .with_for_update().execution_options(populate_existing=True)
        )).all() if identifiers else []
        references = {
            product.id: CanonicalProductReference(
                product_id=product.id,
                base_unit=canonical_base_unit(product),
                review_status=product.review_status,
            )
            for product in products
        }
        plan = plan_uk_product_catalogue(
            proposals, canonical_products=references, as_of=as_of,
            max_evidence_age_days=max_evidence_age_days,
        )

        # Complete all identity/conflict validation before mutating any offer.
        keys = {(action.proposal.store_id, action.proposal.retailer_sku) for action in plan.actions}
        offer_ids = {action.proposal.proposal_id for action in plan.actions}
        existing = (await session.scalars(
            select(RegionalProductOffer).where(or_(
                tuple_(RegionalProductOffer.store_id, RegionalProductOffer.retailer_sku).in_(keys),
                RegionalProductOffer.id.in_(offer_ids),
            ))
            .with_for_update().execution_options(populate_existing=True)
        )).all() if keys else []
        by_key = {(offer.store_id, offer.retailer_sku): offer for offer in existing}
        by_id = {offer.id: offer for offer in existing}
        for action in plan.actions:
            proposal = action.proposal
            offer = by_key.get((proposal.store_id, proposal.retailer_sku))
            if offer is not None and offer.id != proposal.proposal_id:
                raise ValueError("Existing retailer SKU has a conflicting deterministic offer ID")
            collision = by_id.get(proposal.proposal_id)
            if collision is not None and collision is not offer:
                raise ValueError("Deterministic offer ID belongs to a different retailer SKU")
            if offer is not None and review_time < _normalised_utc(offer.reviewed_at):
                raise ValueError("An older review cannot overwrite a newer catalogue review")

        created = updated = unchanged = 0
        for action in plan.actions:
            proposal = action.proposal
            offer = by_key.get((proposal.store_id, proposal.retailer_sku))
            values = _offer_values(proposal, reviewer_user_id, review_time)
            same_content = offer is not None and all(
                getattr(offer, key) == value
                for key, value in values.items()
                if key not in {"reviewed_at", "reviewed_by_user_id"}
            )
            if same_content:
                unchanged += 1
                continue
            if offer is None:
                session.add(RegionalProductOffer(id=proposal.proposal_id, **values))
                created += 1
            else:
                for key, value in values.items():
                    setattr(offer, key, value)
                updated += 1
        await session.flush()
        return UKCatalogueImportResult(
            created=created, updated=updated, unchanged=unchanged,
            offer_ids=tuple(action.proposal.proposal_id for action in plan.actions),
        )
