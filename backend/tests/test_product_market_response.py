from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from app.schemas.product import ProductResponse, StoreProductResponse


def product(**extra):
    return SimpleNamespace(id=uuid4(), name="Rice", unit="g",
                           created_at=datetime.now(timezone.utc), **extra)


def test_product_response_exposes_submission_country_not_viewer_country():
    value = ProductResponse.model_validate(product(submitted_country_code="GB",
                                                    submitted_price=3.5))
    assert value.model_dump(mode="json")["submitted_country_code"] == "GB"
    assert value.submitted_price == 3.5


def test_legacy_submission_keeps_polish_currency_provenance():
    assert ProductResponse.model_validate(product()).submitted_country_code == "PL"


def test_legacy_store_row_is_explicitly_pln_even_without_price_currency_column():
    row = SimpleNamespace(id=uuid4(), store_id=uuid4(), product_id=uuid4(),
                          price=2.5, is_available=True, product=product())
    assert StoreProductResponse.model_validate(row).model_dump(mode="json")["currency_code"] == "PLN"
