"""Regresje przenoszenia zapotrzebowania między zakupami a spiżarnią."""

from decimal import Decimal
from types import SimpleNamespace

from app.services.pantry_shopping_sync import split_required_quantity


def test_pantry_covers_whole_product_and_is_idempotent() -> None:
    product = SimpleNamespace(name="Mąka pszenna", unit="kg")
    rows = [
        SimpleNamespace(required_quantity=Decimal("0.300"), unit="kg"),
        SimpleNamespace(required_quantity=Decimal("0.700"), unit="kg"),
    ]
    pantry = SimpleNamespace(quantity=None, unit=None)

    assert split_required_quantity(product, rows, pantry) == (
        Decimal("1.000"), Decimal("0.000")
    )


def test_pantry_shortage_keeps_purchase_remainder() -> None:
    product = SimpleNamespace(name="Mąka pszenna", unit="kg")
    rows = [SimpleNamespace(required_quantity=Decimal("1.000"), unit="kg")]
    pantry = SimpleNamespace(quantity=Decimal("0.250"), unit="kg")

    assert split_required_quantity(product, rows, pantry) == (
        Decimal("0.250"), Decimal("0.750")
    )


def test_removing_from_pantry_restores_purchase() -> None:
    product = SimpleNamespace(name="Mąka pszenna", unit="kg")
    rows = [SimpleNamespace(required_quantity=Decimal("1.000"), unit="kg")]

    assert split_required_quantity(product, rows, None) == (
        Decimal("0.000"), Decimal("1.000")
    )
