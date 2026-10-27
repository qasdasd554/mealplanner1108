"""Only selectable store offers may be saved; catalogue estimates are not stock."""
import asyncio
from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

import pytest

from app.core.exceptions import ProductUnavailableException
from app.models import ProductSubstitute, ShoppingListItem, Store, StoreProduct
from app.services.product_substitution import ProductSubstitutionService
from tests.test_uk_ons_shopping import food
from tests.test_uk_pricing_availability_integration import db, Database
from tests.uk_regional_fixtures import reviewed_offer, uk_store


def test_uk_suggestions_need_selected_store_evidence_not_just_a_catalogue_price(db):
    original, generic, local, elsewhere = [food(name) for name in
        ("Makaron penne", "Makaron spaghetti", "Makaron fusilli", "Makaron tagliatelle")]
    db.add_all([original, generic, local, elsewhere])
    shop = uk_store(db, slug="tesco")
    other = uk_store(db, slug="sainsburys")
    reviewed_offer(db, local, shop)
    reviewed_offer(db, elsewhere, other)
    db.commit()
    rows = asyncio.run(ProductSubstitutionService(Database(db)).auto_find_similar(original.id, shop.id))
    assert [row["product"].id for row in rows if row.get('regional_quote')] == [local.id]
    assert all(row.get('generic_reference') for row in rows if not row.get('regional_quote'))


def test_uk_legacy_row_without_snapshot_can_save_a_real_selected_store_offer(db):
    original, selected = food("Makaron penne"), food("Makaron spaghetti")
    db.add_all([original, selected])
    shop = uk_store(db, slug="tesco")
    reviewed_offer(db, selected, shop)
    legacy_sp = StoreProduct(id=uuid4(), store_id=shop.id, product_id=original.id, price=5)
    db.add(legacy_sp)
    db.commit()
    item = ShoppingListItem(id=uuid4(), store_product_id=legacy_sp.id, required_quantity=Decimal(100),
                            unit="g", is_checked=False)
    asyncio.run(ProductSubstitutionService(Database(db)).substitute_shopping_list_item(item, selected.id, shop.id))
    assert item.regional_snapshot.product_id == selected.id
    assert item.regional_snapshot.store_id == shop.id and item.unit == "g"
    assert item.estimated_price == Decimal("2.00")


@pytest.mark.parametrize("withdrawn", [False, True])
def test_pl_save_matches_availability_filter_and_prices_all_required_packs(db, withdrawn):
    original, selected = food("Makaron penne"), food("Makaron spaghetti")
    db.add_all([original, selected])
    shop = Store(id=uuid4(), name="PL fixture", country_code="PL", currency_code="PLN")
    db.add(shop)
    original_sp = StoreProduct(id=uuid4(), product_id=original.id, store_id=shop.id, price=3)
    selected_sp = StoreProduct(id=uuid4(), product_id=selected.id, store_id=shop.id, price=4,
        is_available=True, withdrawn_at=datetime.now(timezone.utc) if withdrawn else None)
    selected.default_quantity = 500
    db.add_all([original_sp, selected_sp])
    db.commit()
    item = ShoppingListItem(id=uuid4(), store_product_id=original_sp.id, required_quantity=Decimal(750),
                            unit="g", is_checked=True)
    service = ProductSubstitutionService(Database(db))
    if withdrawn:
        with pytest.raises(ProductUnavailableException):
            asyncio.run(service.substitute_shopping_list_item(item, selected.id, shop.id))
        assert item.store_product_id == original_sp.id
    else:
        asyncio.run(service.substitute_shopping_list_item(item, selected.id, shop.id))
        assert item.estimated_price == Decimal("8.00") and item.required_quantity == 750
        assert not item.is_checked


@pytest.mark.parametrize("overflow", [False, True])
def test_pl_unit_conversion_does_not_store_zero_or_overflow_the_database(db, overflow):
    original, selected = [food(name) for name in
        (("Mleko 2%", "Mleko bez laktozy") if overflow else ("Makaron penne", "Makaron spaghetti"))]
    original.unit, selected.unit = ("l", "ml") if overflow else ("g", "kg")
    selected.default_quantity = 1000 if overflow else 1
    db.add_all([original, selected])
    shop = Store(id=uuid4(), name="PL fixture", country_code="PL", currency_code="PLN")
    db.add(shop)
    before = StoreProduct(id=uuid4(), product_id=original.id, store_id=shop.id, price=3)
    after = StoreProduct(id=uuid4(), product_id=selected.id, store_id=shop.id, price=4, is_available=True)
    db.add_all([before, after])
    db.commit()
    item = ShoppingListItem(id=uuid4(), store_product_id=before.id,
        required_quantity=Decimal("1000000" if overflow else "0.001"),
        unit=original.unit, is_checked=False)
    operation = ProductSubstitutionService(Database(db)).substitute_shopping_list_item(item, selected.id, shop.id)
    if overflow:
        with pytest.raises(ValueError, match="supported range"):
            asyncio.run(operation)
        assert item.store_product_id == before.id
    else:
        asyncio.run(operation)
        assert item.required_quantity == Decimal("0.001") and item.unit == "g"
        assert item.estimated_price == 4
