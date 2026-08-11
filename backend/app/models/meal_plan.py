"""Modele ORM planu posiłków i wpisów."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class MealPlan(Base):
    """Plan posiłków na określony okres."""

    __tablename__ = "meal_plans"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="CASCADE"),
        nullable=False,
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    meals_per_day: Mapped[int] = mapped_column(
        Integer, default=3, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="draft",
        nullable=False,
        comment="draft | active | completed | archived",
    )
    preferences: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="meal_plans")
    store: Mapped["Store"] = relationship("Store")
    entries: Mapped[list[MealPlanEntry]] = relationship(
        "MealPlanEntry", back_populates="meal_plan", cascade="all, delete-orphan"
    )
    shopping_list: Mapped["ShoppingList | None"] = relationship(
        "ShoppingList", back_populates="meal_plan", uselist=False
    )

    def __repr__(self) -> str:
        return f"<MealPlan {self.id} user={self.user_id} {self.start_date}>"


class MealPlanEntry(Base):
    """Wpis w planie posiłków — przypisanie przepisu do dnia i slotu."""

    __tablename__ = "meal_plan_entries"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    meal_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("meal_plans.id", ondelete="CASCADE"),
        nullable=False,
    )
    recipe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("recipes.id", ondelete="CASCADE"),
        nullable=False,
    )
    day_number: Mapped[int] = mapped_column(Integer, nullable=False)
    meal_slot: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="śniadanie | obiad | kolacja | przekąska",
    )
    servings_multiplier: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), default=Decimal("1.00"), nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    meal_plan: Mapped[MealPlan] = relationship(
        "MealPlan", back_populates="entries"
    )
    recipe: Mapped["Recipe"] = relationship("Recipe", back_populates="meal_plan_entries")

    def __repr__(self) -> str:
        return f"<MealPlanEntry day={self.day_number} slot={self.meal_slot!r}>"
