"""Dzienne nawodnienie, aktywność fizyczna i historia masy ciała.

Osobne tabele, a nie jedna wspólna „dzienna notatka": nawodnienie
to POJEDYNCZA, narastająca liczba na dobę (ile ml wypito), a aktywność
to LISTA zdarzeń w ciągu dnia (bieganie 200 kcal, rower 150 kcal).
Masa ciała jest jednym opcjonalnym pomiarem na dzień, który można później
poprawić bez tworzenia duplikatu.
"""

from __future__ import annotations

import uuid
from datetime import date as date_type
from datetime import datetime

from sqlalchemy import Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class WaterLog(Base):
    """Ile mililitrów wody użytkownik wypił danego dnia."""

    __tablename__ = "water_logs"
    __table_args__ = (
        # Jeden wiersz na użytkownika i dzień — dolewanie wody
        # AKTUALIZUJE istniejący wpis zamiast tworzyć nowy. Bez tego
        # ograniczenia równoległe kliknięcia (np. dwukrotne dotknięcie
        # przycisku) potrafiłyby stworzyć dwa wiersze na ten sam dzień
        # i suma pokazywałaby się dwa razy.
        UniqueConstraint("user_id", "date", name="uq_water_logs_user_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    date: Mapped[date_type] = mapped_column(Date, nullable=False, index=True)
    amount_ml: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class WeightLog(Base):
    """Opcjonalny pomiar masy ciała przypisany do konkretnego dnia."""

    __tablename__ = "weight_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_weight_logs_user_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date_type] = mapped_column(Date, nullable=False, index=True)
    weight_kg: Mapped[float] = mapped_column(Float, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class ActivityLog(Base):
    """Pojedyncza aktywność fizyczna i spalone przy niej kalorie.

    Spalone kalorie POWIĘKSZAJĄ dzienny limit w liczniku — użytkownik,
    który przebiegł 5 km, może zjeść odpowiednio więcej. Dlatego
    przechowujemy je osobno od spożytych, a nie jako ujemny wpis
    w dzienniku żywieniowym: mieszanie jednego z drugim uniemożliwiłoby
    pokazanie, ile faktycznie zjedzono, a ile wypracowano.
    """

    __tablename__ = "activity_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    date: Mapped[date_type] = mapped_column(Date, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    kcal_burned: Mapped[int] = mapped_column(Integer, nullable=False)
    duration_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
