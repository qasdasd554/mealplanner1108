"""Explicit reviewed OFF links for generic ingredients; no network or commits.

The trusted import caller must inspect the label/food identity. A name match,
English translation or a model-generated suggestion is not a review. Links
only establish OFF-reported UK sale, never retailer stock, prices or quantities.
"""

from dataclasses import dataclass
from datetime import date, datetime
from itertools import islice
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, tuple_

from app.models.off_catalogue_product import OffCatalogueProduct
from app.models.off_ingredient_mapping import OffIngredientMapping
from app.models.product import Product
from app.models.user import User
from app.services.off_availability import off_uk_evidence_conditions
from app.services.system_content_language import is_system_ingredient
from app.services.uk_catalogue_import import _normalised_utc, _review_clock, canonical_base_unit


class OffMappingProposal(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, str_strip_whitespace=True)

    product_id: UUID
    product_name: str = Field(min_length=1, max_length=300)
    product_unit: str = Field(min_length=1, max_length=20)
    product_brand: str | None = Field(default=None, max_length=200)
    off_barcode: str = Field(pattern=r"^[0-9]{8,14}$")
    off_fingerprint: str = Field(pattern=r"^[0-9a-f]{64}$")
    review_note: str = Field(min_length=10, max_length=1000)
    country_code: Literal["GB"] = "GB"


@dataclass(frozen=True)
class OffMappingImportResult:
    created: int
    updated: int
    unchanged: int


async def import_reviewed_off_mappings(session, rows, *, reviewer_user_id: UUID,
                                       reviewed_at: datetime, as_of: date) -> OffMappingImportResult:
    """Bounded atomic review of already-used OFF cache entries, not an importer.

    Caller owns the outer transaction. Lock canonical products deterministically
    so two reviewers cannot race on the same link. Never create Product, OFF
    facts, offers or prices, and never manufacture a code for a generic food.
    """
    now = _review_clock(reviewed_at, as_of)
    if not isinstance(reviewer_user_id, UUID):
        raise ValueError("An authenticated reviewer UUID is required")
    if session.new or session.dirty or session.deleted:
        raise ValueError("OFF mapping review requires a clean session")
    bounded = tuple(islice(rows, 501))
    if len(bounded) > 500:
        raise ValueError("Review at most 500 links per batch")
    proposals = tuple(OffMappingProposal.model_validate(row) for row in bounded)
    keys = {(row.product_id, row.off_barcode) for row in proposals}
    if len(keys) != len(proposals):
        raise ValueError("Duplicate ingredient/OFF links in review batch")

    async with session.begin_nested():
        reviewer = (await session.execute(select(User.id, User.role, User.is_banned)
            .where(User.id == reviewer_user_id).with_for_update())).one_or_none()
        if reviewer is None or reviewer.role != "admin" or reviewer.is_banned:
            raise PermissionError("An unbanned database administrator must review OFF links")
        ids = {row.product_id for row in proposals}
        codes = {row.off_barcode for row in proposals}
        products = (await session.scalars(select(Product).where(Product.id.in_(ids))
            .order_by(Product.id).with_for_update().execution_options(populate_existing=True))).all()
        by_id = {row.id: row for row in products}
        evidence = (await session.scalars(select(OffCatalogueProduct).where(
            OffCatalogueProduct.barcode.in_(codes), *off_uk_evidence_conditions(as_of=as_of))
            .order_by(OffCatalogueProduct.barcode).with_for_update()
            .execution_options(populate_existing=True))).all()
        by_code = {row.barcode: row for row in evidence}
        mappings = (await session.scalars(select(OffIngredientMapping).where(
            tuple_(OffIngredientMapping.product_id, OffIngredientMapping.off_barcode).in_(keys))
            .with_for_update().execution_options(populate_existing=True))).all() if keys else []
        existing = {(row.product_id, row.off_barcode): row for row in mappings}
        staged = []
        for row in proposals:
            product, off = by_id.get(row.product_id), by_code.get(row.off_barcode)
            if (product is None or product.created_by_user_id is not None
                    or product.review_status != "approved" or product.barcode is not None
                    or ((product.brand or "").strip() and not is_system_ingredient(product))):
                raise ValueError("Only approved generic system ingredients can be linked; branded SKUs are excluded")
            # Legacy seed foods carry Polish example brands, although their IDs
            # represent generic recipe ingredients. Keep those facts unchanged;
            # a reviewed link only attests UK sale of the generic food concept.
            if (product.name != row.product_name or product.unit != row.product_unit
                    or product.brand != row.product_brand):
                raise ValueError("Canonical ingredient identity changed since review")
            if (off is None or off.fingerprint != row.off_fingerprint
                    or _normalised_utc(off.retrieved_at) > now
                    or canonical_base_unit(product) != off.base_unit):
                raise ValueError("Fresh compatible UK OFF evidence matching this review is required")
            current = existing.get((row.product_id, row.off_barcode))
            if current is not None and _normalised_utc(current.reviewed_at) > now:
                raise ValueError("An older review cannot overwrite a newer OFF link")
            values = dict(country_code="GB", product_name=product.name,
                product_brand=product.brand,
                product_unit=product.unit, base_unit=off.base_unit, off_fingerprint=off.fingerprint,
                review_note=row.review_note, reviewed_at=now, reviewed_by_user_id=reviewer_user_id)
            staged.append((row, current, values))
        created = updated = unchanged = 0
        for row, current, values in staged:
            if current is None:
                session.add(OffIngredientMapping(product_id=row.product_id,
                    off_barcode=row.off_barcode, **values))
                created += 1
            elif all((_normalised_utc(getattr(current, key)) if key == "reviewed_at"
                      else getattr(current, key)) == value for key, value in values.items()):
                unchanged += 1
            else:
                for key, value in values.items():
                    setattr(current, key, value)
                updated += 1
        await session.flush()
        return OffMappingImportResult(created, updated, unchanged)
