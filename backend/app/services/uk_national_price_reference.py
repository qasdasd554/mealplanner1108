"""Offline ONS quantity reference. Not shop stock, a SKU or actual packaging.

An explicit ONS label is required. No fuzzy food matching, Polish currency
conversion, retailer multipliers, external request or DB write occurs here.
The source month stays visible; this is not a claim of today's shelf price.
"""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_UP, localcontext
from functools import lru_cache
import json
from pathlib import Path
import re


@lru_cache(maxsize=1)
def reference_dataset():
    return json.loads((Path(__file__).resolve().parents[1] /
        "data/uk_ons_price_references_20261024.json").read_text(encoding="utf-8"))


@dataclass(frozen=True)
class NationalQuantityReference:
    name: str
    cost_gbp: Decimal
    period: str
    reference_unit: str
    source_url: str
    is_estimated: bool = True
    retailer_price: bool = False
    confirms_package: bool = False


def _reference_unit(value):
    if value == "each":
        return Decimal(1), "szt"
    if not isinstance(value, str):
        return None
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?) (g|kg|ml|l|pack)", value)
    if match is None:
        return None
    amount, unit = Decimal(match[1]), match[2]
    if unit in {"kg", "l"}:
        amount *= 1000
    return amount, {"kg": "g", "l": "ml", "pack": "szt"}.get(unit, unit)


def estimate_reference_quantity(name, quantity, unit, *, as_of: date):
    if isinstance(quantity, (bool, float)) or type(as_of) is not date:
        return None
    try:
        amount = Decimal(quantity)
        if (not amount.is_finite() or not 0 < amount <= Decimal("1000000000")
                or len(amount.as_tuple().digits) > 32 or abs(amount.as_tuple().exponent) > 12):
            return None
        if unit in {"kg", "l"}:
            amount *= 1000
        target_unit = {"kg": "g", "l": "ml", "szt.": "szt"}.get(unit, unit)
        if target_unit not in {"g", "ml", "szt"}:
            return None
        data = reference_dataset()
        if date.fromisoformat(data["retrieved_on"]) > as_of:
            return None
        matches = [row for row in data["records"] if row["name"] == name]
        if len(matches) != 1:
            return None
        row, = matches
        if row["price_gbp"] is None or row["period"] > as_of.strftime("%Y-%m"):
            return None
        reference = _reference_unit(row["reference_unit"])
        if reference is None or reference[1] != target_unit or reference[0] <= 0:
            return None
        with localcontext() as arithmetic:
            arithmetic.prec = 48
            cost = (Decimal(row["price_gbp"]) * amount / reference[0]).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        return NationalQuantityReference(name=name, cost_gbp=cost, period=row["period"],
            reference_unit=row["reference_unit"], source_url=data["source_url"])
    except (ValueError, TypeError, ArithmeticError):
        return None
