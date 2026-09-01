"""Schematy Pydantic dla zgłaszania treści i blokowania użytkowników."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

# Ustalona, krótka lista powodów — pole wyboru w UI zamiast dowolnego
# tekstu jako jedynej opcji. Ułatwia adminowi szybkie skanowanie zgłoszeń
# i jest zgodne z tym, jak wygląda "Report" w większości aplikacji
# społecznościowych, których wzorce recenzenci Apple znają.
REPORT_REASONS = {
    "spam",
    "inappropriate_content",
    "harassment",
    "misinformation",
    "other",
}


class ContentReportCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    reason: str
    details: str | None = Field(default=None, max_length=1000)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, v: str) -> str:
        if v not in REPORT_REASONS:
            raise ValueError(f"Powód musi być jednym z: {', '.join(sorted(REPORT_REASONS))}.")
        return v

    @field_validator("details")
    @classmethod
    def strip_details(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        return v or None


class ContentReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    reporter_user_id: uuid.UUID
    content_type: str
    content_id: uuid.UUID
    reason: str
    details: str | None
    status: str
    created_at: datetime


class ContentReportAdminEntry(ContentReportResponse):
    """Wersja dla panelu admina — dołącza podgląd zgłoszonej treści,
    żeby nie trzeba było klikać w osobny ekran dla każdego zgłoszenia."""

    reporter_email: str
    content_preview: str | None = None
    content_author_email: str | None = None


class ReportStatusUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    status: str

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        if v not in {"resolved", "dismissed"}:
            raise ValueError("Status musi być 'resolved' albo 'dismissed'.")
        return v


class BlockedUserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    blocked_user_id: uuid.UUID
    blocked_display_name: str | None
    blocked_avatar: str | None
    created_at: datetime
