from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.api.v1.products import _require_complete_recipe_nutrition
from app.api.v1.recipes import _product_has_complete_nutrition
from app.services.nutrition_calculator import (
    compute_recipe_nutrition_total,
    is_ingredient_quantity_reasonable,
    quantity_to_grams,
)


def test_one_package_uses_physical_package_weight() -> None:
    assert quantity_to_grams("Frytki", 1, "opak", 450) == 450


def test_unknown_package_never_falls_back_to_fake_100g() -> None:
    stale_options = [{
        "code": "opak",
        "label": "opakowanie",
        "base_quantity": 100,
        "base_unit": "g",
    }]

    assert quantity_to_grams("Pizza", 1, "opak", None, stale_options) == 0


def test_recipe_nutrition_for_package_is_not_zero() -> None:
    product = SimpleNamespace(
        name="Frytki",
        serving_quantity=450,
        nutrition_per_100={
            "kcal": 150,
            "protein": 3,
            "fat": 5,
            "carbs": 22,
            "fiber": 2,
        },
    )
    ingredient = SimpleNamespace(product=product, quantity=1, unit="opak")

    assert compute_recipe_nutrition_total([ingredient]) == {
        "kcal": 675.0,
        "protein": 13.5,
        "fat": 22.5,
        "carbs": 99.0,
        "fiber": 9.0,
    }


def test_one_hundred_packages_is_rejected_as_unreasonable() -> None:
    assert is_ingredient_quantity_reasonable(100, "opak") is False


def test_manual_recipe_rejects_unknown_nutrition_instead_of_saving_zeros() -> None:
    with pytest.raises(HTTPException) as error:
        _require_complete_recipe_nutrition({
            "kcal": 0,
            "protein": 0,
            "fat": 0,
            "carbs": 0,
        })

    assert error.value.status_code == 422
    assert "etykiety" in str(error.value.detail)


def test_manual_recipe_accepts_real_nutrition_with_valid_zero_macros() -> None:
    _require_complete_recipe_nutrition({
        "kcal": 42,
        "protein": 0,
        "fat": 0,
        "carbs": 10.5,
    })


def test_recipe_api_does_not_treat_placeholder_zeros_as_nutrition() -> None:
    product = SimpleNamespace(nutrition_per_100={
        "kcal": 0,
        "protein": 0,
        "fat": 0,
        "carbs": 0,
    })

    assert _product_has_complete_nutrition(product) is False


def test_recipe_api_accepts_complete_macros_with_individual_zeros() -> None:
    product = SimpleNamespace(nutrition_per_100={
        "kcal": 64,
        "protein": 4,
        "fat": 0,
        "carbs": 12,
    })

    assert _product_has_complete_nutrition(product) is True
