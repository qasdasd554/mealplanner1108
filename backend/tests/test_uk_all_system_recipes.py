"""The whole authored-by-system cookbook must work in the English market.

Real reviewed source packets are used, not a blanket recipe-ID bypass.
No HTTP, production DB or authored recipe translation is allowed here.
"""
from datetime import date
import asyncio
import json
from pathlib import Path
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.db.seed import PRODUCTS_DATA, PRODUCT_BRANDS, NUTRITION_DATA, RECIPES_DATA, _uid
from app.models import Product, Recipe, RecipeIngredient
from app.services.market_catalog import recipe_market_availability
from app.services.nutrition_calculator import compute_recipe_nutrition_total
from app.services.system_content_language import recipe_display_content, _recipe_translations
from tests.test_regional_shopping import db, UK_STORES


def seed_cookbook(session):
    foods = {name: Product(id=_uid('product:'+name), name=name, unit=unit,
        brand=PRODUCT_BRANDS[name], review_status='approved',
        nutrition_per_100=NUTRITION_DATA[name]) for name, unit, *_ in PRODUCTS_DATA}
    session.add_all(foods.values())
    recipes = []
    for data in RECIPES_DATA:
        row = Recipe(id=_uid('recipe:'+data['name']), name=data['name'],
            description=data['description'], instructions=data['instructions'],
            suggested_seasonings=data['suggested_seasonings'],
            meal_type=data['meal_type'], servings=data['servings'],
            visibility='public', is_active=True)
        row.ingredients = [RecipeIngredient(id=uuid4(), product=foods[name],
            quantity=quantity, unit=unit, is_optional=optional)
            for name, quantity, unit, optional in data['ingredients']]
        row.nutrition_total = compute_recipe_nutrition_total(row.ingredients)
        recipes.append(row)
    session.add_all(recipes)
    session.commit()
    return foods, recipes


def test_all_137_system_recipes_have_reviewed_uk_ingredients_and_english_content(db, monkeypatch):
    from app.services.meal_plan_generator import MealPlanGenerator
    from app.services.market_catalog import ensure_recipe_available_in_market

    session, _, user, _, _ = db
    foods, recipes = seed_cookbook(session)
    actual = set(session.scalars(select(Recipe.id).where(
        recipe_market_availability('GB', as_of=date(2026, 10, 25)))))
    missing = [row.name for row in recipes if row.id not in actual]
    assert not missing, missing
    assert len(actual) == len(RECIPES_DATA) == 137
    for row in recipes:
        translated = recipe_display_content(row, country_code='GB')
        # International dish names may legitimately be identical (Shakshuka).
        assert translated == _recipe_translations()[row.name], row.name
        assert len(translated['instructions']) == len(row.instructions)
        assert row.nutrition_total['kcal'] > 0
    pages = [list(session.scalars(select(Recipe.id).where(
        recipe_market_availability('GB', as_of=date(2026, 10, 25)))
        .order_by(Recipe.id).offset(skip).limit(30))) for skip in range(0, 150, 30)]
    assert [len(page) for page in pages] == [30, 30, 30, 30, 17]
    assert {identity for page in pages for identity in page} == actual
    assert sum(map(len, pages)) == len(actual)
    monkeypatch.setattr('app.services.meal_plan_generator.utc_market_date', lambda: date(2026, 10, 25))
    monkeypatch.setattr('app.services.market_catalog.utc_market_date', lambda: date(2026, 10, 25))
    eligible = asyncio.run(MealPlanGenerator(db[1])._filter_eligible_recipes(
        store_id=UK_STORES[0].id, allergen_ids=set(), user_id=user.id, country_code='GB'))
    assert {row.id for row in eligible} == actual
    for food_name in ('Śmietana 30%', 'Szałwia świeża', 'Papryka żółta', 'Budyń waniliowy'):
        recipe = next(row for row in recipes if any(
            item.product_id == foods[food_name].id for item in row.ingredients))
        asyncio.run(ensure_recipe_available_in_market(db[1], recipe, user, store_id=UK_STORES[0].id))
    plan = asyncio.run(MealPlanGenerator(db[1]).generate(user.id, UK_STORES[0].id,
        duration_days=7, meals_per_day=3, target_kcal=2000, household_size=1,
        include_pantry=False))
    assert len(plan.entries) >= 21
    assert {entry.recipe_id for entry in plan.entries} <= actual
    # No recipe ID, name or look-alike from a user borrows country evidence.
    unavailable = Product(id=uuid4(), name='Courgettes', unit='g', review_status='approved')
    foreign = Recipe(id=uuid4(), name=recipes[0].name, created_by_user_id=user.id,
        meal_type=recipes[0].meal_type, description='Original user description',
        instructions=['Original user directions'], is_active=True, visibility='public')
    foreign.ingredients = [RecipeIngredient(id=uuid4(), product=unavailable,
        quantity=100, unit='g', is_optional=False)]
    session.add(foreign)
    session.commit()
    assert session.scalar(select(Recipe.id).where(Recipe.id == foreign.id,
        recipe_market_availability('GB', as_of=date(2026, 10, 25)))) is None
    assert recipe_display_content(foreign, country_code='GB')['description'] == 'Original user description'


