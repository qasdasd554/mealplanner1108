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
    weight_kg: float | None = None
    height_cm: float | None = None
    age: int | None = None
    gender: str | None = None
    activity_level: str | None = None
    daily_kcal_goal: int | None = None
    avatar: str | None = None
    is_email_verified: bool = False
    role: str = "user"
    is_premium: bool = False
    premium_expires_at: datetime | None = None
    premium_product_id: str | None = None
    created_at: datetime


class UserLogin(BaseModel):
    """Dane logowania."""

    email: str
    password: str


class Token(BaseModel):
    """Token JWT zwracany po pomyślnym logowaniu."""

    access_token: str
    token_type: str = "bearer"
