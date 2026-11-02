"""Regressions for the reported 3 pieces of cinnamon = 741 kcal error."""
from decimal import Decimal
from types import SimpleNamespace as NS
from uuid import uuid4

import pytest

from app.services.nutrition_calculator import compute_recipe_nutrition_total, quantity_to_grams
from app.services.product_measures import build_measure_options
from app.services.polish_shopping_amounts import item_price


def food(name="Cynamon", unit="g", pack=20, kcal=247):
    return NS(id=uuid4(), name=name, unit=unit, default_quantity=pack,
              serving_quantity=None, measure_options=build_measure_options(name, unit),
              nutrition_per_100=dict(kcal=kcal, protein=4, fat=1.2, carbs=80.6, fiber=53.1))


@pytest.mark.parametrize("name", ["Cynamon", "Cinnamon", "Mąka pszenna", "Wheat flour", "Olej rzepakowy", "Rapeseed oil", "Nieznana przyprawa"])
def test_unknown_piece_mass_never_invents_100g(name):
    assert quantity_to_grams(name, 3, "szt") == 0


def test_reported_741_kcal_is_unknown_instead_of_fabricated():
    ingredient = NS(product=food(), quantity=3, unit="szt")
    result = compute_recipe_nutrition_total([ingredient])
    assert result.get("_incomplete") is True
    assert result["kcal"] is None
    assert result["_known_totals"]["kcal"] == 0


@pytest.mark.parametrize("name", ["Cynamon", "Cinnamon"])
@pytest.mark.parametrize("unit,factor", [("łyżeczki", 2.6), ("tsp", 2.6), ("łyżki", 7.8), ("tbsp", 7.8)])
def test_named_kitchen_measures_use_product_specific_factor(name, unit, factor):
    p = food(name)
    amount = quantity_to_grams(name, 3, unit, None, p.measure_options)
    assert amount == pytest.approx(3 * factor)
    ingredient = NS(product=p, quantity=3, unit=unit)
    assert compute_recipe_nutrition_total([ingredient])["kcal"] == round(247 * amount / 100, 1)
    price = item_price(p, NS(price=Decimal("3.49")), 3, unit)
    assert price == (Decimal("3.49") if amount <= 20 else Decimal("6.98"))


def test_no_one_to_one_fallback_for_unknown_measures():
    assert quantity_to_grams("Cynamon", 3, "mystery scoops") == 0


def test_explicit_piece_weight_and_real_eggs_are_preserved():
    assert quantity_to_grams("Jajka", 3, "szt") == 150
    options = [dict(code="szt", base_quantity=4, base_unit="g")]
    assert quantity_to_grams("Laska cynamonu", 3, "szt", None, options) == 12


def test_conflicting_piece_metadata_is_not_arbitrarily_selected():
    options = [dict(code="szt", base_quantity=4, base_unit="g"),
               dict(code="szt", base_quantity=100, base_unit="g")]
    assert quantity_to_grams("Cynamon", 3, "szt", None, options) == 0


@pytest.mark.parametrize("name,instruction,expected", [
    ("Cynamon", "Dodaj cynamon (3 łyżeczki) do nadzienia.", 7.8),
    ("Cynamon", "Wymieszaj z 3 łyżeczkami cynamonu.", 7.8),
    ("Cinnamon", "Stir in 3 tsp cinnamon.", 7.8),
    ("Cynamon", "Stir in 3 tsp cinnamon.", 7.8),
    ("Mąka pszenna", "Wsyp mąkę pszenną (250 g).", 250),
    ("Cynamon", "Dodaj cukier (100 g) i cynamon (3 g).", 3),
])
def test_legacy_amount_is_recovered_only_from_an_explicit_named_source(name, instruction, expected):
    from app.services.recipe_amounts import repair_recipe_amounts
    ingredient = NS(product=food(name), quantity=3, unit="szt")
    recipe = NS(ingredients=[ingredient], instructions=[instruction], nutrition_total={"kcal": 741})
    assert repair_recipe_amounts(recipe)
    assert ingredient.quantity == pytest.approx(expected)
    assert ingredient.unit == "g"
    assert recipe.nutrition_total["kcal"] == round(247 * expected / 100, 1)
    assert not repair_recipe_amounts(recipe)  # repeat-safe


