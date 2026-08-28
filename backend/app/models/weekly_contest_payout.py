"""Śledzenie, które tygodnie cotygodniowego konkursu przepisów zostały
już rozliczone (punkty przyznane zwycięzcom) — zabezpieczenie przed
PODWÓJNYM przyznaniem punktów, gdyby zaplanowane zadanie (patrz
app/services/weekly_contest.py) uruchomiło się więcej niż raz dla
tego samego tygodnia (np. po restarcie serwera akurat w tym oknie)."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class WeeklyContestPayout(Base):
    __tablename__ = "weekly_contest_payouts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    # Poniedziałek tygodnia, który został rozliczony — UNIKALNE, więc
    # próba ponownego zapisu dla tego samego tygodnia po prostu zawiedzie
    # (constraint w bazie), a nie tylko "sprawdzenie w Pythonie", które
    # teoretycznie mogłoby przegapić wyścig (race condition).
    week_start_date: Mapped[date] = mapped_column(Date, nullable=False, unique=True)
    processed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
