"""Reviewed autumn additions: system content only, no network or DB import."""
import json
from decimal import Decimal
from pathlib import Path

DATA = json.loads((Path(__file__).resolve().parents[1] /
    'data/autumn_recipes_20261102.json').read_text(encoding='utf-8'))
AUTUMN_PRODUCT_NAMES = frozenset(row['name'] for row in DATA['products'])
# The same static, unverified indicative cost model as the existing Polish
# seed. Prices are per 100 g/ml, NEVER a claim about package size or live stock.
# No values are copied into verified retailer offers or the UK GBP quote table.
PLN_ESTIMATE_PER_100 = {
    'Bulion warzywny gotowy': '.40', 'Chleb żytni razowy': '1.20',
    'Erytrytol': '3.00', 'Granulat sojowy suchy': '3.00',
    'Grzyby leśne świeże': '6.00', 'Imbir mielony': '17.45',
    'Kapusta kiszona': '.90', 'Ksylitol': '4.00', 'Kurki świeże': '8.00',
    'Majeranek suszony': '20.00', 'Makaron pełnoziarnisty': '1.20',
    'Mleko 1,5%': '.35', 'Mozzarella light': '4.79', 'Mąka owsiana': '1.50',
    'Nachosy naturalne': '3.00', 'Ocet spirytusowy': '1.00', 'Ogórki kiszone': '1.20',
    'Papryczka chili świeża': '6.00', 'Polędwica wołowa': '12.00',
    'Pudding proteinowy waniliowy': '2.50', 'Rostbef wołowy': '8.33',
    'Skyr waniliowy': '2.66', 'Sok pomarańczowy': '.80', 'Sok z cytryny': '2.50',
    'Tortilla pełnoziarnista': '3.00', 'Wieprzowina mielona': '2.50',
    'Woda': '.10', 'Śmietana 12%': '1.25', 'Śmietanka 12%': '1.50',
}
AUTUMN_PRODUCTS = [(row['name'], row['unit'], Decimal('100'), row['department'],
                   Decimal(PLN_ESTIMATE_PER_100[row['name']]), row['allergens'])
                  for row in DATA['products']]
AUTUMN_NUTRITION = {row['name']: dict(row['nutrition'], _source={
    'provider': 'reviewed_generic_estimate', 'status': 'estimated',
    'basis_unit': row['unit'], 'allergens_checked': False,
}) for row in DATA['products']}
AUTUMN_RECIPES = [dict(row, ingredients=[
    (name, Decimal(quantity), unit, optional)
    for name, quantity, unit, optional in row['ingredients']])
    for row in DATA['recipes']]
AUTUMN_RECIPE_NAMES = frozenset(row['name'] for row in AUTUMN_RECIPES)


def append_autumn_recipes(existing):
    """Fail closed on an accidental bundled duplicate, never change old meals."""
    def fingerprint(row):
        return tuple(sorted((name.casefold(), str(Decimal(qty) / row['servings']), unit)
            for name, qty, unit, optional in row['ingredients'] if not optional))
    names = {row['name'].strip().casefold() for row in existing}
    fingerprints = {fingerprint(row) for row in existing}
    for row in AUTUMN_RECIPES:
        key = row['name'].strip().casefold()
        signature = fingerprint(row)
        if key in names or signature in fingerprints:
            raise ValueError('Duplicate autumn system recipe: ' + row['name'])
        names.add(key)
        fingerprints.add(signature)
    return [*existing, *AUTUMN_RECIPES]
