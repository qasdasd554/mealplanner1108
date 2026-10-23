from decimal import Decimal
from types import SimpleNamespace as NS
from uuid import uuid4

import pytest

from app.services.regional_requirements import aggregate_regional_requirements, to_regional_base_quantity, subtract_regional_quantity


def product(unit="g", options=None, name="Milk is not a density conversion"):
    return NS(id=uuid4(), unit=unit, measure_options=options or [], name=name,
              default_quantity=100, serving_quantity=500)


def plan(item, rows):
    return NS(entries=[NS(servings_multiplier=multiplier,
                          recipe=NS(servings=8, ingredients=[
                              NS(product_id=item.id, product=item, quantity=quantity, unit=unit)
                          ])) for quantity, unit, multiplier in rows])


@pytest.mark.parametrize("unit,quantity,expected,base", [
    ("g", "150", "150", "g"), ("kg", "0.25", "250", "g"),
    ("ml", "150", "150", "ml"), ("l", "1.136", "1136", "ml"),
])
def test_explicit_units_are_exact(unit, quantity, expected, base):
    assert to_regional_base_quantity(product(base), quantity, unit) == (Decimal(expected), base)


@pytest.mark.parametrize("unit", ["opak", "szt", "lyzeczka", "szklanka", "porcja", "cups", ""])
def test_default_and_serving_sizes_are_not_implicit_measures(unit):
    with pytest.raises(ValueError):
        to_regional_base_quantity(product(), "1", unit)


@pytest.mark.parametrize("quantity", [True, 0, -1, "NaN", "Infinity", float("nan"), None, "1e-1000000"])
def test_invalid_or_unbounded_amounts_are_rejected(quantity):
    with pytest.raises(ValueError):
        to_regional_base_quantity(product(), quantity, "g")


def test_finite_api_float_is_converted_through_its_decimal_text():
    assert to_regional_base_quantity(product(), 0.1, "kg") == (Decimal("100"), "g")


def test_measure_uses_explicit_local_dimension_not_product_name():
    item = product("ml", [{"code": "szklanka", "base_quantity": "250", "base_unit": "ml"}])
    assert to_regional_base_quantity(item, "2", "szklanka") == (Decimal("500"), "ml")
    with pytest.raises(ValueError):
        to_regional_base_quantity(item, "500", "g")


def test_conflicting_measures_and_dimensions_cannot_be_priced():
    for options in [
        [{"code": "opak", "base_quantity": 500, "base_unit": "ml"}],
        [{"code": "opak", "base_quantity": 500, "base_unit": "g"},
         {"code": "opak", "base_quantity": 600, "base_unit": "g"}],
    ]:
        with pytest.raises(ValueError):
            to_regional_base_quantity(product(options=options), 1, "opak")


def test_mixed_mass_units_and_final_multiplier_are_aggregated_only_once():
    item = product()
    result = aggregate_regional_requirements(plan(item, [("100", "g", "2"), ("0.25", "kg", "0.5")]))[item.id]
    assert result.quantity == Decimal("325")
    assert result.unit == "g"
    assert result.raw_quantity is None
    assert result.raw_unit is None
    assert result.raw_amounts == ((Decimal("200"), "g"), (Decimal("0.125"), "kg"))


def test_unknown_measure_poisoning_is_independent_of_entry_order():
    item = product()
    for rows in [[("100", "g", 1), ("1", "opak", 1)], [("1", "opak", 1), ("100", "g", 1)]]:
        result = aggregate_regional_requirements(plan(item, rows))[item.id]
        assert result.quantity is None
        assert result.unit is None
        assert len(result.raw_amounts) == 2


def test_unknown_same_unit_retains_raw_quantity_without_guessing_mass():
    item = product()
    result = aggregate_regional_requirements(plan(item, [(1, "opak", 2), (2, "opak", 1)]))[item.id]
    assert result.quantity is None
    assert result.raw_quantity == 4
    assert result.raw_unit == "opak"


def test_missing_canonical_product_is_not_silently_omitted():
    item = product()
    entry = plan(item, [(100, "g", 1)])
    entry.entries[0].recipe.ingredients[0].product = None
    result = aggregate_regional_requirements(entry)[item.id]
    assert result.product is None
    assert result.quantity is None
    assert result.raw_quantity == 100


def test_zero_multiplier_is_not_replaced_by_one():
    item = product()
    assert aggregate_regional_requirements(plan(item, [(100, "g", 0)]))[item.id].quantity is None


def test_storage_range_and_large_precision_do_not_round_a_remainder_away():
    item = product()
    assert to_regional_base_quantity(item, "0.5000000000000000000000000000001", "kg")[0] == Decimal("500.0000000000000000000000000001")
    with pytest.raises(ValueError):
        to_regional_base_quantity(item, "10000", "kg")
    result = aggregate_regional_requirements(plan(item, [("9999999", "g", 1), (1, "g", 1)]))[item.id]
    assert result.quantity is None


def test_pantry_deficit_does_not_erase_a_tiny_remainder():
    assert subtract_regional_quantity(Decimal("500.0000000000000000000000000001"), Decimal(500)) == Decimal("1e-28")
    assert subtract_regional_quantity(Decimal(500), Decimal(500)) == 0
    assert subtract_regional_quantity(Decimal(500), Decimal(600)) == 0


@pytest.mark.parametrize("left,right", [(0.1, Decimal(0)), (Decimal(1), Decimal(-1)), (Decimal("NaN"), Decimal(0))])
def test_pantry_deficit_requires_exact_nonnegative_finite_operands(left, right):
    with pytest.raises(ValueError):
        subtract_regional_quantity(left, right)
