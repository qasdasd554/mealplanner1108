"""Shared GB requirements, without Polish name-based weight/density guesses.

This is display/checkout arithmetic, not a change to the legacy PL nutrition
calculator. Unknown measures remain unknown in every consumer of this module.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, InvalidOperation, localcontext
import math
from typing import Any
from uuid import UUID

from app.services.uk_catalogue_import import canonical_base_unit


MAX_STORED_QUANTITY = Decimal("9999999.999")


def canonical_measure_code(unit: str) -> str:
    value = (unit or '').strip().casefold()
    return {
        'łyżeczka': 'lyzeczka', 'łyżeczki': 'lyzeczka', 'łyżeczek': 'lyzeczka',
        'tsp': 'lyzeczka', 'teaspoon': 'lyzeczka', 'teaspoons': 'lyzeczka',
        'łyżka': 'lyzka', 'łyżki': 'lyzka', 'łyżek': 'lyzka',
        'tbsp': 'lyzka', 'tablespoon': 'lyzka', 'tablespoons': 'lyzka',
        'szt.': 'szt', 'pcs': 'szt',
    }.get(value, value)


def _amount(value: Any) -> Decimal:
    if value is None or isinstance(value, bool):
        raise ValueError("A positive finite quantity is required")
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("A positive finite quantity is required")
        value = str(value)
    try:
        result = Decimal(value)
    except (InvalidOperation, TypeError, ValueError) as exc:
        raise ValueError("A positive finite quantity is required") from exc
    if not result.is_finite() or result <= 0:
        raise ValueError("A positive finite quantity is required")
    # Keep integer-ratio and exact arithmetic bounded before accepting API data.
    if len(result.as_tuple().digits) > 60 or abs(result.as_tuple().exponent) > 60:
        raise ValueError("Quantity precision exceeds the supported range")
    return result


def _multiply(left: Decimal, right: Decimal) -> Decimal:
    with localcontext() as arithmetic:
        arithmetic.prec = max(28, len(left.as_tuple().digits) + len(right.as_tuple().digits))
        return left * right


def _add(left: Decimal, right: Decimal) -> Decimal:
    with localcontext() as arithmetic:
        arithmetic.prec = max(
            28,
            max(left.adjusted(), right.adjusted())
            - min(left.as_tuple().exponent, right.as_tuple().exponent) + 2,
        )
        return left + right


def subtract_regional_quantity(left: Decimal, right: Decimal) -> Decimal:
    """Exact nonnegative deficit, also when the pantry leaves a tiny remainder."""
    if any(not isinstance(value, Decimal) or not value.is_finite() or value < 0
           for value in (left, right)):
        raise ValueError("Finite nonnegative Decimal quantities are required")
    return max(Decimal(0), _add(left, right.copy_negate()))


def to_regional_base_quantity(product: Any, quantity: Any, unit: str) -> tuple[Decimal, str]:
    """Use only an explicit compatible mass/volume or a persisted measure.

    A canonical package/default_quantity is NOT evidence for a household
    measure. No translated name, implicit serving size or g-to-ml conversion.
    """
    amount = _amount(quantity)
    unit = canonical_measure_code(unit)
    base_unit = canonical_base_unit(product)
    direct_unit = {"g": "g", "kg": "g", "ml": "ml", "l": "ml"}.get(unit)
    if direct_unit is not None:
        if direct_unit != base_unit:
            raise ValueError("Mass and volume require a proven product conversion")
        if unit in {"kg", "l"}:
            sign, digits, exponent = amount.as_tuple()
            amount = Decimal((sign, digits, exponent + 3))
    else:
        matches: set[tuple[Decimal, str]] = set()
        for option in product.measure_options or []:
            if not isinstance(option, dict) or canonical_measure_code(option.get("code")) != unit:
                continue
            if option.get("base_unit") != base_unit:
                raise ValueError("Measure dimension conflicts with the canonical product")
            matches.add((_amount(option.get("base_quantity")), base_unit))
        if not matches and unit == 'lyzka':
            # A metric tablespoon is three metric teaspoons. Use the product's
            # persisted teaspoon factor, never assume one gram per millilitre.
            for option in product.measure_options or []:
                if (isinstance(option, dict) and canonical_measure_code(option.get('code')) == 'lyzeczka'
                        and option.get('base_unit') == base_unit):
                    matches.add((_multiply(_amount(option.get('base_quantity')), Decimal(3)), base_unit))
        if len(matches) != 1:
            raise ValueError("An unambiguous persisted product measure is required")
        factor, _ = next(iter(matches))
        amount = _multiply(amount, factor)
    if amount > MAX_STORED_QUANTITY:
        raise ValueError("Quantity exceeds the shopping-list storage range")
    return amount, base_unit


@dataclass(frozen=True, slots=True)
class RegionalRequirement:
    product_id: UUID
    product: Any | None
    quantity: Decimal | None
    unit: str | None
    raw_quantity: Decimal | None
    raw_unit: str | None
    raw_amounts: tuple[tuple[Decimal, str], ...]


def aggregate_regional_requirements(plan: Any) -> dict[UUID, RegionalRequirement]:
    """Aggregate final entry multipliers once; do not divide by servings again.

    One unresolved ingredient poisons that product's quote instead of silently
    pricing its known fraction. Raw amounts permit an unpriced list display.
    """
    requirements: dict[UUID, RegionalRequirement] = {}
    for entry in plan.entries or []:
        recipe = entry.recipe
        if recipe is None:
            continue
        for ingredient in recipe.ingredients or []:
            product_id = ingredient.product_id
            if product_id is None:
                raise ValueError("A canonical ingredient product is required")
            product = ingredient.product
            previous = requirements.get(product_id)
            raw_amounts = previous.raw_amounts if previous else ()
            resolved_quantity = None
            resolved_unit = None
            try:
                multiplier = _amount(
                    1 if entry.servings_multiplier is None else entry.servings_multiplier
                )
                raw = _multiply(_amount(ingredient.quantity), multiplier)
                if raw > MAX_STORED_QUANTITY:
                    raise ValueError("Quantity exceeds the shopping-list storage range")
                raw_amounts += ((raw, ingredient.unit),)
                if product is not None:
                    resolved_quantity, resolved_unit = to_regional_base_quantity(
                        product, raw, ingredient.unit,
                    )
                if previous is not None:
                    if previous.quantity is None or resolved_unit != previous.unit:
                        resolved_quantity, resolved_unit = None, None
                    elif resolved_quantity is not None:
                        resolved_quantity = _add(previous.quantity, resolved_quantity)
                        if resolved_quantity > MAX_STORED_QUANTITY:
                            resolved_quantity, resolved_unit = None, None
            except (AttributeError, ValueError, InvalidOperation):
                resolved_quantity, resolved_unit = None, None
            same_raw_unit = bool(raw_amounts) and len({row[1] for row in raw_amounts}) == 1
            raw_total = Decimal(0)
            for raw_amount, _ in raw_amounts:
                raw_total = _add(raw_total, raw_amount)
            requirements[product_id] = RegionalRequirement(
                product_id=product_id, product=product or (previous.product if previous else None),
                quantity=resolved_quantity, unit=resolved_unit,
                raw_quantity=raw_total if same_raw_unit and raw_total <= MAX_STORED_QUANTITY else None,
                raw_unit=raw_amounts[0][1] if same_raw_unit else None,
                raw_amounts=raw_amounts,
            )
    return requirements
