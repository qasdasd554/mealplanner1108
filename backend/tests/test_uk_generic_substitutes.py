"""Canonical foods need selected-store evidence to be offered as substitutes."""
import asyncio
import pytest
from decimal import Decimal
from uuid import uuid4

from app.models import ProductSubstitute, ShoppingListItem
from app.services.product_substitution import ProductSubstitutionService
from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
from app.api.v1 import products
from app.schemas.product import SubstituteResponse
from tests.test_uk_ons_shopping import food
from tests.test_uk_pricing_availability_integration import db, Database
from tests.uk_regional_fixtures import uk_store, reviewed_offer
from app.core.exceptions import ProductUnavailableException
from types import SimpleNamespace


def test_uk_canonical_alternatives_with_retail_evidence_are_listed_and_saved(db):
    original, alternative = food("Makaron penne"), food("Makaron spaghetti")
    db.add_all([original, alternative])
    shop = uk_store(db, slug="tesco")
    reviewed_offer(db, alternative, shop)
    db.add(ProductSubstitute(id=uuid4(), original_product_id=original.id,
        substitute_product_id=alternative.id, similarity_score=Decimal("0.95")))
    db.commit()
    adapter = Database(db)
    values = asyncio.run(products.get_product_substitutes(original.id, shop.id,
        db=adapter, current_user=SimpleNamespace(id=uuid4(), country_code="GB")))
    row, = [SubstituteResponse.model_validate(value) for value in values]
    assert row.name.startswith("Synthetic") and row.currency_code == "GBP"
    assert row.price == 2 and row.package_quantity == 500
    assert row.price_basis == "package" and row.package_unit == "g"
    item = ShoppingListItem(id=uuid4(), is_checked=True)
    apply_regional_item_quote(item, product=original, quantity=Decimal(250),
        unit="g", offers=[], store_id=shop.id, as_of=regional_pricing_date())
    asyncio.run(ProductSubstitutionService(adapter).substitute_shopping_list_item(item,
        alternative.id, shop.id))
    assert item.regional_snapshot.product_id == alternative.id
    assert item.substituted_for == original.id and not item.is_checked
    assert item.required_quantity == 250 and item.unit == "g"
    assert item.estimated_price == Decimal("2.00")


def test_uk_fallback_uses_only_selected_store_offers(db):
    original, alternative = food("Makaron penne"), food("Makaron spaghetti")
    db.add_all([original, alternative, food("Pierś z kurczaka")])
    shop = uk_store(db, slug="tesco")
    reviewed_offer(db, alternative, shop)
    db.commit()
    rows = asyncio.run(ProductSubstitutionService(Database(db)).auto_find_similar(original.id, shop.id))
    assert [row["product"].id for row in rows if row.get('regional_quote')] == [alternative.id]


def test_generic_catalogue_price_does_not_prove_substitute_stock(db):
    original, alternative = food("Makaron penne"), food("Szafran")
    alternative.created_by_user_id = uuid4()
    db.add_all([original, alternative])
    shop = uk_store(db, slug="tesco")
    db.commit()
    item = ShoppingListItem(id=uuid4(), is_checked=False)
    apply_regional_item_quote(item, product=original, quantity=Decimal(10), unit="g",
        offers=[], store_id=shop.id, as_of=regional_pricing_date())
    previous_price, previous_product = item.estimated_price, item.regional_snapshot.product_id
    with pytest.raises(ProductUnavailableException):
        asyncio.run(ProductSubstitutionService(Database(db)).substitute_shopping_list_item(
            item, alternative.id, shop.id))
    assert item.estimated_price == previous_price
    assert item.regional_snapshot.product_id == previous_product


def test_uk_generic_picker_keeps_foreign_user_products_and_dimension_changes_out(db):
    original = food("Makaron penne")
    hidden = food("Makaron spaghetti")
    hidden.created_by_user_id = uuid4()
    db.add_all([original, hidden, food("Mleko 2%")])
    shop = uk_store(db, slug="tesco")
    db.commit()
    assert asyncio.run(ProductSubstitutionService(Database(db)).auto_find_similar(original.id, shop.id)) == []
