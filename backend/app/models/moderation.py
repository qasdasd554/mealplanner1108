"""Modele moderacji treści — zgłoszenia (Guideline 1.2 Apple: aplikacje
z treścią od użytkowników muszą mieć mechanizm zgłaszania) i blokowanie
innych użytkowników.

Świadomie DWA osobne modele, nie jeden ogólny "Moderation" — zgłoszenie
i blokada mają zupełnie inny cykl życia: zgłoszenie jest jednorazowym
zdarzeniem rozpatrywanym przez admina (ma status), blokada jest trwałym
stanem relacji między dwoma kontami (nie ma "rozpatrzenia").
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class ContentReport(Base):
    """Zgłoszenie treści (przepisu albo komentarza) do rozpatrzenia przez
    administratora. `content_type` + `content_id` zamiast osobnej kolumny
    klucza obcego dla każdego typu treści — prościej dodać kolejny typ
    zgłaszalnej treści w przyszłości bez migracji schematu."""

    __tablename__ = "content_reports"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    reporter_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # "recipe" | "comment"
    content_type: Mapped[str] = mapped_column(String(20), nullable=False)
    content_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    # Krótki, ustalony powód (patrz REPORT_REASONS w schemas/moderation.py)
    # + opcjonalny wolny tekst z detalami.
    reason: Mapped[str] = mapped_column(String(50), nullable=False)
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    # "pending" | "resolved" | "dismissed" — admin oznacza po rozpatrzeniu.
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class BlockedUser(Base):
    """Blokada — `user_id` nie widzi już treści od `blocked_user_id`
    (przepisy i komentarze filtrowane w zapytaniach listujących)."""

    __tablename__ = "blocked_users"
    __table_args__ = (
        UniqueConstraint("user_id", "blocked_user_id", name="uq_blocked_users_pair"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    blocked_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
