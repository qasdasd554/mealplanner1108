"""English display/search contract; no canonical records are rewritten."""
import importlib.util
import json
from datetime import date
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from sqlalchemy import create_engine, select, event
from sqlalchemy.orm import Session

from app.api.v1.recipes import _recipe_search_filter, _apply_recipe_sort
from app.models import Base, Product, Recipe, RecipeIngredient, User, FoodLogEntry
from app.api.v1.food_log import _to_response
from app.api.v1.recipes import save_recipe_variant
from app.schemas.recipe import RecipeVariantCreate
from tests.test_regional_shopping import AsyncDB, run
from tests.sqlite_uuid_compat import supply_sqlite_uuid_defaults

ROOT = Path(__file__).resolve().parents[2]
INDEX = json.loads((ROOT / 'backend/app/data/system_content_index.json').read_text(encoding='utf-8'))


def test_generated_source_contract_is_current_without_database_import():
    spec = importlib.util.spec_from_file_location('content_generator', ROOT / 'scripts/build_system_content_labels.py')
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    dart, index = generator.build()
    assert index == INDEX
    assert generator.parsed_maps(generator.OUTPUT.read_text(encoding='utf-8')) == generator.parsed_maps(dart)


@pytest.fixture(params=[False, True], ids=['native', 'without_returning'])
def db(request):
    engine = create_engine('sqlite:///:memory:')
    @event.listens_for(engine, 'connect')
    def register_uuid(connection, _):
        connection.create_function('gen_random_uuid', 0, lambda: uuid4().hex)
    Base.metadata.create_all(engine)
    if request.param:
        engine.dialect.insert_returning = False
    with Session(engine) as session:
        supply_sqlite_uuid_defaults(session)
        yield session
    engine.dispose()


def recipe(db, *, row_id=None, name='Synthetic bowl', description='', creator=None):
    row = Recipe(id=row_id or uuid4(), name=name, description=description,
        meal_type='obiad', servings=2, difficulty='łatwy', created_by_user_id=creator,
        instructions=['Original step'], nutrition_total={'kcal': 222}, visibility='public')
    db.add(row)
    db.flush()
    return row


def matches(db, text, country):
    return set(db.scalars(select(Recipe.id).where(_recipe_search_filter(text, country_code=country))))


def test_english_title_matches_only_unchanged_system_identity(db):
    row_id, item = next(iter(INDEX['recipes'].items()))
    original = recipe(db, row_id=UUID(row_id), name=item['source'], description=item['description'])
    user = User(id=uuid4(), email='uk-content@example.invalid', password_hash='synthetic', country_code='GB')
    db.add(user)
    db.flush()
    copied = recipe(db, name=item['source'], description=item['description'], creator=user.id)
    assert matches(db, item['en_GB'], 'GB') == {original.id}
    assert matches(db, item['en_GB'], 'PL') == set()
    assert matches(db, item['source'], 'PL') == {original.id, copied.id}
    original.name = 'Changed canonical name'
    db.flush()
    assert matches(db, item['en_GB'], 'GB') == set()


def test_english_ingredient_matches_exact_seed_product_without_multiplying_rows(db):
    product_id, item = next((key, row) for key, row in INDEX['ingredients'].items() if row['en_GB'] == 'Potatoes')
    product = Product(id=UUID(product_id), name=item['source'], unit='g')
    db.add(product)
    main = recipe(db)
    for amount in (100, 50):
        db.add(RecipeIngredient(id=uuid4(), recipe_id=main.id, product_id=product.id, quantity=amount, unit='g', is_optional=False))
    db.flush()
    assert matches(db, 'pOtAtOeS', 'GB') == {main.id}
    assert matches(db, 'potatoes', 'PL') == set()
    assert matches(db, '%_', 'GB') == set()
    product.name = 'Edited ingredient source'
    db.flush()
    assert matches(db, 'potatoes', 'GB') == set()


