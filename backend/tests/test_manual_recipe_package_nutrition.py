from types import SimpleNamespace

from app.services.nutrition_calculator import (
    compute_recipe_nutrition_total,
    is_ingredient_quantity_reasonable,
    quantity_to_grams,
)


def test_one_package_uses_physical_package_weight() -> None:
    assert quantity_to_grams("Frytki", 1, "opak", 450) == 450


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
