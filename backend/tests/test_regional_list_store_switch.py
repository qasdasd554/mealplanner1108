"""List-scoped GB store changes against real SQLite, never recipe rebuilds."""

from copy import deepcopy
from datetime import timedelta
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1 import shopping_lists as api
from app.core.exceptions import NotFoundException
from app.db.uk_store_catalog import UK_STORES
from app.models import (
    MealPlan, PantryItem, Product, RegionalProductOffer, ShoppingListItem,
    ShoppingListShare, Store, User,
)
from app.schemas.shopping_list import ShoppingListResponse
from app.services import regional_shopping
from app.services.shopping_list_builder import ShoppingListBuilder
from tests.test_regional_shopping import db, loaded, make_plan, run


def switch(adapter, user, shopping, target=None):
    handler = getattr(api, "update_shopping_list_store", None)
    assert callable(handler), "A list-scoped store switch must not rebuild recipes"
    payload = api.ShoppingListStoreRequest(store_id=target or UK_STORES[1].id)
    return run(handler(shopping.meal_plan_id, payload, user, adapter))


def build(db, *, quantity="600"):
    session, adapter, user, product, _ = db
    plan = make_plan(session, user, product, quantity=quantity, include_pantry=False)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    return session, adapter, user, product, plan, loaded(session, shopping.id)


def row_state(item):
    snapshot = item.regional_snapshot
    return (
        item.id, item.required_quantity, item.unit, item.is_checked,
        item.is_from_pantry, item.is_generated, item.substituted_for,
        snapshot.manual_extra_quantity, snapshot.purchase_is_checked,
    )


def test_switch_uses_current_manual_amounts_and_preserves_row_identity(db):
    session, adapter, user, product, plan, shopping = build(db)
    item = shopping.items[0]
    offers = run(regional_shopping.load_regional_offers(adapter, {product.id}, shopping.store_id))
    regional_shopping.apply_regional_item_quote(
        item, product=product, store_id=shopping.store_id, quantity=Decimal("750"),
        unit="g", offers=offers, as_of=regional_shopping.regional_pricing_date(),
    )
    item.regional_snapshot.manual_extra_quantity = Decimal("150")
    session.commit()
    before = row_state(item)
    result = switch(adapter, user, shopping)
    result = loaded(session, result.id)
    assert len(result.items) == 1 and row_state(result.items[0]) == before
    assert result.store_id == UK_STORES[1].id
    assert session.get(MealPlan, plan.id).store_id == UK_STORES[1].id
    assert result.items[0].regional_snapshot.quote_data["package_quantity"] == "1E+3"
    assert ShoppingListResponse.model_validate(result).total_estimated_price == 1.80
    assert plan.entries[0].recipe.ingredients[0].quantity == Decimal("600")


def test_switch_preserves_merged_technical_list_with_no_recipe_entries(db):
    session, adapter, user, product, _ = db
    rows = []
    for quantity in ("200", "350"):
        plan = make_plan(session, user, product, quantity=quantity)
        rows.append(run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id)))
    merged = run(api.merge_shopping_lists(
        api.MergeShoppingListsRequest(list_ids=[row.meal_plan_id for row in rows]), user, adapter,
    ))
    merged = loaded(session, merged.id)
    assert session.get(MealPlan, merged.meal_plan_id).entries == []
    before = [row_state(item) for item in merged.items]
    result = switch(adapter, user, merged)
    result = loaded(session, result.id)
    assert [row_state(item) for item in result.items] == before
    assert result.items[0].required_quantity == Decimal("550")
    assert result.items[0].estimated_price == Decimal("1.80")


def test_switch_preserves_frozen_purchased_pack_and_pantry_without_second_deduction(db):
    session, adapter, user, product, plan, shopping = build(db, quantity="100")
    bought = shopping.items[0]
    bought.is_checked = True
    session.commit()
    frozen = deepcopy(bought.regional_snapshot.quote_data)
    run(api.add_item_to_shopping_list(plan.id, api.AddItemRequest(product_id=product.id, quantity=150, unit="g"), user, adapter))
    shopping = loaded(session, shopping.id)
    # Pantry is already split in persisted rows; do not query/subtract new stock.
    session.add(PantryItem(id=uuid4(), user_id=user.id, product_id=product.id, quantity=Decimal("5000"), unit="g"))
    pantry = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, is_generated=False, is_checked=True)
    regional_shopping.apply_regional_item_quote(
        pantry, product=product, store_id=shopping.store_id, quantity=Decimal("50"),
        unit="g", offers=[], as_of=regional_shopping.regional_pricing_date(), from_pantry=True,
    )
    session.add(pantry)
    session.commit()
    shopping = loaded(session, shopping.id)
    before = {item.id: row_state(item) for item in shopping.items}
    result = loaded(session, switch(adapter, user, shopping).id)
    assert {item.id: row_state(item) for item in result.items} == before
    bought = next(item for item in result.items if item.id == bought.id)
    assert bought.regional_snapshot.quote_data == frozen
    assert bought.regional_snapshot.store_id == UK_STORES[0].id
    assert bought.estimated_price == Decimal("1.25")
    assert next(item for item in result.items if item.is_from_pantry).estimated_price == 0
    assert ShoppingListResponse.model_validate(result).total_estimated_price == 3.05
    run(api.complete_shopping_list(plan.id, True, user, adapter))
    assert session.scalar(select(PantryItem).where(PantryItem.product_id == product.id)).quantity == Decimal("5500")


