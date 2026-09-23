"""Regresje limitu tygodniowego, spiżarni i bezstratnego łączenia list."""

import asyncio
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from fastapi import HTTPException

from app.api.v1.shopping_lists import shopping_item_merge_key
from app.schemas.shopping_list import ShoppingListItemResponse
from app.services.shopping_list_builder import pantry_coverage_grams
from app.services.shopping_list_quota import (
    calendar_week_start, can_append_recipes_to_existing_list,
    can_create_shopping_list, record_shopping_list_creation,
)


def test_calendar_week_starts_on_monday() -> None:
    assert calendar_week_start(date(2026, 9, 21)) == date(2026, 9, 21)
    assert calendar_week_start(date(2026, 9, 27)) == date(2026, 9, 21)
    assert calendar_week_start(date(2026, 9, 28)) == date(2026, 9, 28)


def test_standard_user_cannot_create_second_list_in_same_week() -> None:
    user = SimpleNamespace(id=uuid4(), role="user", is_premium=False)
    count_result = SimpleNamespace(scalar_one=lambda: 1)
    db = SimpleNamespace(
        execute=AsyncMock(side_effect=[None, count_result]),
        add=MagicMock(), flush=AsyncMock(),
    )
    try:
        asyncio.run(record_shopping_list_creation(
            db, user=user, shopping_list_id=uuid4(),
        ))
    except HTTPException as exc:
        assert exc.status_code == 403
    else:
        raise AssertionError("Druga darmowa lista w tym tygodniu musi być odrzucona")
    db.add.assert_not_called()


def test_standard_user_can_create_first_list_in_week() -> None:
    user = SimpleNamespace(id=uuid4(), role="user", is_premium=False)
    count_result = SimpleNamespace(scalar_one=lambda: 0)
    db = SimpleNamespace(execute=AsyncMock(side_effect=[None, count_result]))
    assert asyncio.run(can_create_shopping_list(db, user=user)) is True


def test_premium_can_create_list_without_weekly_count_query() -> None:
    user = SimpleNamespace(id=uuid4(), role="admin")
    db = SimpleNamespace(execute=AsyncMock(), add=MagicMock(), flush=AsyncMock())
    asyncio.run(record_shopping_list_creation(
        db, user=user, shopping_list_id=uuid4(),
    ))
    db.execute.assert_not_called()
    db.add.assert_called_once()
    db.flush.assert_awaited_once()


def test_standard_cannot_append_whole_recipe_to_existing_list() -> None:
    user = SimpleNamespace(id=uuid4(), role="user", is_premium=False)
    assert can_append_recipes_to_existing_list(user) is False


def test_admin_can_append_whole_recipe_to_existing_list() -> None:
    user = SimpleNamespace(id=uuid4(), role="admin")
    assert can_append_recipes_to_existing_list(user) is True


def test_pantry_covers_only_available_amount() -> None:
    pantry = SimpleNamespace(quantity=Decimal("0.15"), unit="kg")
    assert pantry_coverage_grams("Mąka", 250, pantry, "g") == 150
    assert pantry_coverage_grams("Mąka", 100, pantry, "g") == 100
    assert pantry_coverage_grams("Mąka", 250, None, "g") == 0


def test_pantry_without_quantity_means_product_is_available() -> None:
    pantry = SimpleNamespace(quantity=None, unit=None)
    assert pantry_coverage_grams("Mąka", 250, pantry, "g") == 250


def test_pantry_item_is_last_section_with_zero_price() -> None:
    item = SimpleNamespace(
        id="00000000-0000-0000-0000-000000000001",
        store_product=None,
        custom_name="Mąka",
        required_quantity=Decimal("150"),
        unit="g",
        estimated_price=Decimal("0"),
        is_checked=True,
        is_from_pantry=True,
    )
    response = ShoppingListItemResponse.model_validate(item)
    assert response.department_name == "W spiżarni"
    assert response.estimated_price == 0
    assert response.is_from_pantry


def test_merge_does_not_collapse_checked_and_unchecked_portions() -> None:
    base = dict(
        is_from_pantry=False,
        store_product_id=None,
        custom_name="  Ryż ",
        unit="g",
        department_id=None,
        substituted_for=None,
    )
    checked = SimpleNamespace(**base, is_checked=True)
    unchecked = SimpleNamespace(**base, is_checked=False)
    assert shopping_item_merge_key(checked) != shopping_item_merge_key(unchecked)
    assert shopping_item_merge_key(unchecked) == shopping_item_merge_key(
        SimpleNamespace(**{**base, "custom_name": "ryż"}, is_checked=False)
    )
