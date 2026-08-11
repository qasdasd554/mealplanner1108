"""Schematy Pydantic v2 dla sklepów i działów sklepowych."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class StoreBase(BaseModel):
    """Wspólne pola sklepu."""

    name: str
    logo_url: str | None = None


class StoreCreate(StoreBase):
    """Dane wymagane do utworzenia sklepu."""

    pass


class StoreResponse(StoreBase):
    """Odpowiedź API — pełne dane sklepu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    department_order: dict | None = None
    created_at: datetime


class StoreDepartmentResponse(BaseModel):
    """Odpowiedź API — dział sklepowy."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    store_id: uuid.UUID
    name: str
    sort_order: int
