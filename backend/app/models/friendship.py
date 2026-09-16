"""Relacja znajomych i zaproszenia między użytkownikami."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Friendship(Base):
    """Jedna, kanonicznie zapisana para użytkowników.

    ``user_a_id`` i ``user_b_id`` są zawsze ustawiane w kolejności tekstowej
    UUID. Dzięki temu ta sama para nie może utworzyć dwóch relacji w
    przeciwnych kierunkach. ``requested_by_id`` zachowuje informację, kto
    wysłał oczekujące zaproszenie.
    """

    __tablename__ = "friendships"
    __table_args__ = (
        UniqueConstraint("user_a_id", "user_b_id", name="uq_friendships_pair"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    user_a_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_b_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    requested_by_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user_a: Mapped["User"] = relationship("User", foreign_keys=[user_a_id])  # noqa: F821
    user_b: Mapped["User"] = relationship("User", foreign_keys=[user_b_id])  # noqa: F821
    requested_by: Mapped["User"] = relationship("User", foreign_keys=[requested_by_id])  # noqa: F821


def canonical_friend_ids(first: uuid.UUID, second: uuid.UUID) -> tuple[uuid.UUID, uuid.UUID]:
    """Zwraca parę UUID w stabilnej kolejności używanej przez ograniczenie UNIQUE."""

    return (first, second) if str(first) < str(second) else (second, first)