@pytest.mark.parametrize("instruction", [
    "Dodaj cukier (100 g) i cynamon.",
    "Upiecz 3 cynamonki. Dodaj cynamon do smaku.",
    "Dodaj cynamon (3 g), a później cynamon (5 g).",
    "Dodaj 3 łyżeczki cukru cynamonowego.",
    "Dodaj 3 sztuki cynamonu.",
])
def test_ambiguous_or_unrelated_source_does_not_invent_a_repair(instruction):
    from app.services.recipe_amounts import repair_recipe_amounts
    ingredient = NS(product=food(), quantity=3, unit="szt")
    recipe = NS(ingredients=[ingredient], instructions=[instruction], nutrition_total={"kcal": 741})
    repair_recipe_amounts(recipe)
    assert ingredient.quantity == 3 and ingredient.unit == "szt"
    assert recipe.nutrition_total["_incomplete"] is True
    assert recipe.nutrition_total["kcal"] is None


def test_valid_recipe_amount_is_never_overwritten_from_cooking_steps():
    from app.services.recipe_amounts import repair_recipe_amounts
    ingredient = NS(product=food(), quantity=10, unit="g")
    recipe = NS(ingredients=[ingredient], instructions=["Posyp cynamonem (3 g)."], nutrition_total={"kcal": 24.7})
    assert not repair_recipe_amounts(recipe)
    assert ingredient.quantity == 10 and ingredient.unit == "g"


@pytest.mark.parametrize("unit", ["szt", "szt.", "pieces", "opakowanie", "pack"])
def test_count_unit_alias_cannot_bypass_the_quantity_limit(unit):
    from app.services.nutrition_calculator import is_ingredient_quantity_reasonable
    assert not is_ingredient_quantity_reasonable(200, unit)


@pytest.mark.parametrize("unit", ["kg", "l"])
def test_large_metric_units_use_the_same_physical_limit_as_grams(unit):
    from app.services.nutrition_calculator import is_ingredient_quantity_reasonable
    assert not is_ingredient_quantity_reasonable(20000, unit)
    assert is_ingredient_quantity_reasonable(20, unit)


def test_all_system_recipes_share_seed_and_runtime_conversions():
    from app.db.seed import PRODUCTS_DATA, NUTRITION_DATA, RECIPES_DATA, calculate_nutrition
    units = {row[0]: row[1] for row in PRODUCTS_DATA}
    for recipe in RECIPES_DATA:
        ingredients = []
        for name, quantity, unit, *_ in recipe["ingredients"]:
            product = NS(name=name, unit=units[name], serving_quantity=None,
                measure_options=build_measure_options(name, units[name]), nutrition_per_100=NUTRITION_DATA[name])
            ingredient = NS(product=product, quantity=quantity, unit=unit)
            total = compute_recipe_nutrition_total([ingredient])
            assert not total.get("_incomplete"), (recipe["name"], name, quantity, unit)
            seeded = calculate_nutrition(name, quantity, unit)
            for key in ("kcal", "protein", "fat", "carbs", "fiber"):
                assert total[key] == round(seeded[key], 1), (recipe["name"], name, key)
            ingredients.append(ingredient)
        assert not compute_recipe_nutrition_total(ingredients).get("_incomplete")


def test_seed_cannot_reintroduce_100g_for_an_unknown_count():
    from app.db.seed import calculate_nutrition
    with pytest.raises(ValueError, match="Unknown physical amount"):
        calculate_nutrition("Cynamon", 3, "szt")
