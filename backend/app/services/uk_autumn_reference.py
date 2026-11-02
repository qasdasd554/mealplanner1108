"""Pinned UK country-food observations for the autumn additions.

These pages establish a generic ingredient in the UK catalogue, not current
stock at any of our shops, a package size, price or another SKU's nutrition.
The original observation date expires normally; there is no startup fetch.
"""
from datetime import date
from functools import lru_cache
import hashlib
import json
from pathlib import Path
from types import MappingProxyType
from urllib.parse import urlparse
from uuid import UUID

REFERENCE_SHA256 = 'fd059f324a54b160f2dfab5d4d97ce92c0a410f7b52bbf7b4d700c59293c4a90'


def validate_autumn_reference(data):
    canonical = json.dumps(data, sort_keys=True, ensure_ascii=False,
                           separators=(',', ':'), allow_nan=False).encode()
    if hashlib.sha256(canonical).hexdigest() != REFERENCE_SHA256:
        raise ValueError('Autumn country references differ from reviewed observations')
    if data['version'] != 1 or data['automatic_import'] is not False or len(data['references']) != 68:
        raise ValueError('Unexpected autumn reference schema')
    from app.services.system_content_language import _index
    seen, result = set(), []
    for row in data['references']:
        source = row['source']
        identity = row['product_id']
        if (identity in seen or row['country_code'] != 'GB'
                or _index()['ingredients'].get(identity, {}).get('source') != row['product_name']
                or source['kind'] != 'country_catalogue_listing'
                or urlparse(source['url']).scheme != 'https'
                or urlparse(source['url']).hostname != source['publisher']
                or not source['food_concept']):
            raise ValueError('Invalid autumn country food identity/source')
        seen.add(identity)
        result.append(MappingProxyType(dict(product_id=UUID(identity),
            product_name=row['product_name'], product_brand=row['product_brand'],
            reviewed_on=date.fromisoformat(source['reviewed_on']))))
    return tuple(result)


@lru_cache(maxsize=1)
def reviewed_autumn_references():
    path = Path(__file__).resolve().parents[1] / 'data/uk_autumn_ingredients_20261102.json'
    raw = path.read_bytes()
    if len(raw) > 100_000:
        raise ValueError('Autumn country reference exceeds bounded size')
    return validate_autumn_reference(json.loads(raw))
