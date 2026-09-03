"""Schematy Pydantic v2 dla użytkowników i uwierzytelniania."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, model_validator


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
    # Saldo punktów premium — widoczne w profilu, żeby użytkownik wiedział,
    # ile mu zostało (2 punkty = jedno zapytanie do AI).
    premium_points: int = 0
    created_at: datetime

    # ── JEDNO ŹRÓDŁO PRAWDY O DOSTĘPIE PREMIUM ──
    # Liczone tą SAMĄ funkcją, którą backend blokuje endpointy premium
    # (is_premium_active), więc UI nie może się z nią rozjechać.
    #
    # NAPRAWA BŁĘDU: wcześniej API zwracało tylko surową flagę
    # `is_premium`, a aplikacja liczyła dostęp sama jako
    # `isPremium || isAdmin`, CAŁKOWICIE POMIJAJĄC datę wygaśnięcia.
    # Efekt: po wygaśnięciu subskrypcji flaga w bazie nadal była `true`
    # (nic jej automatycznie nie gasi), więc profil dalej pokazywał
    # "Premium" i odblokowane funkcje, ale każde żądanie do endpointu
    # premium wracało z 403 — użytkownik widział aktywne premium, którego
    # nie dało się użyć.
    has_premium_access: bool = False

    @model_validator(mode="after")
    def compute_premium_access(self):
        # Import lokalny, żeby uniknąć cyklicznego importu:
        # core.premium -> models.user -> (pośrednio) schemas.
        from app.core.premium import is_premium_active

        # is_premium_active oczekuje obiektu z polami role/is_premium/
        # premium_expires_at — ten schemat ma dokładnie te pola, więc
        # przekazujemy go bezpośrednio zamiast duplikować logikę.
        self.has_premium_access = is_premium_active(self)
        return self


class UserLogin(BaseModel):
    """Dane logowania."""

    email: str
    password: str


class Token(BaseModel):
    """Token JWT zwracany po pomyślnym logowaniu."""

    access_token: str
    token_type: str = "bearer"
