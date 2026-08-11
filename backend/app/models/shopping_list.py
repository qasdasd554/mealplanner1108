"""Modele ORM listy zakupów i pozycji."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class ShoppingList(Base):
    """Lista zakupów wygenerowana na podstawie planu posiłków."""

    __tablename__ = "shopping_lists"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    meal_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("meal_plans.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="pending",
        nullable=False,
        comment="pending | in_progress | completed",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    meal_plan: Mapped["MealPlan"] = relationship(
        "MealPlan", back_populates="shopping_list"
    )
    store: Mapped["Store"] = relationship("Store")
    items: Mapped[list[ShoppingListItem]] = relationship(
        "ShoppingListItem",
        back_populates="shopping_list",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<ShoppingList {self.id} status={self.status!r}>"


class ShoppingListItem(Base):
    """Pozycja na liście zakupów."""

    __tablename__ = "shopping_list_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    shopping_list_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("shopping_lists.id", ondelete="CASCADE"),
        nullable=False,
    )
    store_product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("store_products.id", ondelete="CASCADE"),
        nullable=False,
    )
    department_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("store_departments.id", ondelete="SET NULL"),
        nullable=True,
    )
    required_quantity: Mapped[Decimal] = mapped_column(
        Numeric(10, 3), nullable=False
    )
    unit: Mapped[str] = mapped_column(String(20), nullable=False)
    estimated_price: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2), nullable=True
    )
    is_checked: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    substituted_for: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="SET NULL"),
        nullable=True,
        comment="ID oryginalnego produktu, jeśli ten jest zamiennikiem",
    )

    # ── Relacje ──────────────────────────────────────────────────
    shopping_list: Mapped[ShoppingList] = relationship(
        "ShoppingList", back_populates="items"
    )
    store_product: Mapped["StoreProduct"] = relationship("StoreProduct")
    department: Mapped["StoreDepartment | None"] = relationship("StoreDepartment")
    substituted_for_product: Mapped["Product | None"] = relationship(
        "Product", foreign_keys=[substituted_for]
    )

    def __repr__(self) -> str:
        return (
            f"<ShoppingListItem {self.store_product_id} "
            f"qty={self.required_quantity} {self.unit}>"
        )
