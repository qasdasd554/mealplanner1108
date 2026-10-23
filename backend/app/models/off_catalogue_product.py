"""Isolated, attributable OFF facts. No users, retailer offers or prices."""

from datetime import datetime

from sqlalchemy import DateTime, Float, Integer, String
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class OffCatalogueProduct(Base):
    __tablename__ = "off_catalogue_products"

    barcode: Mapped[str] = mapped_column(String(14), primary_key=True)
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    brand: Mapped[str | None] = mapped_column(String(200))
    search_name: Mapped[str] = mapped_column(String(510), nullable=False, index=True)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    base_unit: Mapped[str] = mapped_column(String(2), nullable=False)
    package_quantity: Mapped[float | None] = mapped_column(Float)
    nutrition_per_100: Mapped[dict] = mapped_column(JSON, nullable=False)
    reported_stores: Mapped[list] = mapped_column(JSON, nullable=False)
    source_url: Mapped[str] = mapped_column(String(200), nullable=False)
    source_modified_t: Mapped[int] = mapped_column(Integer, nullable=False)
    retrieved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    licence: Mapped[str] = mapped_column(String(20), nullable=False)
    fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
