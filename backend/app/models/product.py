"""Modele ORM produktów, produktów sklepowych, substytutów i alergenów."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Product(Base):
    """Produkt spożywczy (np. 'Mleko 2%', 'Pierś z kurczaka')."""

    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    brand: Mapped[str | None] = mapped_column(String(200), nullable=True)
    unit: Mapped[str] = mapped_column(
        String(20), nullable=False, comment="kg | szt | l | g"
    )
    default_quantity: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 3), nullable=True, comment="Wielkość opakowania"
    )
    barcode: Mapped[str | None] = mapped_column(
        String(50), unique=True, nullable=True
    )
    nutrition_per_100: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Wartości odżywcze na 100 g/ml: kcal, protein, fat, carbs, fiber",
    )
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # ── Relacje ──────────────────────────────────────────────────
    store_products: Mapped[list[StoreProduct]] = relationship(
        "StoreProduct", back_populates="product", cascade="all, delete-orphan"
    )
    allergens: Mapped[list[Allergen]] = relationship(
        "Allergen",
        secondary="product_allergens",
        back_populates="products",
        lazy="selectin",
    )
    recipe_ingredients: Mapped[list["RecipeIngredient"]] = relationship(
        "RecipeIngredient", back_populates="product"
    )
    substitutes_as_original: Mapped[list[ProductSubstitute]] = relationship(
        "ProductSubstitute",
        foreign_keys="ProductSubstitute.original_product_id",
        back_populates="original_product",
        cascade="all, delete-orphan",
    )
    substitutes_as_substitute: Mapped[list[ProductSubstitute]] = relationship(
        "ProductSubstitute",
        foreign_keys="ProductSubstitute.substitute_product_id",
        back_populates="substitute_product",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Product {self.name!r}>"


class StoreProduct(Base):
    """Powiązanie produktu ze sklepem — cena i dostępność."""

    __tablename__ = "store_products"
    __table_args__ = (
        UniqueConstraint("store_id", "product_id", name="uq_store_product"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="CASCADE"),
        nullable=False,
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
    )
    department_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("store_departments.id", ondelete="SET NULL"),
        nullable=True,
    )
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_verified: Mapped[date | None] = mapped_column(Date, nullable=True)
    withdrawn_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # ── Relacje ──────────────────────────────────────────────────
    store: Mapped["Store"] = relationship("Store", back_populates="store_products")
    product: Mapped[Product] = relationship("Product", back_populates="store_products")
    department: Mapped["StoreDepartment | None"] = relationship(
        "StoreDepartment", back_populates="store_products"
    )

    def __repr__(self) -> str:
        return f"<StoreProduct store={self.store_id} product={self.product_id} price={self.price}>"


class ProductSubstitute(Base):
    """Zamiennik produktu z oceną podobieństwa."""

    __tablename__ = "product_substitutes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    original_product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
    )
    substitute_product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
    )
    similarity_score: Mapped[Decimal] = mapped_column(
        Numeric(3, 2), default=Decimal("0.50")
    )

    # ── Relacje ──────────────────────────────────────────────────
    original_product: Mapped[Product] = relationship(
        "Product",
        foreign_keys=[original_product_id],
        back_populates="substitutes_as_original",
    )
    substitute_product: Mapped[Product] = relationship(
        "Product",
        foreign_keys=[substitute_product_id],
        back_populates="substitutes_as_substitute",
    )

    def __repr__(self) -> str:
        return (
            f"<ProductSubstitute {self.original_product_id} -> "
            f"{self.substitute_product_id} ({self.similarity_score})>"
        )


class Allergen(Base):
    """Alergen (np. 'gluten', 'laktoza', 'orzechy')."""

    __tablename__ = "allergens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    name: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    products: Mapped[list[Product]] = relationship(
        "Product",
        secondary="product_allergens",
        back_populates="allergens",
    )

    def __repr__(self) -> str:
        return f"<Allergen {self.name!r}>"


class ProductAllergen(Base):
    """Tabela asocjacyjna — powiązanie produktu z alergenem."""

    __tablename__ = "product_allergens"

    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        primary_key=True,
    )
    allergen_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("allergens.id", ondelete="CASCADE"),
        primary_key=True,
    )
