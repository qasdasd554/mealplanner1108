"""Modele ORM przepisów, tagów i składników."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Recipe(Base):
    """Przepis kulinarny."""

    __tablename__ = "recipes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    cuisine: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="polska | włoska | azjatycka | ...",
    )
    meal_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="śniadanie | obiad | kolacja | przekąska",
    )
    prep_time_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cook_time_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    servings: Mapped[int] = mapped_column(Integer, default=2, nullable=False)
    difficulty: Mapped[str] = mapped_column(
        String(50),
        default="łatwy",
        nullable=False,
        comment="łatwy | średni | trudny",
    )
    nutrition_total: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    tags: Mapped[list[RecipeTag]] = relationship(
        "RecipeTag", back_populates="recipe", cascade="all, delete-orphan"
    )
    ingredients: Mapped[list[RecipeIngredient]] = relationship(
        "RecipeIngredient", back_populates="recipe", cascade="all, delete-orphan"
    )
    meal_plan_entries: Mapped[list["MealPlanEntry"]] = relationship(
        "MealPlanEntry", back_populates="recipe"
    )

    def __repr__(self) -> str:
        return f"<Recipe {self.name!r}>"


class RecipeTag(Base):
    """Tag przypisany do przepisu (np. 'wegetariańskie', 'keto')."""

    __tablename__ = "recipe_tags"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    recipe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("recipes.id", ondelete="CASCADE"),
        nullable=False,
    )
    tag: Mapped[str] = mapped_column(String(100), nullable=False)

    # ── Relacje ──────────────────────────────────────────────────
    recipe: Mapped[Recipe] = relationship("Recipe", back_populates="tags")

    def __repr__(self) -> str:
        return f"<RecipeTag {self.tag!r}>"


class RecipeIngredient(Base):
    """Składnik przepisu z ilością i jednostką."""

    __tablename__ = "recipe_ingredients"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    recipe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("recipes.id", ondelete="CASCADE"),
        nullable=False,
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(10, 3), nullable=False)
    unit: Mapped[str] = mapped_column(String(20), nullable=False)
    is_optional: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Relacje ──────────────────────────────────────────────────
    recipe: Mapped[Recipe] = relationship("Recipe", back_populates="ingredients")
    product: Mapped["Product"] = relationship("Product", back_populates="recipe_ingredients")

    def __repr__(self) -> str:
        return f"<RecipeIngredient {self.product_id} x{self.quantity} {self.unit}>"
