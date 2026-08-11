"""Schematy Pydantic v2 dla produktów i produktów sklepowych."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class NutritionInfo(BaseModel):
    """Wartości odżywcze na 100 g/ml."""

    kcal: float | None = None
    protein: float | None = None
    fat: float | None = None
    carbs: float | None = None
    fiber: float | None = None


class ProductBase(BaseModel):
    """Wspólne pola produktu."""

    name: str
    brand: str | None = None
    unit: str
    default_quantity: float | None = None
    barcode: str | None = None
    nutrition_per_100: NutritionInfo | None = None


class ProductCreate(ProductBase):
    """Dane wymagane do utworzenia produktu."""

    pass


class ProductResponse(ProductBase):
    """Odpowiedź API — pełne dane produktu."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    image_url: str | None = None
    created_at: datetime


class StoreProductResponse(BaseModel):
    """Odpowiedź API — produkt w kontekście sklepu (z ceną i dostępnością)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    store_id: uuid.UUID
    product_id: uuid.UUID
    department_id: uuid.UUID | None = None
    price: float
    is_available: bool
    last_verified: date | None = None
    product: ProductResponse
class SubstituteResponse(BaseModel):
    """Odpowiedź API — zamiennik z opcjonalną ceną ze sklepu."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    brand: str | None = None
    price: float | None = None
    kcal: int | None = None
    similarity_score: float | None = None
