"""English system-label predicates; no name guesses, writes or external I/O."""
from functools import lru_cache
import hashlib
import json
from pathlib import Path
from uuid import UUID

from sqlalchemy import and_, case, false, or_

_LANGUAGES = {"GB": "en_GB", "DE": "de"}

@lru_cache(maxsize=1)
def _index():
    return json.loads((Path(__file__).resolve().parents[1] / 'data/system_content_index.json').read_text(encoding='utf-8'))


def recipe_display_name(recipe, *, country_code: str = 'PL') -> str:
    language = _LANGUAGES.get(country_code)
    if language is None or getattr(recipe, 'created_by_user_id', object()) is not None:
        return recipe.name
    row = _index()['recipes'].get(str(recipe.id))
    if row is None or row['source'] != recipe.name or row['description'] != recipe.description:
        return recipe.name
    return row[language]


def is_system_ingredient(product) -> bool:
    """Identify an unchanged canonical seed food, not an arbitrary branded SKU."""
    if getattr(product, 'created_by_user_id', object()) is not None:
        return False
    row = _index()['ingredients'].get(str(product.id))
    return row is not None and row['source'] == product.name


@lru_cache(maxsize=8)
def generic_system_ingredient_condition(model):
    """Shared cooking vocabulary, NOT evidence of sale in any country/shop.

    Only known unchanged system identities can be shown as generic foods.
    Authored foods, scanned SKUs and restaurant products keep market guards.
    """
    identities = or_(*(and_(model.id == UUID(identity), model.name == row['source'])
        for identity, row in _index()['ingredients'].items()))
    return and_(model.created_by_user_id.is_(None), model.barcode.is_(None),
        model.review_status == 'approved', identities)


def ingredient_display_name(product, *, country_code: str = 'PL') -> str:
    """Use the reviewed seed label without translating arbitrary authored food.

    This is only a language alias for the same product ID. It is not evidence
    of UK sale, a retailer offer, a pack weight or an ingredient substitution.
    """
    language = _LANGUAGES.get(country_code)
    if language is None or getattr(product, 'created_by_user_id', object()) is not None:
        return product.name
    row = _index()['ingredients'].get(str(product.id))
    if row is None or row['source'] != product.name:
        return product.name
    return row[language]


@lru_cache(maxsize=2)
def _recipe_translations(language='en_GB'):
    return json.loads((Path(__file__).resolve().parents[1] / f'data/system_recipes_{language}.json').read_text(encoding='utf-8'))


def recipe_display_content(recipe, *, country_code: str = 'PL') -> dict:
    canonical = dict(name=recipe.name, description=recipe.description,
        instructions=list(recipe.instructions or []),
        suggested_seasonings=list(recipe.suggested_seasonings or []))
    language = _LANGUAGES.get(country_code)
    if language is None or recipe.created_by_user_id is not None:
        return canonical
    row = _index()['recipes'].get(str(recipe.id))
    if row is None:
        return canonical
    fingerprint = hashlib.sha256(json.dumps(canonical, sort_keys=True,
        ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
    if fingerprint != row['detail_sha256']:
        return canonical
    translated = _recipe_translations(language).get(recipe.name)
    if translated is None:
        return canonical
    return dict(name=translated['name'], description=translated['description'],
        instructions=list(translated['instructions']),
        suggested_seasonings=list(translated['suggested_seasonings']))


def english_system_name_match(model, term: str, *, kind: str, country_code: str = 'GB'):
    needle = term.strip().casefold()
    if not needle or kind not in {'recipes', 'ingredients'}:
        return false()
    matches = []
    for identity, row in _index()[kind].items():
        if needle not in row[_LANGUAGES[country_code]].casefold():
            continue
        conditions = [model.id == UUID(identity), model.name == row['source'],
                      model.created_by_user_id.is_(None)]
        if kind == 'recipes':
            conditions.append(model.description == row['description'])
        matches.append(and_(*conditions))
    return or_(*matches) if matches else false()


def english_ingredient_name_in(model, names: set[str], *, country_code: str = 'GB'):
    """Match an exact, reviewed GB ingredient label to its canonical identity."""
    matches = [
        and_(model.id == UUID(identity), model.name == row['source'])
        for identity, row in _index()['ingredients'].items()
        if row[_LANGUAGES[country_code]].casefold() in names
    ]
    return and_(model.created_by_user_id.is_(None), or_(*matches)) if matches else false()


@lru_cache(maxsize=8)
def english_system_name_order(model, *, kind: str, country_code: str = 'GB'):
    clauses = []
    for identity, row in _index()[kind].items():
        conditions = [model.id == UUID(identity), model.name == row['source']]
        if kind == 'recipes':
            conditions.append(model.description == row['description'])
        clauses.append((and_(*conditions), row[_LANGUAGES[country_code]]))
    # Most growing-catalogue rows are authored: skip all seed checks for them.
    return case((model.created_by_user_id.is_(None), case(*clauses, else_=model.name)), else_=model.name)
