"""Official national averages are planning references, never fake store offers."""

from datetime import date
from decimal import Decimal

import pytest

from app.services.uk_national_price_reference import estimate_reference_quantity, reference_dataset


TODAY = date(2026, 10, 24)


def test_source_projection_keeps_real_missing_values_and_no_merchant_claims():
    data = reference_dataset()
    assert data["publisher"] == "Office for National Statistics"
    assert data["licence"] == "OGL-3.0" and data["currency"] == "GBP"
    assert data["source_sha256"] == "e52e1d5f28122c70af428556717e4b6ff5f880272756d0e47bfe3dbdf8c95289"
    assert len(data["records"]) == 200
    assert sum(row["price_gbp"] is None for row in data["records"]) == 1
    assert data["retailer_prices"] is False and data["confirms_availability"] is False
    assert data["units_are_actual_packages"] is False


@pytest.mark.parametrize("label,quantity,unit,total", [
    ("Onions", "250", "g", "0.29"),
    ("Milk - cow's (semi-skimmed, fresh)", "568", "ml", "0.57"),
    ("Bananas", "1", "kg", "1.13"),
    ("Eggs - free-range", "2", "szt", "0.66"),
    ("Lemons", "2", "szt", "0.74"),
])
def test_only_explicit_compatible_quantity_is_costed(label, quantity, unit, total):
    result = estimate_reference_quantity(label, Decimal(quantity), unit, as_of=TODAY)
    assert result is not None and result.cost_gbp == Decimal(total)
    assert result.period == "2026-09" and result.is_estimated is True
    assert result.retailer_price is False and result.confirms_package is False


@pytest.mark.parametrize("label,quantity,unit", [
    ("Onions", "1", "opak"), ("Onions", "1", "szt"),
    ("Onions", "100", "ml"), ("Milk - cow's (semi-skimmed, fresh)", "100", "g"),
    ("Eggs - free-range", "100", "g"),
    ("Skimmed or semi-skimmed milk of cows, delivered", "1", "l"),
    ("Flour - plain", "100", "g"),  # self-raising flour is NOT a substitute.
    ("Potato chips", "100", "g"),  # never fuzzily price with raw potatoes.
])
def test_missing_price_or_identity_or_measure_does_not_become_zero(label, quantity, unit):
    assert estimate_reference_quantity(label, Decimal(quantity), unit, as_of=TODAY) is None


@pytest.mark.parametrize("quantity", [True, False, "NaN", "Infinity", "-1", "0", "1e1000000"])
def test_invalid_amount_is_rejected_without_expensive_arithmetic(quantity):
    assert estimate_reference_quantity("Onions", quantity, "g", as_of=TODAY) is None


def test_dataset_cannot_be_used_as_if_it_were_already_available_before_retrieval():
    assert estimate_reference_quantity("Onions", "100", "g", as_of=date(2026, 9, 1)) is None
