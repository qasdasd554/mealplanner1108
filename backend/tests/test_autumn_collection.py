"""Content regressions: quantities, country proof, privacy and repeat imports."""
import asyncio
from datetime import date
import json
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import select, func

from app.db.autumn_catalog import AUTUMN_RECIPES, AUTUMN_PRODUCT_NAMES, DATA, append_autumn_recipes
from app.db.seed import RECIPES_DATA, PRODUCTS_DATA, NUTRITION_DATA, PRODUCT_BRANDS, _uid, seed_database, calculate_nutrition
from app.models import Product, Recipe, RecipeIngredient
from app.services.product_measures import build_measure_options
from app.services.nutrition_calculator import compute_recipe_nutrition_total
from app.services.uk_autumn_reference import reviewed_autumn_references, validate_autumn_reference
from tests.test_regional_shopping import db

ROOT = Path(__file__).resolve().parents[2]
UNITS = {row[0]:row[1] for row in PRODUCTS_DATA}


def test_thirty_distinct_complete_recipes_match_source_servings_and_photos():
    assert len(AUTUMN_RECIPES) == 30
    old = [r for r in RECIPES_DATA if r['name'] not in {x['name'] for x in AUTUMN_RECIPES}]
    assert len(old) == 137
    assert len(append_autumn_recipes(old)) == 167
    for row, source in zip(AUTUMN_RECIPES, DATA['provenance']):
        assert row['servings'] == int(source['source_servings'].split()[0])
        assert row['instructions'] and row['description'] and len(row['ingredients']) >= 5
        assert len({x[0] for x in row['ingredients']}) == len(row['ingredients'])
        assert source['source_url'].startswith('https://centrumrespo.pl/przepisy/')
        assert (ROOT/'frontend/assets/recipe_photos'/source['photo_asset']).is_file()
    with pytest.raises(ValueError, match='Duplicate'):
        append_autumn_recipes(RECIPES_DATA)


@pytest.mark.parametrize('row', AUTUMN_RECIPES, ids=lambda r:r['name'])
def test_each_amount_resolves_and_seed_equals_runtime_without_unknown_or_fake_zero(row):
    ingredients=[]; expected={k:0 for k in ('kcal','protein','fat','carbs','fiber')}
    for name,q,unit,optional in row['ingredients']:
        assert name in UNITS and unit in {'g','ml','szt'} and q > 0
        food=Product(id=_uid('product:'+name),name=name,unit=UNITS[name],
            nutrition_per_100=NUTRITION_DATA[name],measure_options=build_measure_options(name,UNITS[name]))
        ingredients.append(RecipeIngredient(id=uuid4(),product=food,quantity=q,unit=unit,is_optional=optional))
        for key,value in calculate_nutrition(name,float(q),unit).items():expected[key]+=value
        if name in {'Cynamon','Imbir mielony','Goździki mielone'}:
            assert unit=='g' and q <= 5
        if name=='Jajka': assert unit=='szt' and q <= 3
        if name=='Bulion warzywny gotowy': assert unit=='ml'
    actual=compute_recipe_nutrition_total(ingredients)
    assert not actual.get('_incomplete'),actual
    assert 100 <= actual['kcal']/row['servings'] <= 1500
    assert all(actual[k] == round(v,1) for k,v in expected.items())
    if any(n in AUTUMN_PRODUCT_NAMES for n,*_ in row['ingredients']):assert actual['_estimated']


def test_country_reference_is_pinned_and_has_no_prices_packages_or_nutrition():
    assert len(reviewed_autumn_references()) == 68
    path=ROOT/'backend/app/data/uk_autumn_ingredients_20261102.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    for row in data['references']:
        assert set(row)=={'product_id','product_name','product_brand','country_code','source'}
    data['references'][0]['product_name']='Different food'
    with pytest.raises(ValueError,match='reviewed'):validate_autumn_reference(data)


@pytest.mark.parametrize('change',['none','name','brand','owner','barcode','pending','future','expired'])
def test_seasonal_country_proof_cannot_be_borrowed_or_renewed(db,change):
    from app.services.uk_system_recipe_reference import retailer_country_product_ids
    session,adapter,user,_,_=db
    name='Skyr waniliowy'
    food=Product(id=_uid('product:'+name),name=name,unit='g',brand=PRODUCT_BRANDS[name],review_status='approved')
    if change=='name':food.name='Different yoghurt'
    if change=='brand':food.brand='Different SKU'
    if change=='owner':food.created_by_user_id=user.id
    if change=='barcode':food.barcode='12345678'
    if change=='pending':food.review_status='pending'
    session.add(food);session.commit()
    day=date(2026,11,1) if change=='future' else date(2026,12,3) if change=='expired' else date(2026,11,2)
    assert asyncio.run(retailer_country_product_ids(adapter,{food.id},as_of=day))==({food.id} if change=='none' else set())


def test_seed_is_idempotent_and_does_not_translate_authored_recipes(db):
    session,adapter,user,_,_=db
    class SeedAdapter:
        async def merge(self, value): return session.merge(value)
        async def execute(self, *args, **kwargs): return session.execute(*args, **kwargs)
        async def flush(self): session.flush()
        def add_all(self, values): session.add_all(values)
    seed_adapter=SeedAdapter()
    authored=Recipe(id=uuid4(),name=AUTUMN_RECIPES[0]['name'],description='My private original',
        created_by_user_id=user.id,meal_type='obiad',instructions=['Original user step'],servings=1)
    session.add(authored);session.commit()
    asyncio.run(seed_database(seed_adapter));session.commit()
    first=session.scalar(select(func.count()).select_from(Recipe))
    asyncio.run(seed_database(seed_adapter));session.commit()
    assert session.scalar(select(func.count()).select_from(Recipe))==first==168
    assert authored.description=='My private original' and authored.instructions==['Original user step']
    for name in AUTUMN_PRODUCT_NAMES:
        food=session.get(Product,_uid('product:'+name))
        assert food.serving_quantity is None
        assert all(x['code']!='opak' for x in food.measure_options)
    from app.services.meal_plan_generator import MealPlanGenerator
    eligible=asyncio.run(MealPlanGenerator(adapter)._filter_eligible_recipes(
        allergen_ids=set(),store_id=_uid('store:Biedronka'),country_code='PL',user_id=user.id))
    assert {_uid('recipe:'+row['name']) for row in AUTUMN_RECIPES} <= {r.id for r in eligible}
