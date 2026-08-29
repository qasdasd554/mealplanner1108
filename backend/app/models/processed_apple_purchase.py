"""Śledzenie już rozliczonych zakupów jednorazowych z App Store —
Apple, w przeciwieństwie do Google Play (patrz consumptionState w
google_play_billing.py), NIE MA wbudowanego mechanizmu "konsumowania"
zakupu. Odpowiedzialność za to, żeby ten sam zakup nie przyznał
punktów dwa razy, spoczywa WYŁĄCZNIE po naszej stronie — stąd ta
tabela, zamiast pytania Apple "czy to już skonsumowane"."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class ProcessedApplePurchase(Base):
    __tablename__ = "processed_apple_purchases"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    # ID transakcji z App Store — UNIKALNE, więc próba ponownego
    # rozliczenia tej samej transakcji zawiedzie na poziomie bazy
    # (constraint), nie tylko "sprawdzenia w Pythonie".
    transaction_id: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    processed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
