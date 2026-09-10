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
    # Widoczne tylko wtedy, gdy produkt jest zgłoszeniem użytkownika —
    # oficjalne produkty katalogowe mają review_status="approved" (patrz
    # domyślna wartość w modelu) i submitted_price=None.
    review_status: str = "approved"
    # float, nie Decimal — Pydantic serializuje Decimal do JSON jako
    # STRING (żeby zachować dokładność), np. "11.99" zamiast 11.99.
    # Frontend parsował to jako liczbę ("as num?"), więc dostawał wyjątek
    # "type String is not a subtype of type num". Reszta cen w tym pliku
    # (StoreProductResponse.price) i tak już używa float — to pole było
    # jedynym wyjątkiem.
    submitted_price: float | None = None
    requested_store_ids: list[str] | None = None


class StoreProductResponse(BaseModel):
    """Odpowiedź API — produkt w kontekście sklepu (z ceną i dostępnością)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    store_id: uuid.UUID
    product_id: uuid.UUID
    department_id: uuid.UUID | None = None
    price: float
    # Marka własna sklepu dla tego produktu, jeśli potwierdzona (np.
    # "Mleczna Dolina" dla mleka w Biedronce). Puste = brak marki własnej
    # w tej kategorii w danym sklepie.
    store_brand_name: str | None = None
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
