"""Actual PLN baskets need proven measures, not name-based weight guesses."""

import asyncio
from decimal import Decimal
from types import SimpleNamespace as NS
from uuid import uuid4

import pytest

from app.services.polish_list_prices import quote_polish_list


def quote(*, quantity=600, unit="g", product_unit="g", package=500,
          measures=None, price=5, name="Mąka"):
    store = NS(id=uuid4())
    product = NS(id=uuid4(), name=name, unit=product_unit,
                 default_quantity=package, serving_quantity=None,
                 measure_options=measures or [])
    offer = NS(store_id=store.id, product_id=product.id, price=price,
               is_available=True, withdrawn_at=None,
               store_brand_name=None, last_verified=None)
    row = NS(store_product=NS(product_id=product.id, product=product),
             custom_name=None, required_quantity=quantity, unit=unit,
             regional_snapshot=None, is_checked=False, is_from_pantry=False)

    class DB:
        async def execute(self, _):
            return NS(scalars=lambda: NS(unique=lambda: NS(all=lambda: [offer])))

    return asyncio.run(quote_polish_list(DB(), NS(items=[row]), [store]))[store.id][0][2]


@pytest.mark.parametrize("unit,product_unit", [("cup", "g"), ("cup", "cup"),
                                                ("szt", "g"), ("g", "szt"),
                                                ("g", "ml"), ("ml", "g")])
def test_unproven_measure_stays_unpriced(unit, product_unit):
    assert quote(quantity=2, unit=unit, product_unit=product_unit) is None


@pytest.mark.parametrize("unit,product_unit", [("szt", "szt"), ("szt.", "szt"),
                                                ("opak", "opak"), ("opakowanie", "opak")])
@pytest.mark.parametrize("quantity,count", [(2, 1), (12, 2)])
def test_same_count_unit_does_not_require_a_gram_weight(unit, product_unit, quantity, count):
    result = quote(name="Jajka", quantity=quantity, unit=unit,
                   product_unit=product_unit, package=10)
    assert result["package_count"] == count
    assert result["price_in_store"] == 5 * count
    assert result["quantity_needed"] == quantity


@pytest.mark.parametrize("quantity,unit,product_unit,package,count", [
    (600, "g", "g", 500, 2), (Decimal("0.6"), "kg", "g", 500, 2),
    (600, "g", "kg", Decimal("0.5"), 2), (1200, "ml", "l", 1, 2),
    (Decimal("500.0000000000000001"), "g", "g", 500, 2),
])
def test_compatible_mass_and_volume_round_to_whole_packages(quantity, unit, product_unit, package, count):
    result = quote(quantity=quantity, unit=unit, product_unit=product_unit, package=package)
    assert result["package_count"] == count
    assert result["price_in_store"] == 5 * count


@pytest.mark.parametrize("unit,factor,base,product_unit,quantity,package,count", [
    ("cup", 160, "g", "g", 4, 500, 2),
    ("szt", 50, "g", "g", 12, 500, 2),
    ("g", 50, "g", "szt", 600, 10, 2),
    ("g", 2, "ml", "ml", 600, 1000, 2),
    ("kg", 2, "ml", "ml", Decimal("0.6"), 1000, 2),
    ("ml", Decimal("0.5"), "g", "g", 1200, 500, 2),
])
def test_persisted_unambiguous_measure_allows_conversion(unit, factor, base, product_unit, quantity, package, count):
    code = "szt" if product_unit == "szt" else "g" if unit == "kg" else unit
    result = quote(quantity=quantity, unit=unit, product_unit=product_unit, package=package,
                   measures=[{"code": code, "base_quantity": factor, "base_unit": base}])
    assert result["package_count"] == count


@pytest.mark.parametrize("field", ["quantity", "package", "price"])
@pytest.mark.parametrize("value", [0, -1, float("nan"), float("inf"), Decimal("NaN"), True, None])
def test_invalid_numeric_values_stay_unpriced(field, value):
    assert quote(**{field: value}) is None


@pytest.mark.parametrize("measures", [
    [{"code": "cup", "base_quantity": float("nan"), "base_unit": "g"}],
    [{"code": "cup", "base_quantity": 0, "base_unit": "g"}],
    [{"code": "cup", "base_quantity": 160, "base_unit": "g"},
     {"code": "cup", "base_quantity": 200, "base_unit": "g"}],
    [{"code": "cup", "base_quantity": 160, "base_unit": "ml"}],
    [{"code": "g", "base_quantity": 2, "base_unit": "ml"},
     {"code": "g", "base_quantity": 3, "base_unit": "ml"}],
])
def test_invalid_or_ambiguous_persisted_conversion_stays_unpriced(measures):
    cross_dimension = measures[0]["code"] == "g"
    assert quote(quantity=2, unit="g" if cross_dimension else "cup",
                 product_unit="ml" if cross_dimension else "g", measures=measures) is None
