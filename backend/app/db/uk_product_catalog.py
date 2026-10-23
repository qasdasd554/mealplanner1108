"""Validated, deterministic UK catalogue proposals; NEVER a stock seed.

The current StoreProduct cannot retain local SKU/pack or price provenance.
Consequently this module only prepares a dry-run proposal and deliberately
blocks persistence. It is not called during startup and performs no network IO.
Retailer catalogue evidence is not proof of stock in every physical branch.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any, Iterable, Literal, Mapping
from urllib.parse import urlsplit
from uuid import UUID, uuid5

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.db.uk_store_catalog import UK_STORES


# Explicitly reviewed retailer domains. A matching host is a validation guard,
# not independent verification that the submitted observation is true.
_RETAILER_DOMAINS: Mapping[str, tuple[str, ...]] = {
    "tesco": ("tesco.com",),
    "sainsburys": ("sainsburys.co.uk",),
    "asda": ("asda.com",),
    "aldi": ("aldi.co.uk",),
    "morrisons": ("morrisons.com",),
    "lidl": ("lidl.co.uk",),
    "co-op": ("coop.co.uk",),
    "waitrose": ("waitrose.com",),
    "iceland": ("iceland.co.uk",),
    "ocado": ("ocado.com",),
}
_STORES_BY_SLUG = {store.slug: store for store in UK_STORES}

WRITE_BLOCKERS: tuple[str, ...] = (
    "StoreProduct has no persisted UK retailer SKU and per-SKU pack quantity/unit.",
    "StoreProduct has no persisted source URL, observed date and availability scope.",
    "StoreProduct has no persisted observed/estimate price flag, source and estimate reason.",
    "StoreProduct is unique by store/product, not by retailer SKU; do not overwrite another pack.",
)


class _FrozenInput(BaseModel):
    model_config = ConfigDict(
        extra="forbid", frozen=True, str_strip_whitespace=True,
        revalidate_instances="always",
    )


class CatalogueEvidence(_FrozenInput):
    """A dated source to be manually checked; never fetched by the importer."""

    url: str = Field(min_length=1, max_length=1000)
    publisher: str = Field(min_length=1, max_length=200)
    checked_on: date

    @field_validator("url")
    @classmethod
    def public_https_url(cls, value: str) -> str:
        parsed = urlsplit(value)
        if (
            parsed.scheme != "https"
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
            or parsed.fragment
            or parsed.port not in (None, 443)
        ):
            raise ValueError("Evidence must use an HTTPS URL without credentials or fragments")
        return value


def _exact_decimal(value: Any) -> Any:
    # JSON prices/weights use decimal strings, never binary float rounding.
    if isinstance(value, (bool, float)):
        raise ValueError("Use an exact decimal string or Decimal, not bool/float")
    return value


class UKPackage(_FrozenInput):
    quantity: Decimal = Field(gt=0, max_digits=9, decimal_places=3)
    unit: Literal["g", "ml"]
    source: CatalogueEvidence

    _exact_quantity = field_validator("quantity", mode="before")(_exact_decimal)

    @field_validator("quantity")
    @classmethod
    def normalise_quantity(cls, value: Decimal) -> Decimal:
        return value.normalize()


class UKPrice(_FrozenInput):
    amount: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    currency_code: Literal["GBP"] = "GBP"
    kind: Literal["observed", "estimate"]
    source: CatalogueEvidence
    estimate_reason: str | None = Field(default=None, min_length=10, max_length=1000)

    _exact_amount = field_validator("amount", mode="before")(_exact_decimal)

    @field_validator("amount")
    @classmethod
    def normalise_amount(cls, value: Decimal) -> Decimal:
        return value.quantize(Decimal("0.01"))

    @model_validator(mode="after")
    def explain_estimate(self) -> UKPrice:
        if self.kind == "estimate" and not self.estimate_reason:
            raise ValueError("An estimated GBP price requires an explicit local estimate reason")
        if self.kind == "observed" and self.estimate_reason is not None:
            raise ValueError("An observed price must not carry an estimate reason")
        return self


class UKProductProposal(_FrozenInput):
    """One independently evidenced local SKU, not an all-stores declaration."""

    country_code: Literal["GB"] = "GB"
    retailer_slug: str
    retailer_sku: str = Field(min_length=1, max_length=150, pattern=r"^[A-Za-z0-9._-]+$")
    canonical_product_id: UUID
    name_en: str = Field(min_length=1, max_length=300)
    package: UKPackage
    price: UKPrice
    availability_scope: Literal["online_catalogue"] = "online_catalogue"
    availability_status: Literal["available_online", "out_of_stock", "unknown"]
    availability_source: CatalogueEvidence

    @model_validator(mode="after")
    def require_specific_retailer_evidence(self) -> UKProductProposal:
        if self.retailer_slug not in _STORES_BY_SLUG:
            raise ValueError("Unknown UK retailer slug")
        for source in self.sources:
            host = urlsplit(source.url).hostname or ""
            if not any(
                host == domain or host.endswith("." + domain)
                for domain in _RETAILER_DOMAINS[self.retailer_slug]
            ):
                raise ValueError("Pack, price and listing evidence must belong to this UK retailer")
        return self

    @property
    def sources(self) -> tuple[CatalogueEvidence, ...]:
        return self.package.source, self.price.source, self.availability_source

    @property
    def store_id(self) -> UUID:
        return _STORES_BY_SLUG[self.retailer_slug].id

    @property
    def proposal_id(self) -> UUID:
        return uuid5(self.store_id, f"product-sku:{self.retailer_sku}")

    @property
    def fingerprint(self) -> str:
        payload = json.dumps(
            self.model_dump(mode="json"), sort_keys=True, separators=(",", ":"),
            ensure_ascii=False,
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()


class CanonicalProductReference(_FrozenInput):
    """Read-only catalogue snapshot, not a new Product or translated overwrite."""

    product_id: UUID
    base_unit: Literal["g", "ml"]
    review_status: Literal["approved", "pending", "rejected"]


@dataclass(frozen=True, slots=True)
class ProposedCatalogueAction:
    proposal: UKProductProposal
    action: Literal["new_proposal", "revise_proposal", "unchanged"]


@dataclass(frozen=True, slots=True)
class UKCataloguePlan:
    actions: tuple[ProposedCatalogueAction, ...]
    as_of: date
    write_blockers: tuple[str, ...] = WRITE_BLOCKERS

    @property
    def can_write(self) -> bool:
        return False


def plan_uk_product_catalogue(
    rows: Iterable[UKProductProposal | Mapping[str, Any]],
    *,
    canonical_products: Mapping[UUID, CanonicalProductReference],
    as_of: date,
    previous_fingerprints: Mapping[UUID, str] | None = None,
    max_evidence_age_days: int = 30,
) -> UKCataloguePlan:
    """Validate the whole batch before returning a sorted, idempotent dry-run.

    Identical duplicates collapse; conflicting duplicates fail the whole batch.
    Price is PER THE QUOTED LOCAL PACKAGE, never per canonical Polish package.
    A caller must explicitly provide canonical IDs and g/ml dimension; no name
    similarity matching, g/ml density conversion or fallback package of 100.
    Previous fingerprints refer to reviewed PROPOSALS, not active stock rows.
    """
    if type(max_evidence_age_days) is not int or not 1 <= max_evidence_age_days <= 365:
        raise ValueError("Evidence freshness must be between 1 and 365 days")
    previous = previous_fingerprints or {}
    for fingerprint in previous.values():
        if re.fullmatch(r"[0-9a-f]{64}", fingerprint) is None:
            raise ValueError("Previous fingerprints must be lowercase SHA-256 digests")

    unique: dict[UUID, UKProductProposal] = {}
    for row in rows:
        proposal = UKProductProposal.model_validate(row)
        canonical = canonical_products.get(proposal.canonical_product_id)
        if canonical is None or canonical.product_id != proposal.canonical_product_id:
            raise ValueError("An explicit existing canonical product mapping is required")
        if canonical.review_status != "approved":
            raise ValueError("A UK catalogue proposal must map to an approved canonical product")
        if canonical.base_unit != proposal.package.unit:
            raise ValueError("UK pack dimension differs from canonical g/ml dimension")
        for source in proposal.sources:
            age = (as_of - source.checked_on).days
            if age < 0 or age > max_evidence_age_days:
                raise ValueError("Evidence is future-dated or too old for this import review")
        existing = unique.get(proposal.proposal_id)
        if existing is not None and existing != proposal:
            raise ValueError("Conflicting observations for the same retailer SKU")
        unique[proposal.proposal_id] = proposal

    actions = []
    for identifier in sorted(unique, key=str):
        proposal = unique[identifier]
        old_fingerprint = previous.get(identifier)
        action = (
            "unchanged" if old_fingerprint == proposal.fingerprint else
            "revise_proposal" if old_fingerprint is not None else
            "new_proposal"
        )
        actions.append(ProposedCatalogueAction(proposal=proposal, action=action))
    return UKCataloguePlan(actions=tuple(actions), as_of=as_of)


class UKCatalogueWriteBlocked(RuntimeError):
    """Raised before a session can be touched or partial data can be persisted."""


async def apply_uk_product_catalogue(session: Any, plan: UKCataloguePlan) -> None:
    """Intentionally unavailable until SKU/provenance schema is implemented.

    No session call, add, flush, execute or commit is made, even for an empty
    plan. Do not bypass this by constructing StoreProduct rows from proposals.
    """
    raise UKCatalogueWriteBlocked("UK catalogue is dry-run only: " + " ".join(WRITE_BLOCKERS))
