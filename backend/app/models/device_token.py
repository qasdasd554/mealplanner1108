"""Tokeny urządzeń do powiadomień push (Firebase Cloud Messaging).

Jeden użytkownik może mieć WIELE tokenów naraz — telefon i tablet,
Android i iOS, albo to samo konto na dwóch urządzeniach. Dlatego osobna
tabela, a nie kolumna na modelu User: kolumna zmusiłaby do nadpisywania
poprzedniego tokenu przy każdym kolejnym logowaniu i push docierałby
tylko na ostatnio użyte urządzenie.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class DeviceToken(Base):
    __tablename__ = "device_tokens"
    __table_args__ = (
        # Ten sam token nie może być przypisany dwa razy. Token jest
        # własnością URZĄDZENIA, nie konta — jeśli na tym samym telefonie
        # zaloguje się inna osoba, token musi zostać PRZEPISANY na nią,
        # inaczej poprzedni właściciel dalej dostawałby cudze powiadomienia
        # na to urządzenie.
        UniqueConstraint("token", name="uq_device_tokens_token"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Token rejestracyjny z FCM. Bywa długi (>200 znaków), stąd zapas.
    token: Mapped[str] = mapped_column(String(512), nullable=False)
    # "ios" | "android" — przydatne przy diagnozie i statystykach.
    platform: Mapped[str | None] = mapped_column(String(10), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    # Aktualizowane przy każdej ponownej rejestracji tego samego tokenu —
    # pozwala kiedyś posprzątać tokeny urządzeń nieużywanych od miesięcy.
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
