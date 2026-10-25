"""Reviewed local SKU/pack evidence, separate from the legacy Polish catalogue."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    JSON, CheckConstraint, DateTime, ForeignKey, Index, Numeric, String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class RegionalProductOffer(Base):
    """One reviewed retailer SKU, not stock guaranteed in every local branch.

    Canonical Product nutrition/default quantities and StoreProduct rows are
    intentionally unchanged. A SKU's price is for its quoted local package.
    Source JSONs contain url, publisher and checked_on (an ISO date).
    """

    __tablename__ = "regional_product_offers"
    __table_args__ = (
        UniqueConstraint("store_id", "retailer_sku", name="uq_regional_offer_store_sku"),
        CheckConstraint("country_code = 'GB' AND currency_code = 'GBP'", name="ck_regional_offer_market"),
        CheckConstraint("package_unit IN ('g', 'ml')", name="ck_regional_offer_package_unit"),
        CheckConstraint("package_quantity > 0 AND package_quantity <= 999999.999", name="ck_regional_offer_package_quantity"),
        CheckConstraint("price > 0 AND price <= 99999999.99", name="ck_regional_offer_price"),
        CheckConstraint("price_kind IN ('observed', 'estimate')", name="ck_regional_offer_price_kind"),
        CheckConstraint(
            "(price_kind = 'observed' AND estimate_reason IS NULL) OR "
            "(price_kind = 'estimate' AND estimate_reason IS NOT NULL "
            "AND length(trim(estimate_reason)) BETWEEN 10 AND 1000)",
            name="ck_regional_offer_estimate_reason",
        ),
        CheckConstraint(
            "availability_status IN ('available_online', 'out_of_stock', 'unknown', 'reported_available')",
            name="ck_regional_offer_availability_status",
        ),
        CheckConstraint("availability_scope IN ('online_catalogue', 'store_observation', 'user_submission')", name="ck_regional_offer_availability_scope"),
        CheckConstraint(
            "(availability_scope = 'online_catalogue' AND availability_status IN ('available_online', 'out_of_stock', 'unknown')) OR "
            "(availability_scope IN ('store_observation', 'user_submission') AND availability_status = 'reported_available' AND price_kind = 'estimate')",
            name="ck_regional_offer_evidence_kind",
        ),
        CheckConstraint(
            "availability_scope <> 'user_submission' OR (availability_status = 'reported_available' AND price_kind = 'estimate')",
            name="ck_regional_offer_submission_evidence",
        ),
        CheckConstraint("length(trim(retailer_sku)) BETWEEN 1 AND 150 AND retailer_sku = trim(retailer_sku)", name="ck_regional_offer_sku"),
        CheckConstraint("length(trim(name_en)) BETWEEN 1 AND 300", name="ck_regional_offer_name"),
        CheckConstraint("length(fingerprint) = 64 AND fingerprint = lower(fingerprint)", name="ck_regional_offer_fingerprint"),
        Index("ix_regional_offer_product_store", "product_id", "store_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("stores.id", ondelete="CASCADE"), nullable=False,
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False,
    )
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False)
    retailer_sku: Mapped[str] = mapped_column(String(150), nullable=False)
    name_en: Mapped[str] = mapped_column(String(300), nullable=False)
    package_quantity: Mapped[Decimal] = mapped_column(Numeric(9, 3), nullable=False)
    package_unit: Mapped[str] = mapped_column(String(2), nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    price_kind: Mapped[str] = mapped_column(String(8), nullable=False)
    estimate_reason: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    package_source: Mapped[dict] = mapped_column(JSON(none_as_null=True), nullable=False)
    price_source: Mapped[dict] = mapped_column(JSON(none_as_null=True), nullable=False)
    availability_source: Mapped[dict] = mapped_column(JSON(none_as_null=True), nullable=False)
    availability_status: Mapped[str] = mapped_column(String(20), nullable=False)
    availability_scope: Mapped[str] = mapped_column(String(20), nullable=False)
    reviewed_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
    )
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)

    def __repr__(self) -> str:
        return f"<RegionalProductOffer {self.store_id} {self.retailer_sku!r}>"
