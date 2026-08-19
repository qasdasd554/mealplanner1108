import uuid
from datetime import date, datetime
from typing import Optional, List

from pydantic import BaseModel, Field


class FoodLogEntryBase(BaseModel):
    date: date
    # UWAGA (naprawa): `meal_type` i `custom_name` nie miały limitów
    # długości — w przeciwieństwie do liczbowych pól (patrz
    # FoodLogEntryCreate poniżej), te DWA są bezpieczne do ograniczenia
    # też tutaj (w klasie bazowej, używanej też przy ODCZYCIE), bo limity
    # dokładnie odpowiadają TWARDYM ograniczeniom kolumn w bazie
    # (app/models/food_log.py: meal_type=String(50), custom_name=
    # String(255)) — żaden istniejący wiersz nie mógł ich fizycznie
    # przekroczyć, w przeciwieństwie do granic liczbowych, które są
    # nowymi regułami biznesowymi, nie odbiciem ograniczeń bazy.
    meal_type: str = Field(..., max_length=50, description="Type of meal, e.g. breakfast, lunch, dinner, snack")
    recipe_id: Optional[uuid.UUID] = None
    custom_name: Optional[str] = Field(default=None, max_length=255)
    calories: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    carbs: float = 0.0
    servings: float = 1.0


class FoodLogEntryCreate(FoodLogEntryBase):
    """Dane wymagane przy TWORZENIU wpisu — tu (i tylko tu) mają sens
    ograniczenia wartości. UWAGA (naprawa): wcześniej te pola nie miały
    ŻADNYCH ograniczeń — w przeciwieństwie do parametru `servings` w
    endpointcie `/food-log/from-plan-entry/{id}` (który ma `ge=0.1,
    le=20`), ręczne tworzenie wpisu (`POST /food-log/`) przyjmowało
    dosłownie cokolwiek, łącznie z wartościami ujemnymi albo absurdalnie
    dużymi. Górne granice są celowo hojne (np. 10000 kcal) — mają odciąć
    tylko oczywiście błędne dane, nie ograniczać rzadkich, ale prawdziwych
    przypadków (duży posiłek na kilka osób wpisany ręcznie).

    Ograniczeń NIE dajemy na `FoodLogEntryBase`/`FoodLogEntryResponse`
    (używane przy ODCZYCIE z bazy) — gdyby jakiś już istniejący wiersz
    miał wartość poza tym zakresem, zwykłe pobranie danych zwróciłoby
    błąd walidacji zamiast dane."""

    calories: float = Field(0.0, ge=0, le=10_000)
    protein: float = Field(0.0, ge=0, le=2_000)
    fat: float = Field(0.0, ge=0, le=2_000)
    carbs: float = Field(0.0, ge=0, le=2_000)
    servings: float = Field(1.0, ge=0.1, le=20)


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
