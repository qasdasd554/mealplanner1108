import uuid
from datetime import date, datetime
from typing import Optional, List

from pydantic import BaseModel, Field


class FoodLogEntryBase(BaseModel):
    date: date
    meal_type: str = Field(..., description="Type of meal, e.g. breakfast, lunch, dinner, snack")
    recipe_id: Optional[uuid.UUID] = None
    custom_name: Optional[str] = None
    calories: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    carbs: float = 0.0
    servings: float = 1.0


class FoodLogEntryCreate(FoodLogEntryBase):
    pass


class FoodLogEntryResponse(FoodLogEntryBase):
    id: uuid.UUID
    user_id: uuid.UUID
    created_at: datetime
    # Nazwa przepisu, jeśli wpis powstał z przepisu (recipe_id ustawiony).
    # Bez tego pola aplikacja mobilna nie miała jak pokazać nazwy posiłku —
    # backend zwracał tylko surowe recipe_id (UUID), a nie nazwę dania.
    recipe_name: Optional[str] = None

    class Config:
        orm_mode = True
        from_attributes = True


class DailySummaryResponse(BaseModel):
    date: date
    total_calories: float = 0.0
    total_protein: float = 0.0
    total_fat: float = 0.0
    total_carbs: float = 0.0
    entries: List[FoodLogEntryResponse] = []
