"""Regresja: decyzja administratora nie może zależeć od opcjonalnego sklepu."""

import asyncio
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from app.api.v1.products import review_product


def _pending_product():
    return SimpleNamespace(
        id=uuid.uuid4(), review_status="pending",
        requested_store_ids=None, submitted_price=None,
        created_by_user_id=None, name="Produkt testowy",
    )


def test_admin_can_approve_product_without_store_or_price() -> None:
    product = _pending_product()
    db = SimpleNamespace(get=AsyncMock(return_value=product),
                         add=MagicMock(), commit=AsyncMock())
    asyncio.run(review_product(
        product.id, approve=True, db=db,
        current_user=SimpleNamespace(role="admin"),
    ))
    assert product.review_status == "approved"
    db.commit.assert_awaited_once()


def test_admin_can_correct_previous_rejection() -> None:
    product = _pending_product()
    product.review_status = "rejected"
    db = SimpleNamespace(get=AsyncMock(return_value=product),
                         add=MagicMock(), commit=AsyncMock())
    asyncio.run(review_product(
        product.id, approve=True, db=db,
        current_user=SimpleNamespace(role="admin"),
    ))
    assert product.review_status == "approved"
    db.commit.assert_awaited_once()


def test_store_error_does_not_undo_approval() -> None:
    product = _pending_product()
    product.requested_store_ids = [str(uuid.uuid4())]
    product.submitted_price = Decimal("5.00")
    nested = MagicMock()
    nested.__aenter__ = AsyncMock()
    nested.__aexit__ = AsyncMock(return_value=False)
    db = SimpleNamespace(
        get=AsyncMock(side_effect=[product, RuntimeError("store lookup failed")]),
        add=MagicMock(),
        commit=AsyncMock(),
        begin_nested=MagicMock(return_value=nested),
    )
    asyncio.run(review_product(
        product.id, approve=True, db=db,
        current_user=SimpleNamespace(role="admin"),
    ))
    assert product.review_status == "approved"
    assert db.commit.await_count == 2
