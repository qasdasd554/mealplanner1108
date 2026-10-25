"""The viewer controls copy; the persisted list still controls price/market."""

from copy import deepcopy
from decimal import Decimal
from uuid import uuid4

import pytest

from app.models import ShoppingListShare, Store, User
from tests.test_polish_list_comparison import pl
from tests.test_regional_list_comparison import client_for, list_compare, make_shopping
from tests.test_regional_shopping import UK_STORES, api, db, loaded, run


def collaborator(session, owner, plan_id, country):
    viewer = User(id=uuid4(), email=f"{uuid4()}@example.test",
                  password_hash="fixture", country_code=country)
    session.add(viewer)
    session.add(ShoppingListShare(id=uuid4(), meal_plan_id=plan_id,
        shared_by_user_id=owner.id, shared_with_user_id=viewer.id, status="accepted"))
    session.commit()
    return viewer


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("kind,pl_copy,en_copy,status", [
    ("closed_compare", "Ceny można porównywać tylko dla otwartej listy zakupów.",
        "Only an open shopping list can compare stores.", 409),
    ("closed_switch", "Sklep można zmienić tylko dla otwartej listy zakupów.",
        "Only an open shopping list can change store.", 409),
    ("foreign_target", "Wybrany sklep nie jest dostępny na rynku tej listy.",
        "The selected store is not available in this list's market.", 404),
    ("corrupt_purchase", "Najpierw popraw zapisane dane zakupionego opakowania.",
        "The saved purchased package needs to be corrected first.", 409),
    ("corrupt_pantry", "Najpierw popraw zapisaną ilość ze spiżarni.",
        "The saved pantry quantity needs to be corrected first.", 409),
    ("unknown_requirement", "Nie można wycenić całej bieżącej listy zakupów w tym sklepie.",
        "This store cannot fully price the current shopping list.", 409),
    ("wrong_market_compare", "Nie znaleziono listy zakupów na rynku UK.",
        "Shopping list not found in the UK market.", 404),
    ("wrong_market_switch", "Lista i jej właściciel muszą należeć do tego samego rynku UK.",
        "The list and its owner must belong to the same UK market.", 409),
])
def test_gb_list_rejections_use_viewer_language_without_changing_saved_basket(
    db, country, kind, pl_copy, en_copy, status,
):
    session, adapter, owner, _, _ = db
    plan, shopping = make_shopping(db)
    viewer = collaborator(session, owner, plan.id, country)
    shopping = loaded(session, shopping.id)
    target_id = UK_STORES[1].id
    if kind.startswith("closed"):
        shopping.status = "completed"
    elif kind == "foreign_target":
        target = Store(id=uuid4(), name="Foreign retailer", country_code="PL", currency_code="PLN")
        session.add(target)
        target_id = target.id
    elif kind == "corrupt_pantry":
        shopping.items[0].is_from_pantry = True
        shopping.items[0].is_checked = True
        shopping.items[0].estimated_price = Decimal(0)
        # A priced purchase snapshot is not proof of pantry coverage.
    elif kind == "unknown_requirement":
        shopping.items[0].unit = "cup"
        shopping.items[0].regional_snapshot.required_quantity = None
        shopping.items[0].regional_snapshot.required_unit = None
    elif kind.startswith("wrong_market"):
        plan.store_id = UK_STORES[1].id
    else:
        shopping.items[0].is_checked = True
        shopping.items[0].regional_snapshot.quote_data = {
            **shopping.items[0].regional_snapshot.quote_data, "purchased_quantity": "1",
        }
    session.commit()
    before_plan_store = plan.store_id
    before = deepcopy(shopping.items[0].regional_snapshot.quote_data)
    before_row = shopping.items[0].id, shopping.items[0].required_quantity, shopping.items[0].estimated_price
    with client_for(adapter, viewer) as client:
        if kind.endswith("compare"):
            response = list_compare(client, plan.id)
        else:
            response = client.put(f"/api/v1/shopping-lists/{plan.id}/store",
                                  json={"store_id": str(target_id)})
    assert response.status_code == status, response.text
    assert response.json()["detail"] == (en_copy if country == "GB" else pl_copy)
    session.commit()  # Even a caller that catches the exception cannot persist a partial switch.
    shopping = loaded(session, shopping.id)
    assert shopping.store_id == UK_STORES[0].id
    assert plan.store_id == before_plan_store
    assert shopping.store.currency_code == "GBP"
    assert shopping.items[0].regional_snapshot.quote_data == before
    assert (shopping.items[0].id, shopping.items[0].required_quantity,
            shopping.items[0].estimated_price) == before_row
    assert viewer.country_code == country and owner.country_code == "GB"


def test_gb_viewer_of_polish_list_gets_english_target_error_then_keeps_pln(pl):
    session, adapter, owner, product, _ = pl
    shopping = run(api.create_empty_shopping_list(
        api.EmptyShoppingListRequest(store_id=UK_STORES[0].id), owner, adapter))
    viewer = collaborator(session, owner, shopping.meal_plan_id, "GB")
    with client_for(adapter, viewer) as client:
        failure = client.put(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/store",
                              json={"store_id": str(uuid4())})
        assert failure.status_code == 404
        assert failure.json()["detail"] == "The selected store is not available in this list's market."
        added = client.post(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/items",
                            json={"product_id": str(product.id), "quantity": 600, "unit": "g"})
        assert added.status_code == 201, added.text
        assert added.json()["detail"] == "Product added to shopping list."
        # Production uses a new Session per request; this shared SQLite adapter
        # must reload the relationship after the inserted child row.
        loaded(session, shopping.id)
        again = client.post(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/items",
                            json={"product_id": str(product.id), "quantity": 100, "unit": "g"})
        assert again.status_code == 201, again.text
        assert again.json()["detail"] == "Item quantity updated."
        comparison = list_compare(client, shopping.meal_plan_id)
        assert comparison.status_code == 200, comparison.text
        assert all(row["currency_code"] == "PLN" for row in comparison.json())
        changed = client.put(f"/api/v1/shopping-lists/{shopping.meal_plan_id}/store",
                              json={"store_id": str(UK_STORES[1].id)})
        assert changed.status_code == 200, changed.text
        assert changed.json()["currency_code"] == "PLN"
    shopping = loaded(session, shopping.id)
    assert shopping.items[0].required_quantity == Decimal("700")
    assert shopping.store_id == UK_STORES[1].id
    assert viewer.country_code == "GB" and owner.country_code == "PL"


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_plan_comparison_missing_plan_uses_account_language(db, country):
    session, adapter, owner, _, _ = db
    viewer = User(id=uuid4(), email=f"{uuid4()}@example.test", password_hash="fixture", country_code=country)
    session.add(viewer)
    session.commit()
    with client_for(adapter, viewer) as client:
        response = client.get(f"/api/v1/price-compare/{uuid4()}")
    assert response.status_code == 404
    assert response.json()["detail"] == (
        "Meal plan not found." if country == "GB" else "Nie znaleziono planu posiłków")
