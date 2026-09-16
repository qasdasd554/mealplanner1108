"""Schematy API sekcji Znajomi."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class FriendInvitationCreate(BaseModel):
    identifier: str = Field(min_length=2, max_length=320)


class FriendEntry(BaseModel):
    connection_id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    avatar: str | None = None
    avatar_photo_base64: str | None = None
    status: str
    direction: str | None = None
    created_at: datetime
