import asyncio
from datetime import date
from decimal import Decimal
from types import SimpleNamespace as NS
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.api.v1 import products
from app.schemas.product import SubstituteResponse


@pytest.fixture
def state(monkeypatch):
    item = NS(id=uuid4(), name="Polska nazwa", brand=None,
              review_status="approved", created_by_user_id=None,
              nutrition_per_100={"kcal": 365})
    user = NS(id=uuid4(), country_code="GB")
    store_id = uuid4()
    quote = NS(product_id=item.id, store_id=store_id, name_en="British 500g pack",
               price_per_package=Decimal("1.25"), package_quantity=Decimal(500),
               unit="g", currency_code="GBP", price_is_estimated=False,
               last_verified=date(2026, 10, 16))
    service = NS(find_substitutes=AsyncMock(), auto_find_similar=AsyncMock(return_value=[]))
    monkeypatch.setattr(products, "ProductSubstitutionService", lambda db: service)
    monkeypatch.setattr(products, "get_store_in_account_market", AsyncMock(return_value=NS(id=store_id)))
    database = NS(execute=AsyncMock(return_value=NS(scalar_one_or_none=lambda: item)))
    return NS(item=item, user=user, store_id=store_id, quote=quote, service=service, db=database)


def response(state):
    return asyncio.run(products.get_product_substitutes(
        product_id=state.item.id, store_id=state.store_id, db=state.db, current_user=state.user,
    ))


def test_gb_response_exposes_reviewed_local_package_price_not_legacy_pl_pack(state):
    state.service.find_substitutes.return_value = [{
        "product": state.item, "regional_quote": state.quote,
        "store_product": NS(price=Decimal("99.99")), "similarity_score": 0.9,
    }]
    value = SubstituteResponse.model_validate(response(state)[0]).model_dump(mode="json")
    assert value["name"] == "British 500g pack"
    assert value["currency_code"] == "GBP"
    assert value["price"] == 1.25
    assert value["package_quantity"] == 500
    assert value["package_unit"] == "g"
    assert value["last_verified"] == "2026-10-16"
    assert value["price_is_estimated"] is False


@pytest.mark.parametrize("mismatch", ["legacy_only", "store", "product", "currency"])
def test_gb_rejects_unreviewed_or_foreign_substitute_price(state, mismatch):
    row = {"product": state.item, "regional_quote": state.quote}
    if mismatch == "legacy_only":
        row = {"product": state.item, "store_product": NS(price=5)}
    else:
        setattr(state.quote, {"store": "store_id", "product": "product_id", "currency": "currency_code"}[mismatch],
                "PLN" if mismatch == "currency" else uuid4())
    state.service.find_substitutes.return_value = [row]
    assert response(state) == []


def test_pl_substitution_keeps_original_name_and_price_even_if_extra_quote_exists(state):
    state.user.country_code = "PL"
    state.service.find_substitutes.return_value = [{
        "product": state.item, "regional_quote": state.quote,
        "store_product": NS(price=Decimal("3.99"), last_verified=None),
    }]
    value = SubstituteResponse.model_validate(response(state)[0]).model_dump(mode="json")
    assert value["name"] == "Polska nazwa"
    assert value["price"] == 3.99
    assert value["currency_code"] == "PLN"
    assert value["package_quantity"] is None
