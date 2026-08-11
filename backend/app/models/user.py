"""Modele ORM użytkowników i ich alergenów."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class User(Base):
    """Użytkownik aplikacji."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    email: Mapped[str] = mapped_column(
        String(320), unique=True, nullable=False
    )
    password_hash: Mapped[str] = mapped_column(String(500), nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    preferred_store_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="SET NULL"),
        nullable=True,
    )
    dietary_preferences: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Preferencje dietetyczne w formacie JSON",
    )
    household_size: Mapped[int] = mapped_column(
        Integer, default=1, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # ── Relacje ──────────────────────────────────────────────────
    preferred_store: Mapped["Store | None"] = relationship(
        "Store", foreign_keys=[preferred_store_id]
    )
    meal_plans: Mapped[list["MealPlan"]] = relationship(
        "MealPlan", back_populates="user", cascade="all, delete-orphan"
    )
    allergens: Mapped[list["Allergen"]] = relationship(
        "Allergen",
        secondary="user_allergens",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return f"<User {self.email!r}>"


class UserAllergen(Base):
    """Tabela asocjacyjna — alergeny użytkownika."""

    __tablename__ = "user_allergens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    allergen_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("allergens.id", ondelete="CASCADE"),
        primary_key=True,
    )
