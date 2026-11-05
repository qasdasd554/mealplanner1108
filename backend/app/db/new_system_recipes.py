"""Bilingual system recipe collections using existing catalogue foods."""

import json
from decimal import Decimal
from pathlib import Path


DATA_DIR = Path(__file__).resolve().parents[1] / 'data'
COLLECTIONS = ('new_system_recipes_20261105.json', 'winter_recipes_20261105.json')
DATA = [row for filename in COLLECTIONS
        for row in json.loads((DATA_DIR / filename).read_text(encoding='utf-8'))]
NEW_SYSTEM_RECIPES = [
    dict(
        {key: value for key, value in row.items() if key != 'photo'},
        ingredients=[(name, Decimal(quantity), unit, optional)
                     for name, quantity, unit, optional in row['ingredients']],
    )
    for row in DATA
]
NEW_SYSTEM_RECIPE_NAMES = frozenset(row['name'] for row in NEW_SYSTEM_RECIPES)
