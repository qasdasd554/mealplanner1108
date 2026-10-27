"""Regression cases from UK shopping screenshots, not isolated recipe fixes."""
import asyncio
from decimal import Decimal
from types import SimpleNamespace as NS
from uuid import uuid4

import pytest

from app.models import ShoppingListItem
from app.schemas.shopping_list import ShoppingListItemResponse
from app.services.regional_requirements import aggregate_regional_requirements, to_regional_base_quantity
from app.services.regional_shopping import apply_regional_item_quote, regional_pricing_date
from app.services.shopping_list_builder import ShoppingListBuilder
from app.services.product_substitution import ProductSubstitutionService
from tests.test_uk_ons_shopping import food
from tests.test_uk_pricing_availability_integration import db, Database
from tests.uk_regional_fixtures import uk_store
from tests.test_runtime_async_boundaries import state


def plan(product, amounts, store_id=None):
    return NS(store_id=store_id, user_id=uuid4(), entries=[NS(servings_multiplier=1,
        recipe=NS(ingredients=[NS(product_id=product.id, product=product,
            quantity=Decimal(str(quantity)), unit=unit)])) for quantity, unit in amounts])


@pytest.mark.parametrize('unit,expected', [('łyżeczka', 5), ('łyżka', 15), ('tbsp', 15)])
def test_recipe_spoons_share_the_persisted_liquid_measure(unit, expected):
    oil = food('Oliwa z oliwek')
    assert to_regional_base_quantity(oil, 1, unit) == (Decimal(expected), 'ml')


def test_recipe_oil_is_one_priced_requirement_despite_different_units(db):
    oil = food('Oliwa z oliwek')
    db.add(oil)
    shop = uk_store(db, slug='aldi')
    db.commit()
    meal = plan(oil, [(15, 'ml'), (15, 'ml'), (2, 'łyżka'), (2, 'łyżeczka')], shop.id)
    rows = asyncio.run(ShoppingListBuilder(Database(db))._resolve_regional_requirements(meal, include_pantry=False))
    assert len(rows) == 1
    assert rows[0]['required_quantity'] == 70 and rows[0]['unit'] == 'ml'
    assert rows[0]['estimated_price'] > 0


def test_unknown_repeated_measures_are_summed_without_guessing_density(db):
    oil = food('Oliwa z oliwek')
    db.add(oil)
    shop = uk_store(db, slug='aldi')
    db.commit()
    meal = plan(oil, [(1, 'unknown scoop'), (2, 'unknown scoop'), (15, 'ml')], shop.id)
    rows = asyncio.run(ShoppingListBuilder(Database(db))._resolve_regional_requirements(meal, include_pantry=False))
    assert len(rows) == 2
    assert {(row['required_quantity'], row['unit']) for row in rows} == {(Decimal(3), 'unknown scoop'), (Decimal(15), 'ml')}
    assert all(row['estimated_price'] is None for row in rows)


def test_eggs_offer_piece_display_without_changing_grams_or_cost():
    egg = food('Jajka')
    item = ShoppingListItem(id=uuid4(), is_checked=False)
    apply_regional_item_quote(item, product=egg, quantity=Decimal(2800), unit='g',
        offers=[], store_id=uuid4(), as_of=regional_pricing_date())
    response = ShoppingListItemResponse.model_validate(item)
    assert response.display_quantity == 56 and response.display_unit == 'szt'
    assert response.required_quantity == 2800 and response.unit == 'g'
    assert response.estimated_price == 16.8


def test_catalogue_substitute_is_labelled_and_can_be_saved_without_claiming_stock(db):
    original, alternative = food('Makaron penne'), food('Makaron spaghetti')
    db.add_all([original, alternative])
    shop = uk_store(db, slug='aldi')
    db.commit()
    service = ProductSubstitutionService(Database(db))
    rows = asyncio.run(service.auto_find_similar(original.id, shop.id))
    row, = rows
    assert row['product'].id == alternative.id and row['generic_reference'] is True
    from app.api.v1.products import get_product_substitutes
    from app.schemas.product import SubstituteResponse
    choices = asyncio.run(get_product_substitutes(original.id, shop.id, db=Database(db),
        current_user=NS(id=uuid4(), country_code='GB')))
    response, = [SubstituteResponse.model_validate(row) for row in choices]
    assert response.availability_scope == 'generic_food_reference'
    assert response.name == 'Spaghetti pasta' or response.name == 'Spaghetti'
    assert response.price_basis == 'quantity_reference' and response.price_quantity == 100
    assert response.package_quantity is None and response.price > 0
    item = ShoppingListItem(id=uuid4(), is_checked=False)
    apply_regional_item_quote(item, product=original, quantity=Decimal(250), unit='g',
        offers=[], store_id=shop.id, as_of=regional_pricing_date())
    asyncio.run(service.substitute_shopping_list_item(item, alternative.id, shop.id))
    assert item.regional_snapshot.product_id == alternative.id
    assert item.regional_snapshot.offer_id is None
    assert item.regional_snapshot.quote_data['price_source']['confirms_store_stock'] is False
    assert item.required_quantity == 250


@pytest.mark.asyncio
async def test_old_generated_list_is_repaired_on_read_without_losing_checked_history(state):
    from app.models import MealPlan, ShoppingList, User
    from app.api.v1.shopping_lists import get_shopping_list
    session, db, (user_id, _, plan_id, _, _) = state
    user = await db.get(User, user_id)
    meal = await db.get(MealPlan, plan_id)
    oil = food('Oliwa z oliwek')
    db.add(oil)
    shopping = ShoppingList(id=uuid4(), meal_plan_id=plan_id, store_id=meal.store_id, status='pending')
    db.add(shopping)
    await db.flush()
    for quantity, unit, checked in [(15, 'ml', False), (2, 'łyżka', False), (10, 'ml', True)]:
        item = ShoppingListItem(id=uuid4(), shopping_list_id=shopping.id, is_generated=True, is_checked=checked)
        apply_regional_item_quote(item, product=oil, store_id=meal.store_id, quantity=Decimal(quantity),
            unit=unit, offers=[], as_of=regional_pricing_date())
        # Reproduce the old unresolved spoon snapshot and duplicate raw rows.
        if unit == 'łyżka':
            item.required_quantity, item.unit = Decimal(2), unit
            item.regional_snapshot.required_quantity, item.regional_snapshot.required_unit = None, None
        db.add(item)
    await db.commit()
    result = await get_shopping_list(plan_id, user, db)
    assert len(result.items) == 2
    unchecked, = [item for item in result.items if not item.is_checked]
    checked, = [item for item in result.items if item.is_checked]
    assert unchecked.required_quantity == 45 and unchecked.unit == 'ml'
    assert checked.required_quantity == 10 and checked.is_checked
    result = await get_shopping_list(plan_id, user, db)
    assert len(result.items) == 2  # Idempotent; no repeated extra quantities.
