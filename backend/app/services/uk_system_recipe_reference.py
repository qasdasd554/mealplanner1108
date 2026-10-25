"""Small reviewed country-food references; no DB writes or live-stock claims.

OFF and official retailer catalogue observations remain separate providers.
Neither transfers another SKU's price, nutrition, package or allergen data.
"""
from datetime import date, datetime, timedelta
from functools import lru_cache
import hashlib
import json
from pathlib import Path
from types import MappingProxyType
from uuid import UUID

from sqlalchemy import and_, exists, false, or_, select
from sqlalchemy.orm import aliased

from app.models import Product
from app.services.off_ingredient_mapping import OffMappingProposal
from app.services.system_content_language import _index
from app.services.uk_starter_import import StarterProduct

REFERENCE_SHA256 = '7d0f75bd3a12d891a2b9ee480bd69933d0fa71406a7d1825ea007746be5cc2df'
_RETAILER_URLS = frozenset({
    'https://www.slovakia-foods.co.uk/smot-slah-trv-30-250ml-tami-box-27pcs.html',
    'https://www.waitrose.com/ecom/products/cooks-ingredients-sage/086111-43939-43940',
    'https://www.tesco.com/shop/en-GB/products/258905427',
    'https://www.slovakia-foods.co.uk/puding-v-prasku-s-vanilkovou-aromou-40g-fresh-box-30pcs.html',
})


def validate_reference(data):
    canonical = json.dumps(data, sort_keys=True, ensure_ascii=False,
        separators=(',', ':'), allow_nan=False).encode()
    if hashlib.sha256(canonical).hexdigest() != REFERENCE_SHA256:
        raise ValueError('UK system recipe references differ from the reviewed source')
    if (data['version'] != 1 or data['automatic_import'] is not False
            or data['off_licence'] != 'ODbL-1.0'
            or data['off_attribution_url'] != 'https://world.openfoodfacts.org'
            or len(data['off']) != 116 or len(data['retailer']) != 4):
        raise ValueError('Unexpected country reference schema or size')
    identities, off = set(), []
    for row in data['off']:
        link = OffMappingProposal.model_validate(row['proposal'])
        packet = row['record']
        record = StarterProduct(json.dumps(packet['product'], ensure_ascii=False),
            datetime.fromisoformat(packet['retrieved_at']))
        if (packet['http_status'] != 200 or record.raw['code'] != link.off_barcode
                or packet['source_endpoint'] != f'https://world.openfoodfacts.org/api/v3/product/{link.off_barcode}.json'
                or record.values['fingerprint'] != link.off_fingerprint):
            raise ValueError('Country reference must retain its exact OFF snapshot')
        if str(link.product_id) in identities or _index()['ingredients'][str(link.product_id)]['source'] != link.product_name:
            raise ValueError('Unknown or duplicate canonical food identity')
        identities.add(str(link.product_id))
        off.append((link, record))
    retailer = []
    for row in data['retailer']:
        source = row['source']
        checked = datetime.fromisoformat(source['reviewed_at'])
        if (source['url'] not in _RETAILER_URLS or row['country_code'] != 'GB'
                or checked.tzinfo is None or source['kind'] != 'country_catalogue_listing'
                or not source['retailer_sku'] or not source['publisher']
                or row['product_id'] in identities
                or _index()['ingredients'][row['product_id']]['source'] != row['product_name']):
            raise ValueError('Invalid reviewed UK retailer country reference')
        identities.add(row['product_id'])
        retailer.append(MappingProxyType({
            'product_id':UUID(row['product_id']), 'product_name':row['product_name'],
            'product_brand':row['product_brand'], 'reviewed_on':checked.date(),
        }))
    return tuple(off), tuple(retailer)


@lru_cache(maxsize=1)
def reviewed_system_recipe_references():
    path = Path(__file__).resolve().parents[1]/'data/uk_system_recipe_ingredients_20261025.json'
    raw = path.read_bytes()
    if len(raw) > 2_000_000:
        raise ValueError('UK reference exceeds its bounded size')
    return validate_reference(json.loads(raw.decode('utf-8')))


def retailer_country_evidence_condition(product_id, *, as_of: date):
    if type(as_of) is not date:
        raise ValueError('An explicit calendar date is required')
    food = aliased(Product)
    matches = [and_(food.id == row['product_id'], food.name == row['product_name'],
        food.brand.is_not_distinct_from(row['product_brand']))
        for row in reviewed_system_recipe_references()[1]
        if as_of-timedelta(days=30) <= row['reviewed_on'] <= as_of]
    if not matches:
        return false()
    return exists(select(1).select_from(food).where(food.id == product_id,
        food.created_by_user_id.is_(None), food.barcode.is_(None),
        food.review_status == 'approved', or_(*matches)).correlate_except(food))


async def retailer_country_product_ids(db, product_ids, *, as_of: date):
    relevant = set(product_ids) & {row['product_id'] for row in reviewed_system_recipe_references()[1]}
    if not relevant:
        return set()
    result = await db.execute(select(Product.id).where(Product.id.in_(relevant),
        retailer_country_evidence_condition(Product.id, as_of=as_of)))
    return set(result.scalars().all())