@pytest.mark.parametrize("kind", ["unknown", "corrupt-history"])
def test_incomplete_or_corrupt_target_rejects_atomically_even_if_caller_commits(db, kind):
    session, adapter, user, product, plan, shopping = build(db, quantity="100")
    before = deepcopy(shopping.items[0].regional_snapshot.quote_data)
    if kind == "custom":
        run(api.add_custom_item_to_shopping_list(plan.id, api.AddCustomItemRequest(name="A handwritten item", quantity=1, unit="szt"), user, adapter))
    elif kind == "unknown":
        shopping.items[0].unit = "cup"
        shopping.items[0].regional_snapshot.required_unit = None
        shopping.items[0].regional_snapshot.required_quantity = None
    elif kind in {"missing", "stale"}:
        offer = session.scalar(select(RegionalProductOffer).where(RegionalProductOffer.store_id == UK_STORES[1].id, RegionalProductOffer.product_id == product.id))
        if kind == "missing":
            session.delete(offer)
        else:
            offer.reviewed_at -= timedelta(days=40)
    else:
        shopping.items[0].is_checked = True
        shopping.items[0].regional_snapshot.quote_data = {**before, "purchased_quantity": "1"}
    session.commit()
    shopping = loaded(session, shopping.id)
    before_rows = {item.id: (row_state(item), deepcopy(item.regional_snapshot.quote_data)) for item in shopping.items}
    with pytest.raises(HTTPException) as error:
        switch(adapter, user, shopping)
    assert error.value.status_code == 409
    session.commit()  # A caught rejection must not leak an earlier successful row.
    shopping = loaded(session, shopping.id)
    assert shopping.store_id == plan.store_id == UK_STORES[0].id
    assert {item.id: (row_state(item), item.regional_snapshot.quote_data) for item in shopping.items} == before_rows


@pytest.mark.parametrize("kind", ["custom", "missing", "stale", "raw-unit"])
def test_unpriced_uk_list_can_switch_without_losing_rows_or_claiming_free_prices(db, kind):
    session, adapter, user, product, plan, shopping = build(db, quantity="100")
    if kind == "custom":
        run(api.add_custom_item_to_shopping_list(plan.id, api.AddCustomItemRequest(name="My own item"), user, adapter))
    elif kind == "raw-unit":
        regional_shopping.apply_regional_item_quote(shopping.items[0], product=product,
            store_id=shopping.store_id, quantity=Decimal(2), unit="cup", offers=[],
            as_of=regional_shopping.regional_pricing_date())
    else:
        offer = session.scalar(select(RegionalProductOffer).where(RegionalProductOffer.store_id == UK_STORES[1].id, RegionalProductOffer.product_id == product.id))
        if kind == "missing": session.delete(offer)
        else: offer.reviewed_at -= timedelta(days=40)
    session.commit()
    shopping = loaded(session, shopping.id)
    before = {item.id: row_state(item) for item in shopping.items}
    changed = loaded(session, switch(adapter, user, shopping).id)
    assert changed.store_id == UK_STORES[1].id
    assert {item.id: row_state(item) for item in changed.items} == before
    response = ShoppingListResponse.model_validate(changed)
    assert response.total_estimated_price is None and response.has_unpriced_items
    unknown = [item for item in changed.items if item.estimated_price is None]
    assert unknown and all(item.regional_snapshot.quote_status == "unpriced" for item in unknown)
    assert all(item.regional_snapshot.store_id == UK_STORES[1].id for item in unknown)


@pytest.mark.parametrize("share_status", [None, "pending", "accepted"])
def test_switch_uses_existing_accepted_share_auth_even_for_pl_viewer(db, share_status):
    session, adapter, user, product, plan, shopping = build(db)
    viewer = User(id=uuid4(), email="viewer@example.test", password_hash="test", country_code="PL")
    session.add(viewer)
    if share_status:
        session.add(ShoppingListShare(id=uuid4(), meal_plan_id=plan.id, shared_by_user_id=user.id, shared_with_user_id=viewer.id, status=share_status))
    session.commit()
    if share_status == "accepted":
        assert switch(adapter, viewer, shopping).store_id == UK_STORES[1].id
    else:
        with pytest.raises(NotFoundException):
            switch(adapter, viewer, shopping)
    assert session.get(Product, product.id).default_quantity == Decimal("100")


