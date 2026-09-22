"""Trwały zapis utworzenia listy, niezależny od jej późniejszego usunięcia."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class ShoppingListCreation(Base):
    __tablename__ = "shopping_list_creations"
    __table_args__ = (
        UniqueConstraint("shopping_list_id", name="uq_shopping_list_creation_list"),
        Index("ix_shopping_list_creations_user_week", "user_id", "week_start"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False,
    )
    # Celowo bez FK do listy: skasowanie listy nie odnawia limitu tygodniowego.
    shopping_list_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
