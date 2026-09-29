"""Regresje dla fizycznej ilości produktu w Dzienniku."""

from datetime import date

import pytest
from pydantic import ValidationError

from app.api.v1.food_log import FoodLogNutritionUpdate
from app.schemas.food_log import FoodLogEntryCreate


def test_food_log_accepts_grams_and_portion_size() -> None:
    entry = FoodLogEntryCreate(
        date=date(2026, 9, 29),
        meal_type="Przekąska",
        custom_name="Jogurt truskawkowy",
        calories=228,
        protein=3.6,
        fat=14.4,
        carbs=20.85,
        servings=1,
        amount_value=150,
        amount_unit="g",
        portion_size=150,
    )

    assert entry.amount_value == 150
    assert entry.amount_unit == "g"
    assert entry.portion_size == 150


def test_food_log_update_accepts_millilitres() -> None:
    update = FoodLogNutritionUpdate(
        calories=90,
        protein=3,
        fat=2,
        carbs=12,
        servings=0.5,
        amount_value=150,
        amount_unit="ml",
        portion_size=300,
    )

    assert update.amount_value == 150
    assert update.servings == 0.5


def test_food_log_rejects_unknown_amount_unit() -> None:
    with pytest.raises(ValidationError):
        FoodLogEntryCreate(
            date=date(2026, 9, 29),
            meal_type="Przekąska",
            custom_name="Produkt",
            amount_value=1,
            amount_unit="kg",
        )
