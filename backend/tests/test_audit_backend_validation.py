"""Invalid input must stop at API validation, before database writes."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.api.v1.notifications import DeviceTokenRequest
from app.api.v1.shopping_lists import AddItemRequest
from app.core.safe_url import UnsafeUrlError, validate_public_http_url


@pytest.mark.parametrize("quantity", [float("nan"), float("inf"), -1, 0, 10000])
def test_catalog_shopping_item_rejects_invalid_amount(quantity):
    with pytest.raises(ValidationError):
        AddItemRequest(product_id=uuid4(), quantity=quantity)


@pytest.mark.parametrize("payload", [{"token": "x" * 513}, {"token": "valid", "platform": "x" * 11}])
def test_device_token_cannot_exceed_database_columns(payload):
    with pytest.raises(ValidationError):
        DeviceTokenRequest(**payload)


@pytest.mark.asyncio
@pytest.mark.parametrize("url", ["http://[broken/", "https://example.com:invalid/", "https://8.8.8.8:99999/"])
async def test_invalid_url_authority_has_safe_error(url):
    with pytest.raises(UnsafeUrlError):
        await validate_public_http_url(url)


@pytest.mark.asyncio
async def test_repeated_shopping_completion_does_not_move_pantry_twice(monkeypatch):
    from app.api.v1 import shopping_lists
    shopping = SimpleNamespace(id=uuid4(), status="completed", items=[SimpleNamespace(is_checked=True, is_from_pantry=False, store_product=SimpleNamespace(product_id=uuid4()), required_quantity=1, unit="szt")])
    monkeypatch.setattr(shopping_lists, "_get_shopping_list_or_404", AsyncMock(return_value=shopping))
    db = AsyncMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = SimpleNamespace(quantity=0, unit="szt")
    db.execute.return_value = result
    db.add = MagicMock()
    response = await shopping_lists.complete_shopping_list(uuid4(), True, SimpleNamespace(id=uuid4()), db)
    assert response["moved_to_pantry"] == 0
    db.add.assert_not_called()
