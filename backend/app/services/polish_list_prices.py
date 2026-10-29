"""Quote actual PLN list rows without rebuilding a technical meal plan.

Unknown identities/weights/prices stay unknown. In particular, matching a
custom name to the first similar catalogue item could buy a different meal.
"""

import math
from decimal import Decimal, InvalidOperation, localcontext

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.models import StoreProduct
from app.services.regional_requirements import MAX_STORED_QUANTITY, to_regional_base_quantity
from app.services.uk_catalogue_import import canonical_base_unit


def _positive(value):
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (ValueError, TypeError, OverflowError):
        return None
    return number if math.isfinite(number) and number > 0 else None


def _amount(value):
    if isinstance(value, bool):
        raise ValueError("A positive finite quantity is required")
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise ValueError("A positive finite quantity is required") from exc
    if not amount.is_finite() or not 0 < amount <= MAX_STORED_QUANTITY:
        raise ValueError("A positive finite quantity within storage limits is required")
    if len(amount.as_tuple().digits) > 60 or abs(amount.as_tuple().exponent) > 60:
        raise ValueError("Quantity precision exceeds the supported range")
    return amount


def _base_quantity(product, amount, unit):
    try:
        return to_regional_base_quantity(product, amount, unit)
    except ValueError:
        # The regional helper deliberately rejects cross-dimension inputs.
        # PLN can use an explicit persisted g/ml factor, never a density guess.
        base_unit = canonical_base_unit(product)
        dimensions = {"g": "g", "kg": "g", "ml": "ml", "l": "ml"}
        if unit not in dimensions or dimensions[unit] == base_unit:
            raise
        options = [option for option in product.measure_options or []
                   if isinstance(option, dict) and option.get("code") == unit]
        scale = Decimal(1)
        if not options and unit in {"kg", "l"}:
            options = [option for option in product.measure_options or []
                       if isinstance(option, dict) and option.get("code") == dimensions[unit]]
            scale = Decimal(1000)
        if not options or any(option.get("base_unit") != base_unit for option in options):
            raise ValueError("A persisted mass/volume conversion is required")
        factors = {_amount(option.get("base_quantity")) for option in options}
        if len(factors) != 1:
            raise ValueError("The persisted conversion is ambiguous")
        factor = next(iter(factors))
        with localcontext() as arithmetic:
            arithmetic.prec = max(28, sum(len(value.as_tuple().digits) for value in (amount, scale, factor)))
            converted = amount * scale * factor
        return _amount(converted), base_unit


def _package_count(product, quantity, unit):
    amount, package = _amount(quantity), _amount(product.default_quantity)
    count_units = {"szt": "szt", "szt.": "szt", "opak": "opak", "opakowanie": "opak"}
    if unit in count_units and count_units.get(product.unit) == count_units[unit]:
        required, packed = amount, package
    else:
        required, dimension = _base_quantity(product, amount, unit)
        packed, package_dimension = _base_quantity(product, package, product.unit)
        if dimension != package_dimension:
            raise ValueError("The required quantity and package have different dimensions")
    # Exact ratios avoid losing a final package through float rounding.
    required_n, required_d = required.as_integer_ratio()
    packed_n, packed_d = packed.as_integer_ratio()
    numerator, denominator = required_n * packed_d, packed_n * required_d
    return (numerator + denominator - 1) // denominator


async def quote_polish_list(db, shopping, stores):
    """One bounded price query; return (row, target offer, quote) per store."""
    product_ids = {row.store_product.product_id for row in shopping.items if row.store_product is not None}
    offers = list((await db.execute(select(StoreProduct).where(
        StoreProduct.store_id.in_([store.id for store in stores]),
        StoreProduct.product_id.in_(product_ids),
    ).options(joinedload(StoreProduct.department), joinedload(StoreProduct.product)))).scalars().unique().all()) if product_ids else []
    by_pair = {(offer.store_id, offer.product_id): offer for offer in offers}
    results = {}
    for store in stores:
        rows = []
        for row in shopping.items:
            original = row.store_product
            product = original.product if original is not None else None
            name = product.name if product is not None else row.custom_name or "Nieznany produkt"
            quantity = _positive(row.required_quantity)
            quote, offer = None, None
            if row.regional_snapshot is not None or quantity is None:
                pass  # Never reinterpret a foreign or corrupt row as PLN.
            elif row.is_from_pantry:
                if row.is_checked and row.estimated_price == Decimal(0):
                    quote = dict(product_name=name, quantity_needed=quantity, unit=row.unit,
                                 price_in_store=0, price_is_estimated=False, is_from_pantry=True, is_checked=True)
            elif row.is_checked:
                price = _positive(row.estimated_price)
                if product is not None and price is not None:
                    # Preserve the purchase already saved by the user. Legacy
                    # PLN rows do not store historical package provenance.
                    quote = dict(product_name=name, quantity_needed=quantity, unit=row.unit,
                                 price_in_store=price, price_is_estimated=True, is_checked=True,
                                 store_brand_name=original.store_brand_name)
            elif product is not None:
                offer = by_pair.get((store.id, product.id))
                if offer is not None and offer.is_available and offer.withdrawn_at is None:
                    price = _positive(offer.price)
                    try:
                        count = _package_count(product, row.required_quantity, row.unit)
                        total = _positive(price * count) if price is not None else None
                    except (ValueError, InvalidOperation, OverflowError, TypeError):
                        total = None
                    if total is not None:
                        quote = dict(product_name=name, quantity_needed=quantity, unit=row.unit,
                                     price_in_store=round(total, 2), package_count=count,
                                     price_per_package=price, store_brand_name=offer.store_brand_name,
                                     price_is_estimated=offer.last_verified is None, last_verified=offer.last_verified)
            rows.append((row, offer, quote))
        results[store.id] = rows
    return results
