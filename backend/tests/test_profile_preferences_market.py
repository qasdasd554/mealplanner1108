"""Localised messages do not change Premium gates, validation or calculations."""

import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.users import (CalorieCalculatorRequest,
    calculate_calorie_needs_endpoint, update_ingredient_preferences)
from app.schemas.user import IngredientPreferencesUpdate
from tests.test_plan_preferences_and_limits import _user


@pytest.mark.parametrize("country,expected", [
    ("PL", "Preferencje składników są dostępne w aktywnym Premium."),
    ("GB", "Ingredient preferences require active Premium."),
])
def test_expired_premium_keeps_same_gate_without_db_queries(country, expected):
    db = SimpleNamespace(execute=AsyncMock(), commit=AsyncMock())
    user = _user(country_code=country, is_premium=False)
    with pytest.raises(HTTPException) as error:
        asyncio.run(update_ingredient_preferences(IngredientPreferencesUpdate(), user, db))
    assert error.value.status_code == 403 and error.value.detail == expected
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.parametrize("country,expected", [
    ("PL", "Wybierz składniki z zatwierdzonego katalogu produktów."),
    ("GB", "Choose ingredients from the approved product catalogue."),
])
def test_invalid_selection_keeps_same_validation_and_never_saves(country, expected):
    result = MagicMock()
    result.all.return_value = []
    db = SimpleNamespace(execute=AsyncMock(return_value=result), commit=AsyncMock())
    user = _user(country_code=country)
    payload = IngredientPreferencesUpdate(liked_product_ids=[uuid4()])
    with pytest.raises(HTTPException) as error:
        asyncio.run(update_ingredient_preferences(payload, user, db))
    assert error.value.status_code == 400 and error.value.detail == expected
    assert db.execute.await_count == 1
    db.commit.assert_not_awaited()
    assert user.ingredient_preferences == {}


def test_calculator_has_identical_canonical_response_in_both_markets():
    payload = CalorieCalculatorRequest(weight_kg=70.5, height_cm=175, age=30,
                                      gender="male", activity_level="light")
    polish = asyncio.run(calculate_calorie_needs_endpoint(payload, _user(country_code="PL")))
    british = asyncio.run(calculate_calorie_needs_endpoint(payload, _user(country_code="GB")))
    assert british == polish == {"maintenance": 2274, "weight_loss": 1774, "weight_gain": 2774}
