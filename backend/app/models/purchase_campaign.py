"""Kampanie ofert App Store; nie zmieniają ceny zakupu po stronie serwera."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class PurchaseCampaign(Base):
    __tablename__ = "purchase_campaigns"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    kind: Mapped[str] = mapped_column(String(20), nullable=False)  # premium | points
    product_id: Mapped[str] = mapped_column(String(80), nullable=False)
    discount_percent: Mapped[int] = mapped_column(Integer, nullable=False)
    audience: Mapped[str] = mapped_column(String(20), nullable=False)  # all | user
    target_email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # Link do rzeczywistego kodu ofertowego skonfigurowanego w App Store Connect.
    # Android nie jest uruchamiany samym linkiem: wymaga obsługi offerToken.
    ios_offer_url: Mapped[str] = mapped_column(String(1000), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
