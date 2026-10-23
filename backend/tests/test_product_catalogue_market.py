"""UK canonical catalogue stays local/on-demand; no imported country dump."""
import asyncio
from types import SimpleNamespace
from uuid import uuid4

from app.api.v1.products import list_products
from tests.test_off_recipe_availability import db, facts, dish, Adapter


def test_uk_evidence_for_one_product_cannot_reveal_all_polish_products(db):
    facts(db)
    _, known = dish(db)
    _, missing = dish(db, barcode=None, name="Only in PL")
    user_id = uuid4()
    _, own = dish(db, barcode=None, name="My pending product")
    own.created_by_user_id, own.review_status = user_id, "pending"
    _, british = dish(db, barcode=None, name="Approved UK submission")
    british.submitted_country_code = "GB"
    db.flush()

    async def rows(country):
        return await list_products(skip=0, limit=50, search=None,
            current_user=SimpleNamespace(id=user_id, country_code=country),
            db=Adapter(db))

    assert {product.id for product in asyncio.run(rows("GB"))} == {known.id, own.id, british.id}
    assert missing.id in {product.id for product in asyncio.run(rows("PL"))}