@pytest.mark.parametrize('name', ['Śmietana 30%', 'Szałwia świeża', 'Papryka żółta', 'Budyń waniliowy'])
@pytest.mark.parametrize('change', ['none', 'id', 'name', 'brand', 'owner', 'barcode', 'pending', 'expired', 'future'])
def test_official_catalogue_country_proof_never_borrows_a_user_identity_or_claims_off(db, name, change):
    from app.services.uk_system_recipe_reference import retailer_country_product_ids
    from app.services.off_availability import off_available_product_ids

    session, adapter, user, _, _ = db
    food = Product(id=_uid('product:'+name), name=name, unit='g',
        brand=PRODUCT_BRANDS[name], review_status='approved')
    if change == 'id': food.id = uuid4()
    if change == 'name': food.name += ' edited'
    if change == 'brand': food.brand = 'A different SKU'
    if change == 'owner': food.created_by_user_id = user.id
    if change == 'barcode': food.barcode = '20071974'
    if change == 'pending': food.review_status = 'pending'
    session.add(food)
    session.commit()
    day = date(2026, 12, 1) if change == 'expired' else date(2026, 10, 24) if change == 'future' else date(2026, 10, 25)
    actual = asyncio.run(retailer_country_product_ids(adapter, {food.id}, as_of=day))
    assert actual == ({food.id} if change == 'none' else set())
    # An official catalogue proof is never an invented OFF country record.
    assert asyncio.run(off_available_product_ids(adapter, {food.id}, as_of=day)) == set()


def test_reference_is_pinned_and_keeps_off_times_instead_of_manufacturing_prices():
    from app.services.uk_system_recipe_reference import validate_reference, reviewed_system_recipe_references

    source = Path(__file__).resolve().parents[1]/'app/data/uk_system_recipe_ingredients_20261025.json'
    data = json.loads(source.read_text(encoding='utf-8'))
    off, retailer = reviewed_system_recipe_references()
    assert len(off) == 116 and len(retailer) == 4
    assert all(record.retrieved_at.date() == date(2026, 10, 25) for _, record in off)
    assert all('price' not in row and 'nutrition_per_100' not in row and 'package_quantity' not in row
        for row in data['retailer'])
    data['off'][0]['record']['product']['countries_tags'] = ['en:poland']
    with pytest.raises(ValueError, match='reviewed source'):
        validate_reference(data)


@pytest.mark.asyncio
async def test_no_extra_db_read_for_unrelated_user_product():
    from app.services.uk_system_recipe_reference import retailer_country_product_ids

    db = AsyncMock()
    assert await retailer_country_product_ids(db, {uuid4()}, as_of=date(2026, 10, 25)) == set()
    db.execute.assert_not_called()