def test_search_keeps_user_authored_english_and_author_names(db):
    user = User(id=uuid4(), email='uk-author@example.invalid', password_hash='synthetic', display_name='SyntheticChef', country_code='GB')
    db.add(user)
    db.flush()
    own = recipe(db, name='My English toast', creator=user.id)
    assert matches(db, 'English toast', 'GB') == {own.id}
    assert matches(db, 'SyntheticChef', 'GB') == {own.id}


def test_sort_uses_displayed_english_name_and_falls_back_for_changed_content(db):
    row_id, item = next(iter(INDEX['recipes'].items()))
    original = recipe(db, row_id=UUID(row_id), name=item['source'], description=item['description'])
    second = recipe(db, name='Egg toast')
    assert item['en_GB'].startswith('Courgette')
    query = select(Recipe.id)
    assert list(db.scalars(_apply_recipe_sort(query, 'name', country_code='GB'))) == [original.id, second.id]
    assert list(db.scalars(_apply_recipe_sort(query, 'name', country_code='PL'))) == [second.id, original.id]
    original.description = 'Edited original description'
    db.flush()
    assert list(db.scalars(_apply_recipe_sort(query, 'name', country_code='GB'))) == [second.id, original.id]


def test_diary_system_title_is_display_only_and_authored_names_stay_original(db):
    row_id, item = next(iter(INDEX['recipes'].items()))
    original = recipe(db, row_id=UUID(row_id), name=item['source'], description=item['description'])
    user = User(id=uuid4(), email='uk-diary@example.invalid', password_hash='synthetic', country_code='GB')
    db.add(user)
    entry = FoodLogEntry(id=uuid4(), user_id=user.id, date=date(2026, 10, 22),
        meal_type='obiad', recipe=original, recipe_id=original.id, servings=1,
        calories=222, protein=20, carbs=30, fat=8)
    db.add(entry)
    db.flush()
    assert _to_response(entry, country_code='GB').recipe_name == item['en_GB']
    assert _to_response(entry, country_code='PL').recipe_name == item['source']
    assert entry.recipe.name == item['source']
    assert entry.calories == 222
    original.created_by_user_id = user.id
    assert _to_response(entry, country_code='GB').recipe_name == item['source']


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_saving_system_variant_uses_account_language_but_never_rewrites_source(db, country):
    row_id, item = next(iter(INDEX['recipes'].items()))
    translations = json.loads((ROOT / 'backend/app/data/system_recipes_en_GB.json').read_text(encoding='utf-8'))
    spec = importlib.util.spec_from_file_location('content_generator_variant', ROOT / 'scripts/build_system_content_labels.py')
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    dart, _ = generator.build()
    source = generator.parsed_maps(dart)[0][row_id]['source']
    original = recipe(db, row_id=UUID(row_id), name=source['name'], description=source['description'])
    original.instructions = list(source['instructions'])
    original.suggested_seasonings = list(source['suggested_seasonings'])
    # Admin intentionally avoids unrelated availability setup in this language test.
    user = User(id=uuid4(), email=f'variant-{country}@example.invalid', password_hash='synthetic', country_code=country, role='admin')
    product = Product(id=uuid4(), name='Synthetic flour', unit='g', review_status='approved',
        nutrition_per_100={'kcal': 100, 'protein': 2, 'fat': 3, 'carbs': 20})
    db.add_all([user, product])
    db.flush()
    payload = RecipeVariantCreate(ingredients=[{'product_id': product.id, 'quantity': 100, 'unit': 'g'}])
    before = (original.name, original.description, list(original.instructions), list(original.suggested_seasonings))
    expected = translations[source['name']] if country == 'GB' else source
    for number in (1, 2):
        saved = run(save_recipe_variant(original.id, payload, current_user=user, db=AsyncDB(db)))
        assert saved.name == expected['name'] + (' - edited ' if country == 'GB' else ' - edytowane ') + str(number)
        assert saved.description == expected['description']
        assert saved.instructions == expected['instructions']
        assert saved.suggested_seasonings == expected['suggested_seasonings']
        assert saved.created_by_user_id == user.id and saved.visibility == 'private'
        assert saved.nutrition_total['kcal'] == 100
        assert (original.name, original.description, original.instructions, original.suggested_seasonings) == before
