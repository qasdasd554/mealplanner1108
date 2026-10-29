"""A declared ingredient amount must scale linearly in both markets."""
from types import SimpleNamespace

import pytest

from app.services.nutrition_calculator import (
    NutritionCalculator, compute_recipe_nutrition_total,
)


@pytest.mark.parametrize("name", ["Oliwa z oliwek", "Olive oil", "Olej rzepakowy", "Rapeseed oil"])
@pytest.mark.parametrize("grams", [20, 40, 60, 100])
def test_all_declared_oil_is_counted_without_guessing_frying_absorption(name, grams):
    oil = SimpleNamespace(name=name, serving_quantity=None, measure_options=None,
        nutrition_per_100={"kcal": 900, "protein": 0, "fat": 100, "carbs": 0, "fiber": 0})
    ingredient = SimpleNamespace(product=oil, quantity=grams, unit="g")
    for calculate in (compute_recipe_nutrition_total, NutritionCalculator.calculate_recipe_nutrition):
        totals = calculate([ingredient])
        assert totals["kcal"] == grams * 9
        assert totals["fat"] == grams


def test_salad_total_is_the_sum_of_its_ingredients_and_scales_to_more_servings():
    def ingredient(name, kcal, fat, grams):
        return SimpleNamespace(quantity=grams, unit="g", product=SimpleNamespace(
            name=name, serving_quantity=None, measure_options=None,
            nutrition_per_100={"kcal": kcal, "fat": fat, "carbs": 0, "protein": 0, "fiber": 0}))
    for people in (1, 3, 8):
        ingredients = [ingredient("Oliwa z oliwek", 900, 100, people * 20),
                       ingredient("Pomidory", 20, 0, people * 100)]
        assert compute_recipe_nutrition_total(ingredients)["kcal"] == people * 200
