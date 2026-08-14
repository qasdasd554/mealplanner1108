"""Schematy Pydantic dla powiadomień w aplikacji."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationResponse(BaseModel):
    """Odpowiedź API — pojedyncze powiadomienie."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    notification_type: str
    message: str
    recipe_id: uuid.UUID | None = None
    recipe_name: str | None = None
    comment_id: uuid.UUID | None = None
    is_read: bool
    created_at: datetime


class UnreadCountResponse(BaseModel):
    """Sama liczba nieprzeczytanych — lekkie zapytanie do odznaki na
    dzwoneczku, bez ściągania całej listy powiadomień."""

    unread_count: int
