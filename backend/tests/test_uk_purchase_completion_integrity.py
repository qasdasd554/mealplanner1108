"""Completion must use the same frozen-purchase checks as comparison/switching."""

from copy import deepcopy
from decimal import Decimal

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.models import PantryItem, RegionalProductOffer
from tests.test_regional_shopping import api, db, loaded, make_plan, run, ShoppingListBuilder


@pytest.mark.parametrize("corruption", ["country", "currency", "required_unit", "required_quantity",
    "package_unit", "price_total", "source_host", "status", "unpriced_with_quote"])
def test_completion_rejects_inconsistent_purchase_without_any_pantry_or_list_write(db, corruption):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    item = loaded(session, shopping.id).items[0]
    actor_id = user.id  # Resolve auth identity before intentionally corrupting cached fields.
    item.is_checked = True
    snapshot = item.regional_snapshot
    if corruption == "country": snapshot.country_code = "PL"
    elif corruption == "currency": snapshot.currency_code = "PLN"
    elif corruption == "required_unit": snapshot.required_unit = "ml"
    elif corruption == "required_quantity": snapshot.required_quantity = Decimal("601")
    elif corruption == "status": snapshot.quote_status = "pantry"
    elif corruption == "unpriced_with_quote": snapshot.quote_status = "unpriced"
    else:
        data = deepcopy(snapshot.quote_data)
        if corruption == "package_unit": data["package_unit"] = "ml"
        elif corruption == "price_total": data["total_price"] = "0.01"
        else: data["price_source"] = {**data["price_source"], "url": "https://foreign.example/price"}
        snapshot.quote_data = data
    # Simulate an inconsistent cached/legacy row without bypassing any API role.
    # In-memory invalid country values are not persisted through DB constraints.
    if corruption not in {"country", "currency"}:
        session.flush()
    with pytest.raises(HTTPException) as error:
        from app.services.regional_shopping import complete_regional_items_to_pantry
        run(complete_regional_items_to_pantry(adapter, shopping, actor_id))
    assert error.value.status_code == 409
    assert not any(isinstance(value, PantryItem) for value in session.new)
    assert shopping.status != "completed"
    # Do not flush intentionally invalid country/currency fixtures on SELECT.
    with session.no_autoflush:
        assert session.scalar(select(PantryItem).where(PantryItem.product_id == product.id)) is None


def test_unpriced_purchase_with_known_grams_moves_exact_amount_once_without_a_pl_pack(db):
    from sqlalchemy import delete
    session, adapter, user, product, _ = db
    session.execute(delete(RegionalProductOffer).where(RegionalProductOffer.product_id == product.id))
    session.commit()
    plan = make_plan(session, user, product, quantity="600", include_pantry=False)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    row = loaded(session, shopping.id).items[0]
    assert row.estimated_price is None and row.regional_snapshot.quote_status == "unpriced"
    row.is_checked = True
    session.commit()
    results = [run(api.complete_shopping_list(plan.id, True, user, adapter)) for _ in range(2)]
    assert [result["moved_to_pantry"] for result in results] == [1, 0]
    stored = session.scalar(select(PantryItem).where(PantryItem.product_id == product.id))
    assert stored.quantity == 600 and stored.unit == "g"
    assert product.serving_quantity == 200  # Never treated as three PL example packs.
