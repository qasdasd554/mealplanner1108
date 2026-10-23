"""Additive UK shopping line snapshot; no legacy column changes."""

from datetime import date
from decimal import Decimal
from uuid import UUID as PythonUUID

from sqlalchemy import JSON, Boolean, CheckConstraint, Date, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class ShoppingListItemRegionalSnapshot(Base):
    __tablename__ = "shopping_list_item_regional_snapshots"
    __table_args__ = (
        CheckConstraint("country_code = 'GB' AND currency_code = 'GBP'", name="ck_shopping_snapshot_market"),
        CheckConstraint("quote_status IN ('quoted', 'unpriced', 'pantry')", name="ck_shopping_snapshot_status"),
        CheckConstraint("required_unit IS NULL OR required_unit IN ('g', 'ml')", name="ck_shopping_snapshot_unit"),
        CheckConstraint("required_quantity IS NULL OR required_quantity > 0", name="ck_shopping_snapshot_quantity"),
        CheckConstraint("manual_extra_quantity >= 0", name="ck_shopping_snapshot_manual_extra"),
    )

    item_id: Mapped[PythonUUID] = mapped_column(UUID(as_uuid=True), ForeignKey("shopping_list_items.id", ondelete="CASCADE"), primary_key=True)
    product_id: Mapped[PythonUUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="SET NULL"), nullable=True, index=True)
    store_id: Mapped[PythonUUID] = mapped_column(UUID(as_uuid=True), ForeignKey("stores.id", ondelete="CASCADE"), nullable=False)
    offer_id: Mapped[PythonUUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("regional_product_offers.id", ondelete="SET NULL"), nullable=True)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False, default="GB")
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False, default="GBP")
    name_en: Mapped[str] = mapped_column(String(300), nullable=False)
    required_quantity: Mapped[Decimal | None] = mapped_column(Numeric(10, 3), nullable=True)
    required_unit: Mapped[str | None] = mapped_column(String(2), nullable=True)
    manual_extra_quantity: Mapped[Decimal] = mapped_column(Numeric(10, 3), nullable=False, default=Decimal(0), server_default="0")
    purchase_is_checked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    quote_status: Mapped[str] = mapped_column(String(8), nullable=False)
    quote_data: Mapped[dict | None] = mapped_column(JSON(none_as_null=True), nullable=True)
    pricing_as_of: Mapped[date] = mapped_column(Date, nullable=False)
    item: Mapped["ShoppingListItem"] = relationship("ShoppingListItem", back_populates="regional_snapshot")
