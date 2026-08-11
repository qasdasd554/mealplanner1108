"""Modele ORM sklepów i działów sklepowych."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Store(Base):
    """Sklep (np. Lidl, Biedronka, Dino)."""

    __tablename__ = "stores"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    name: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False
    )
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    department_order: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    # ── Relacje ──────────────────────────────────────────────────
    departments: Mapped[list[StoreDepartment]] = relationship(
        "StoreDepartment", back_populates="store", cascade="all, delete-orphan"
    )
    store_products: Mapped[list["StoreProduct"]] = relationship(
        "StoreProduct", back_populates="store", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Store {self.name!r}>"


class StoreDepartment(Base):
    """Dział w sklepie (np. 'Warzywa i owoce', 'Nabiał')."""

    __tablename__ = "store_departments"

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
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # ── Relacje ──────────────────────────────────────────────────
    store: Mapped[Store] = relationship("Store", back_populates="departments")
    store_products: Mapped[list["StoreProduct"]] = relationship(
        "StoreProduct", back_populates="department"
    )

    def __repr__(self) -> str:
        return f"<StoreDepartment {self.name!r} @ {self.store_id}>"
