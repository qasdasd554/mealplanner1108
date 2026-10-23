"""Common diary/pantry failures use account language with unchanged guards."""

from datetime import date, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1 import food_log, pantry, products
from app.core.exceptions import NotFoundException
from app.schemas.food_log import FoodLogEntryCreate


def _user(country):
    return SimpleNamespace(id=uuid4(), country_code=country, role="user", is_premium=False)


def _db(*, entry=None):
    result = MagicMock()
    result.scalar_one_or_none.return_value = entry
    return SimpleNamespace(get=AsyncMock(return_value=entry), execute=AsyncMock(return_value=result),
        add=MagicMock(), commit=AsyncMock(), delete=AsyncMock(), flush=AsyncMock())


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_diary_history_limit_keeps_the_same_account_day_and_status(monkeypatch, country):
    monkeypatch.setattr(food_log, "market_today", lambda user: date(2026, 10, 22))
    with pytest.raises(HTTPException) as failure:
        food_log._enforce_history_limit(date(2026, 9, 1), _user(country))
    assert failure.value.status_code == 403
    assert failure.value.detail == ("Free accounts can view the last 30 days of history. Unlock Premium to see older entries."
        if country == "GB" else "Darmowe konto ma dostęp do ostatnich 30 dni historii. Odblokuj Premium, aby zobaczyć starsze wpisy.")
    food_log._enforce_history_limit(date(2026, 10, 22) - timedelta(days=30), _user(country))


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_diary_missing_input_does_not_write(country):
    db = _db()
    with pytest.raises(HTTPException) as failure:
        await food_log.create_food_log_entry(FoodLogEntryCreate(date=date(2026, 10, 22), meal_type="obiad"), db, _user(country))
    assert failure.value.status_code == 400
    assert failure.value.detail == ("Choose a recipe (recipe_id) or enter a meal name (custom_name)" if country == "GB"
        else "Podaj przepis (recipe_id) albo własną nazwę posiłku (custom_name)")
    db.get.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["update", "delete", "plan"])
@pytest.mark.parametrize("exists", [False, True])
async def test_diary_missing_or_foreign_entries_do_not_mutate(country, operation, exists):
    entry = SimpleNamespace(user_id=uuid4(), meal_plan=SimpleNamespace(user_id=uuid4())) if exists else None
    db = _db(entry=entry)
    with pytest.raises(HTTPException) as failure:
        if operation == "update":
            await food_log.update_food_log_entry_nutrition(uuid4(), food_log.FoodLogNutritionUpdate(calories=100), db, _user(country))
        elif operation == "delete":
            await food_log.delete_food_log_entry(uuid4(), db, _user(country))
        else:
            await food_log.create_from_meal_plan_entry(uuid4(), None, None, db, _user(country))
    assert failure.value.status_code == (403 if exists else 404)
    english = {"update": "You cannot edit this diary entry.", "delete": "You cannot delete this diary entry.", "plan": "You do not have access to this meal plan entry."}
    polish = {"update": "Brak uprawnień do edycji tego wpisu", "delete": "Brak uprawnień do usunięcia tego wpisu", "plan": "Brak uprawnień do tej pozycji planu posiłków"}
    expected = (english if country == "GB" else polish)[operation] if exists else (
        ("Meal plan entry not found." if country == "GB" else "Nie znaleziono pozycji planu posiłków") if operation == "plan"
        else ("Diary entry not found." if country == "GB" else "Nie znaleziono wpisu w dzienniku"))
    assert failure.value.detail == expected
    db.add.assert_not_called()
    db.delete.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_pantry_empty_add_keeps_400_and_zero_database_io(country):
    db = _db()
    with pytest.raises(HTTPException) as failure:
        await pantry.add_pantry_items(pantry.AddPantryItemsRequest(product_ids=[]), _user(country), db)
    assert failure.value.status_code == 400
    assert failure.value.detail == ("Choose at least one product." if country == "GB" else "Podaj przynajmniej jeden produkt")
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("operation", ["update", "delete"])
async def test_pantry_missing_or_someone_elses_item_keeps_scoped_query(country, operation):
    db = _db()
    with pytest.raises(NotFoundException) as failure:
        if operation == "update":
            await pantry.update_pantry_item_quantity(uuid4(), pantry.UpdatePantryItemQuantityRequest(quantity=100, unit="g"), _user(country), db)
        else:
            await pantry.delete_pantry_item(uuid4(), _user(country), db)
    assert failure.value.status_code == 404
    assert failure.value.detail == ("This product was not found in your pantry." if country == "GB"
        else "Nie znaleziono tego produktu w Twojej spiżarni.")
    assert "pantry_items.user_id" in str(db.execute.await_args.args[0])
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("case", ["premium", "quantity", "unit", "barcode", "missing", "package"])
async def test_barcode_pantry_guards_keep_status_and_do_not_guess_package_mass(monkeypatch, country, case):
    changes = {"premium": {"batch": True}, "quantity": {"quantity": 0}, "unit": {"unit": "unknown"},
        "barcode": {"barcode": "123"}, "missing": {}, "package": {"unit": "opak"}}[case]
    payload = pantry.AddPantryBarcodeRequest.model_construct(**({"barcode": "5901234123457", "quantity": 100, "unit": "g"} | changes))
    db = _db()
    lookup = AsyncMock(return_value=products.BarcodeLookupResponse(found=case == "package", name="Original product" if case == "package" else None))
    monkeypatch.setattr(products, "lookup_barcode", lookup)
    with pytest.raises((HTTPException, NotFoundException)) as failure:
        await pantry.add_pantry_item_from_barcode(payload, _user(country), db)
    status = {"premium": 403, "quantity": 400, "unit": 400, "barcode": 400, "missing": 404, "package": 422}[case]
    english = {"premium": "Batch scanning requires Premium.", "quantity": "Quantity must be greater than zero.", "unit": "Invalid unit.",
        "barcode": "Invalid EAN/UPC barcode.", "missing": "No product was found for this barcode.",
        "package": "The whole package size is unknown. Add it from a label photo or choose grams or millilitres."}
    polish = {"premium": "Skanowanie seryjne jest dostępne w Premium.", "quantity": "Ilość musi być większa od zera", "unit": "Nieprawidłowa jednostka",
        "barcode": "Nieprawidłowy kod EAN/UPC", "missing": "Nie znaleziono produktu o tym kodzie kreskowym.",
        "package": "Nie znamy masy całego opakowania. Uzupełnij ją ze zdjęcia etykiety albo wybierz gramy lub mililitry."}
    assert failure.value.status_code == status
    assert failure.value.detail == (english if country == "GB" else polish)[case]
    if case not in {"missing", "package"}:
        lookup.assert_not_awaited()
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
