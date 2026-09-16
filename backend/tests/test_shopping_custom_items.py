"""Regresje dla pozycji listy zakupów wpisywanych z klawiatury."""

import uuid
from decimal import Decimal
from types import SimpleNamespace

from app.schemas.shopping_list import ShoppingListItemResponse


def test_custom_item_is_serialized_without_catalog_product() -> None:
    item = SimpleNamespace(
        id=uuid.uuid4(),
        store_product=None,
        custom_name="Papier toaletowy",
        required_quantity=Decimal("1"),
        unit="szt",
        estimated_price=None,
        is_checked=False,
    )

    response = ShoppingListItemResponse.model_validate(item)

    assert response.product_id is None
    assert response.product_name == "Papier toaletowy"
    assert response.department_name == "Inne"
    assert response.estimated_price is None
