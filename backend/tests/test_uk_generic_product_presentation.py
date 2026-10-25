"""A food concept's UK availability does not prove its Polish brand or pack."""

import asyncio
from types import SimpleNamespace
from uuid import uuid4
from unittest.mock import AsyncMock

import pytest

from app.api.v1.products import get_product, list_products
from app.api.v1.pantry import get_pantry, PantryItemResponse
from app.models import PantryItem
from app.schemas.product import ProductResponse
from tests.test_uk_catalogue_import import AsyncAdapter, catalogue_db
from tests.test_uk_seed_off_identity import seeded_oats


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("entrypoint", ["catalogue", "detail", "pantry"])
def test_generic_seed_presentation_never_claims_polish_brand_or_pack_in_uk(catalogue_db, country, entrypoint):
    session, owner, _ = catalogue_db
    food = seeded_oats()
    # The separate country-availability predicates are tested elsewhere. This
    # fixture lets the catalogue reach presentation without an external request.
    food.submitted_country_code = "GB"
    food.measure_options = [
        {"code": "opak", "label": "opakowanie", "base_unit": "g", "base_quantity": 500},
        {"code": "szklanka", "label": "szklanka", "base_unit": "g", "base_quantity": 110,
         "approximate": True},
    ]
    session.add(food)
    session.flush()
    pantry = PantryItem(id=uuid4(), user_id=owner, product_id=food.id, quantity=60, unit="g")
    session.add(pantry)
    session.commit()
    account = SimpleNamespace(id=owner, country_code=country)
    adapter = AsyncAdapter(session)
    if entrypoint == "catalogue":
        values = asyncio.run(list_products(skip=0, limit=50, search="owsiane", db=adapter,
                                          current_user=account))
        response = ProductResponse.model_validate(next(value for value in values if value.id == food.id))
    elif entrypoint == "detail":
        response = ProductResponse.model_validate(asyncio.run(get_product(food.id, adapter, account)))
    else:
        values = asyncio.run(get_pantry(account, adapter))
        item = PantryItemResponse.model_validate(next(value for value in values if value.id == pantry.id))
        assert item.quantity == 60 and item.unit == "g"
        response = item.product
    assert response.brand == ("Sante" if country == "PL" else None)
    assert response.serving_quantity == (500 if country == "PL" else None)
    assert {option.code for option in response.measure_options} == (
        {"opak", "szklanka"} if country == "PL" else {"szklanka"})
    assert response.nutrition_per_100.kcal == 389
    assert food.brand == "Sante" and food.serving_quantity == 500
    assert len(food.measure_options) == 2 and not session.dirty


@pytest.mark.parametrize("change", ["different_id", "renamed", "authored", "exact_barcode"])
def test_real_sku_and_authored_food_keep_their_actual_brand_and_pack(catalogue_db, change):
    session, owner, _ = catalogue_db
    food = seeded_oats()
    if change == "different_id": food.id = uuid4()
    elif change == "renamed": food.name = "A real branded oats product"
    elif change == "authored": food.created_by_user_id = owner
    else: food.barcode = "5099801003339"
    session.add(food)
    session.commit()
    response = ProductResponse.model_validate(asyncio.run(get_product(
        food.id, AsyncAdapter(session), SimpleNamespace(id=owner, country_code="GB"))))
    assert response.brand == "Sante" and response.serving_quantity == 500


@pytest.mark.parametrize("query", ["Oats", "owsiane"])
def test_uk_name_suggestions_use_english_identity_without_pl_brand_pack_or_unavailable_food(
        catalogue_db, monkeypatch, query):
    from app.api.v1.products import search_products_by_name
    from app.models import Product
    session, owner, _ = catalogue_db
    food = seeded_oats()
    food.submitted_country_code = "GB"
    not_in_uk = Product(id=uuid4(), name="Płatki owsiane tylko PL", brand="Polish only",
        unit="g", review_status="approved", submitted_country_code="PL")
    session.add_all([food, not_in_uk])
    session.commit()
    external = AsyncMock(return_value=[])
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", external)
    values = asyncio.run(search_products_by_name(query, 10, AsyncAdapter(session),
        SimpleNamespace(id=owner, country_code="GB")))
    local = [value for value in values if value.existing_product_id is not None]
    assert {value.existing_product_id for value in local} == {food.id}
    assert local[0].name == "Oats"
    assert local[0].brand is None and local[0].serving_quantity is None
    assert local[0].kcal_per_100 == 389
    assert local[0].price_min is None and local[0].price_max is None
    assert food.brand == "Sante" and food.serving_quantity == 500 and not session.dirty
