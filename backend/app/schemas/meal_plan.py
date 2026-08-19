"""Schematy Pydantic v2 dla planów posiłków."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.recipe import RecipeResponse


class MealPlanCreate(BaseModel):
    """Dane wymagane do ręcznego utworzenia planu posiłków."""

    store_id: uuid.UUID
    start_date: date
    duration_days: int
    meals_per_day: int = 3
    preferences: dict | None = None


class MealPlanEntryResponse(BaseModel):
    """Odpowiedź API — wpis w planie posiłków."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    recipe: RecipeResponse
    day_number: int
    meal_slot: str
    servings_multiplier: float


class MealPlanResponse(BaseModel):
    """Odpowiedź API — pełny plan posiłków z wpisami."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    store_id: uuid.UUID
    start_date: date
    duration_days: int
    meals_per_day: int
    status: str
    estimated_min_budget: float | None = None
    entries: list[MealPlanEntryResponse] = []
    created_at: datetime


class MealPlanGenerateRequest(BaseModel):
    """Żądanie automatycznego wygenerowania planu posiłków."""

    store_id: uuid.UUID
    duration_days: int = Field(default=7, ge=1, le=14)
    meals_per_day: int = Field(default=3, ge=1, le=5)
    max_budget: float | None = None
    # Dla ilu osób gotować W TYM planie. Jeśli nie podano, backend użyje
    # wartości z profilu użytkownika (household_size ustawione w onboardingu
    # / profilu). Podanie tej wartości NIE zmienia trwale profilu — dotyczy
    # tylko generowanego teraz planu.
    household_size: int | None = Field(default=None, ge=1, le=20)
    # Docelowa dzienna kaloryczność na osobę. Wcześniej aplikacja wysyłała
    # to pole, ale backend go nie przyjmował (Pydantic po cichu odrzucał
    # nieznane pole) — ustawienie w formularzu nic nie robiło.
    #
    # UWAGA (naprawa): to pole było przez pomyłkę zadeklarowane TUTAJ
    # DWUKROTNIE (raz jako float z zakresem >0-6000, zaraz potem jako int
    # z zakresem 800-5000) — druga deklaracja po cichu nadpisywała
    # pierwszą (tak działa Python przy powtórnej definicji atrybutu
    # klasy), więc pierwsza była martwym kodem. Scalone w jedną: typ
    # `float` (zgodny z tym, czego wszędzie indziej w kodzie —
    # meal_plan_generator.py — oczekuje ta wartość), z granicami 800-5000
    # (fizjologicznie sensowniejsze niż ">0", które dopuszczało absurdalne
    # wartości typu target_kcal=1).
    target_kcal: float | None = Field(default=None, ge=800, le=5000)
    preferences: dict | None = None