@pytest.mark.parametrize("kind", ["foreign-target", "completed", "merged", "inconsistent-plan", "foreign-owner"])
def test_switch_rejects_wrong_market_closed_and_inconsistent_lists(db, kind):
    session, adapter, user, product, plan, shopping = build(db)
    target = UK_STORES[1].id
    if kind == "foreign-target":
        target = uuid4()
        session.add(Store(id=target, name="Polish retailer", country_code="PL", currency_code="PLN"))
    elif kind in {"completed", "merged"}:
        shopping.status = kind
    elif kind == "inconsistent-plan":
        plan.store_id = UK_STORES[1].id
    else:
        # Account country is immutable; this fixture creates a distinct PL owner.
        owner = User(id=uuid4(), email="ownerpl@example.test", password_hash="test", country_code="PL")
        session.add(owner)
        plan.user_id = owner.id
        user = owner
    session.commit()
    with pytest.raises((HTTPException, NotFoundException)):
        switch(adapter, user, shopping, target)
    session.commit()
    assert loaded(session, shopping.id).store_id == UK_STORES[0].id


def test_unchanged_recalculation_after_switch_does_not_rewrite_bought_pack(db):
    session, adapter, user, product, plan, shopping = build(db, quantity="100")
    bought = shopping.items[0]
    bought.is_checked = True
    session.commit()
    frozen = deepcopy(bought.regional_snapshot.quote_data)
    switch(adapter, user, shopping)
    result = run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    bought = loaded(session, result.id).items[0]
    assert bought.is_checked
    assert bought.regional_snapshot.store_id == UK_STORES[0].id
    assert bought.regional_snapshot.quote_data == frozen
    run(api.complete_shopping_list(plan.id, True, user, adapter))
    assert session.scalar(select(PantryItem).where(
        PantryItem.user_id == user.id, PantryItem.product_id == product.id,
    )).quantity == Decimal("500")


def test_merging_checked_rows_preserves_actual_packages_separately(db):
    session, adapter, user, product, _ = db
    sources = []
    for quantity in ("100", "200"):
        plan = make_plan(session, user, product, quantity=quantity, include_pantry=False)
        shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
        shopping = loaded(session, shopping.id)
        shopping.items[0].is_checked = True
        session.commit()
        sources.append(shopping)
    merged = run(api.merge_shopping_lists(api.MergeShoppingListsRequest(
        list_ids=[row.meal_plan_id for row in sources],
    ), user, adapter))
    merged = loaded(session, merged.id)
    assert len(merged.items) == 2
    assert all(item.is_checked for item in merged.items)
    assert sum(Decimal(item.regional_snapshot.quote_data["purchased_quantity"])
               for item in merged.items) == Decimal("1000")
    run(api.complete_shopping_list(merged.meal_plan_id, True, user, adapter))
    assert session.scalar(select(PantryItem).where(
        PantryItem.user_id == user.id, PantryItem.product_id == product.id,
    )).quantity == Decimal("1000")


def test_switch_savepoint_rolls_back_failure_after_first_repriced_row(db, monkeypatch):
    session, adapter, user, product, plan, shopping = build(db, quantity="100")
    extra = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id,
                             is_checked=False, is_generated=False)
    offers = run(regional_shopping.load_regional_offers(adapter, {product.id}, shopping.store_id))
    regional_shopping.apply_regional_item_quote(
        extra, product=product, store_id=shopping.store_id, quantity=Decimal("200"),
        unit="g", offers=offers, as_of=regional_shopping.regional_pricing_date(),
    )
    session.add(extra)
    session.commit()
    shopping = loaded(session, shopping.id)
    before = {item.id: deepcopy(item.regional_snapshot.quote_data) for item in shopping.items}
    original = api.apply_regional_item_quote
    calls = []

    def fail_on_second(*args, **kwargs):
        calls.append(args[0].id)
        if len(calls) == 2:
            raise RuntimeError("Synthetic late application failure")
        return original(*args, **kwargs)

    monkeypatch.setattr(api, "apply_regional_item_quote", fail_on_second)
    with pytest.raises(RuntimeError, match="Synthetic late"):
        switch(adapter, user, shopping)
    assert len(calls) == 2
    session.commit()
    shopping = loaded(session, shopping.id)
    assert shopping.store_id == plan.store_id == UK_STORES[0].id
    assert {item.id: item.regional_snapshot.quote_data for item in shopping.items} == before


def test_changed_bought_recipe_requirement_rejects_before_deleting_old_rows(db):
    session, adapter, user, product, plan, shopping = build(db, quantity="100")
    bought = shopping.items[0]
    bought.is_checked = True
    session.commit()
    before = (bought.id, deepcopy(bought.regional_snapshot.quote_data))
    plan.entries[0].recipe.ingredients[0].quantity = Decimal("200")
    session.commit()
    with pytest.raises(HTTPException) as error:
        run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    assert error.value.status_code == 409
    session.commit()
    result = loaded(session, shopping.id)
    assert len(result.items) == 1
    assert result.items[0].required_quantity == Decimal("100")
    assert (result.items[0].id, result.items[0].regional_snapshot.quote_data) == before
