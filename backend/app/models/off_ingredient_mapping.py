"""Reviewed country-availability links, not product substitutions or shop stock."""

from datetime import datetime
from uuid import UUID as PyUUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class OffIngredientMapping(Base):
    __tablename__ = "off_ingredient_mappings"
    __table_args__ = (
        CheckConstraint("country_code = 'GB'", name="ck_off_mapping_country"),
        CheckConstraint("base_unit IN ('g', 'ml')", name="ck_off_mapping_dimension"),
        CheckConstraint("length(trim(product_name)) BETWEEN 1 AND 300", name="ck_off_mapping_name"),
        CheckConstraint("length(product_unit) BETWEEN 1 AND 20", name="ck_off_mapping_unit"),
        CheckConstraint("length(off_fingerprint) = 64 AND off_fingerprint = lower(off_fingerprint)",
            name="ck_off_mapping_fingerprint"),
        CheckConstraint("length(trim(review_note)) BETWEEN 10 AND 1000", name="ck_off_mapping_review"),
    )

    product_id: Mapped[PyUUID] = mapped_column(UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"), primary_key=True)
    off_barcode: Mapped[str] = mapped_column(String(14),
        ForeignKey("off_catalogue_products.barcode", ondelete="CASCADE"), primary_key=True, index=True)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    product_name: Mapped[str] = mapped_column(String(300), nullable=False)
    product_unit: Mapped[str] = mapped_column(String(20), nullable=False)
    product_brand: Mapped[str | None] = mapped_column(String(200), nullable=True)
    base_unit: Mapped[str] = mapped_column(String(2), nullable=False)
    off_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    review_note: Mapped[str] = mapped_column(String(1000), nullable=False)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    reviewed_by_user_id: Mapped[PyUUID | None] = mapped_column(UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
