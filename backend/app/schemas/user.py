"""Schematy Pydantic v2 dla użytkowników i uwierzytelniania."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr


class UserCreate(BaseModel):
    """Dane wymagane do rejestracji użytkownika."""

    email: str
    password: str
    display_name: str | None = None
    preferred_store_id: uuid.UUID | None = None
    dietary_preferences: dict | None = None
    household_size: int = 1
    allergen_ids: list[uuid.UUID] = []


class UserResponse(BaseModel):
    """Odpowiedź API — dane użytkownika (bez hasła)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str | None = None
    preferred_store_id: uuid.UUID | None = None
    dietary_preferences: dict | None = None
    household_size: int
    created_at: datetime


class UserLogin(BaseModel):
    """Dane logowania."""

    email: str
    password: str


class Token(BaseModel):
    """Token JWT zwracany po pomyślnym logowaniu."""

    access_token: str
    token_type: str = "bearer"
