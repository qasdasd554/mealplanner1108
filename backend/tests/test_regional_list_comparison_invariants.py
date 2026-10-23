"""Independent read-only/bulk-loading checks for current UK list comparison.

Local synthetic SQLite evidence only; no live retailer, network or Neon calls.
"""

import asyncio
from copy import deepcopy
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import event

from app.api.v1 import price_compare as api
from app.models import Product, ShoppingList, ShoppingListItem
from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
from tests.test_uk_pricing_availability_integration import Database, db, setup_plan
from tests.uk_regional_fixtures import reviewed_offer, uk_store


def seed_current_list(session, *, item_count):
    owner, source, product, dish, plan = setup_plan(session, quantity="300")
    target = uk_store(session, slug="sainsburys")
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan.id, store_id=source.id,
                            status="pending")
    session.add(shopping)
    session.flush()
    items = []
    for index in range(item_count):
        ingredient = product if index == 0 else Product(
            id=uuid4(), name=f"Synthetic ingredient {index}", unit="g",
            default_quantity=Decimal("100"), review_status="approved",
        )
        session.add(ingredient)
        session.flush()
        offer = reviewed_offer(session, ingredient, source, quantity="500", price="2.00")
        reviewed_offer(session, ingredient, target, quantity="400", price="1.50")
        row = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id,
                               is_checked=False, is_generated=False)
        apply_regional_item_quote(
            row, product=ingredient, store_id=source.id, quantity=Decimal("300"),
            unit="g", offers=[offer], as_of=regional_pricing_date(),
        )
        session.add(row)
        items.append(row)
    session.commit()
    return owner, plan, shopping, source, target, items


def frozen_columns(row):
    return deepcopy({column.name: getattr(row, column.name)
                     for column in type(row).__table__.columns})


def test_comparing_current_list_does_not_modify_cart_or_plan(db):
    owner, plan, shopping, source, target, rows = seed_current_list(db, item_count=3)
    before_plan = frozen_columns(plan)
    before_list = frozen_columns(shopping)
    before_items = {row.id: frozen_columns(row) for row in rows}
    before_snapshots = {row.id: frozen_columns(row.regional_snapshot) for row in rows}
    # A GET must leave both live quantities and frozen package/provenance intact,
    # even if a caller erroneously commits its session after comparison.
    results = asyncio.run(api.compare_shopping_list_prices(
        plan.id, db=Database(db), current_user=owner,
    ))
    assert results
    assert not db.new and not db.dirty and not db.deleted
    db.commit()
    db.expire_all()
    assert frozen_columns(db.get(type(plan), plan.id)) == before_plan
    assert frozen_columns(db.get(ShoppingList, shopping.id)) == before_list
    for row in rows:
        stored = db.get(ShoppingListItem, row.id)
        assert frozen_columns(stored) == before_items[row.id]
        assert frozen_columns(stored.regional_snapshot) == before_snapshots[row.id]


def test_comparing_many_items_has_bounded_queries_not_one_per_product(db):
    owner, plan, shopping, source, target, rows = seed_current_list(db, item_count=24)
    db.expire_all()
    # Resolve actor identity before the measured request, as normal auth does.
    owner.id, owner.country_code
    statements = []

    def record_sql(connection, cursor, statement, parameters, context, many):
        statements.append(statement)

    event.listen(db.bind, "before_cursor_execute", record_sql)
    try:
        results = asyncio.run(api.compare_shopping_list_prices(
            plan.id, db=Database(db), current_user=owner,
        ))
    finally:
        event.remove(db.bind, "before_cursor_execute", record_sql)
    by_store = {result.store_id: result for result in results}
    assert by_store[source.id].total_price == 48
    assert by_store[target.id].total_price == 36
    assert len(by_store[source.id].items) == 24
    assert len(by_store[target.id].items) == 24
    # Existing relationship selectin-loads are allowed, not a per-SKU query.
    selects = [statement for statement in statements
               if statement.lstrip().upper().startswith("SELECT")]
    assert len(selects) <= 12, f"Unexpected query growth: {len(selects)} SELECTs"
    assert all(statement.lstrip().upper().startswith("SELECT") for statement in statements)
    assert not any("FROM pantry_items" in statement for statement in statements)
