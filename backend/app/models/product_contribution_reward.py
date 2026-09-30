"""Trwały rejestr punktów przyznanych za dodanie produktu."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class ProductContributionReward(Base):
    """Zapobiega ponownemu przyznaniu punktu za ten sam produkt.

    Klucz wkładu zostaje w tabeli również po usunięciu produktu przez
    moderatora, dlatego odrzuconego zgłoszenia nie można wysłać ponownie
    wyłącznie po to, aby kolejny raz odebrać punkt.
    """

    __tablename__ = "product_contribution_rewards"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "contribution_key",
            name="uq_product_contribution_reward_user_key",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Celowo bez klucza obcego do products: historia nagrody ma przetrwać
    # usunięcie odrzuconego produktu.
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    contribution_key: Mapped[str] = mapped_column(String(80), nullable=False)
    points_awarded: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
