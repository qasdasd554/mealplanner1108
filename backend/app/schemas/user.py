"""Schematy Pydantic v2 dla użytkowników i uwierzytelniania."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class IngredientPreferencesUpdate(BaseModel):
    """Uporządkowane preferencje Premium, niezależne od alergii i diety."""

    liked_product_ids: list[uuid.UUID] = Field(default_factory=list, max_length=50)
    disliked_product_ids: list[uuid.UUID] = Field(default_factory=list, max_length=50)

    @model_validator(mode="after")
    def validate_products(self):
        if set(self.liked_product_ids) & set(self.disliked_product_ids):
            raise ValueError("Składnik nie może być jednocześnie lubiany i nielubiany.")
        self.liked_product_ids = list(dict.fromkeys(self.liked_product_ids))
        self.disliked_product_ids = list(dict.fromkeys(self.disliked_product_ids))
        return self


class IngredientPreferenceProduct(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str


class IngredientPreferencesResponse(IngredientPreferencesUpdate):
    liked_products: list[IngredientPreferenceProduct] = Field(default_factory=list)
    disliked_products: list[IngredientPreferenceProduct] = Field(default_factory=list)


class UserCreate(BaseModel):
    """Dane wymagane do rejestracji użytkownika."""

    email: str
    password: str
    display_name: str | None = None
    device_region: str | None = None
    preferred_store_id: uuid.UUID | None = None
    dietary_preferences: dict | None = None
    household_size: int = Field(default=1, ge=1, le=8)
    allergen_ids: list[uuid.UUID] = []


class UserResponse(BaseModel):
    """Odpowiedź API — dane użytkownika (bez hasła)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str | None = None
    country_code: Literal["PL", "GB"] = "PL"
    tiktok_username: str | None = None
    preferred_store_id: uuid.UUID | None = None
    dietary_preferences: dict | None = None
    ingredient_preferences: IngredientPreferencesUpdate = Field(default_factory=IngredientPreferencesUpdate)
    household_size: int
    weight_kg: float | None = None
    height_cm: float | None = None
    age: int | None = None
    gender: str | None = None
    activity_level: str | None = None
    daily_kcal_goal: int | None = None
    avatar: str | None = None
    # Zdjęcie ma pierwszeństwo przed ikoną z `avatar`, gdy oba są ustawione
    # — patrz komentarz przy kolumnie w modelu.
    avatar_photo_base64: str | None = None
    is_email_verified: bool = False
    role: str = "user"
    is_premium: bool = False
    premium_expires_at: datetime | None = None
    premium_product_id: str | None = None
    premium_status: str | None = None
    premium_auto_renew_enabled: bool | None = None
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

    @field_validator("country_code", mode="before")
    @classmethod
    def legacy_country_defaults_to_poland(cls, value):
        return "PL" if value is None else value

    @field_validator("ingredient_preferences", mode="before")
    @classmethod
    def empty_legacy_ingredient_preferences(cls, value):
        return value or {}

    @model_validator(mode="after")
    def compute_premium_access(self):
        # Import lokalny, żeby uniknąć cyklicznego importu:
        # core.premium -> models.user -> (pośrednio) schemas.
        from app.core.premium import is_premium_active

        # is_premium_active oczekuje obiektu z polami role/is_premium/
        # premium_expires_at — ten schemat ma dokładnie te pola, więc
        # przekazujemy go bezpośrednio zamiast duplikować logikę.
        self.has_premium_access = is_premium_active(self)
        # Profil TikTok jest dodatkiem Premium. Nie kasujemy zapisanej nazwy
        # po wygaśnięciu subskrypcji, ale przestajemy ją zwracać do aplikacji.
        # Po ponownym wykupieniu Premium odnośnik może więc wrócić bez
        # ponownego wpisywania nazwy przez użytkownika.
        if not self.has_premium_access:
            self.tiktok_username = None
        return self


class UserLogin(BaseModel):
    """Dane logowania."""

    email: str
    password: str


class Token(BaseModel):
    """Token JWT zwracany po pomyślnym logowaniu."""

    access_token: str
    token_type: str = "bearer"
