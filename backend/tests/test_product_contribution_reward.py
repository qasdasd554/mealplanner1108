"""Regresje naliczania punktów za zgłoszenia produktów."""

import asyncio
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock

from app.api.v1.products import ProductSubmission, submit_product
from app.models import Product, ProductContributionReward

from app.api.v1.products import _product_contribution_key


def test_barcode_is_the_reward_identity_when_present() -> None:
    first = _product_contribution_key(
        barcode="5901234123457", name="Dowolna nazwa", brand="Marka A",
    )
    second = _product_contribution_key(
        barcode="5901234123457", name="Inna nazwa", brand="Marka B",
    )
    assert first == second == "barcode:5901234123457"


def test_manual_reward_identity_ignores_case_and_extra_spaces() -> None:
    first = _product_contribution_key(
        barcode=None, name="  Jogurt   naturalny ", brand="Łowicz",
    )
    second = _product_contribution_key(
        barcode=None, name="jogurt naturalny", brand="  ŁOWICZ ",
    )
    assert first == second


def test_different_manual_products_have_different_reward_keys() -> None:
    first = _product_contribution_key(
        barcode=None, name="Jogurt naturalny", brand="Marka A",
    )
    second = _product_contribution_key(
        barcode=None, name="Jogurt naturalny", brand="Marka B",
    )
    assert first != second


def test_new_submission_adds_product_reward_and_one_point(monkeypatch) -> None:
    user = SimpleNamespace(id=uuid.uuid4(), premium_points=4, display_name="Anna")

    class FakeDb:
        def __init__(self) -> None:
            self.scalar_calls = 0
            self.added = []
            self.commits = 0

        async def scalar(self, _statement):
            self.scalar_calls += 1
            return None if self.scalar_calls == 1 else user

        def add(self, value) -> None:
            self.added.append(value)

        async def flush(self) -> None:
            product = next(value for value in self.added if isinstance(value, Product))
            product.id = uuid.uuid4()
            product.created_at = datetime.now(timezone.utc)

        async def commit(self) -> None:
            self.commits += 1

        async def rollback(self) -> None:
            raise AssertionError("Poprawne zgłoszenie nie może wycofać transakcji")

        async def refresh(self, _value) -> None:
            return None

    monkeypatch.setattr(
        "app.core.rate_limit.enforce_user_rate_limit", lambda *_args: None,
    )
    notify = AsyncMock(return_value=1)
    monkeypatch.setattr(
        "app.services.admin_notifications.notify_admins_pending_review", notify,
    )
    db = FakeDb()

    response = asyncio.run(
        submit_product(ProductSubmission(name="Nowy produkt"), db=db, current_user=user)
    )

    assert response.points_awarded == 1
    assert response.premium_points == 5
    assert user.premium_points == 5
    assert any(isinstance(value, Product) for value in db.added)
    assert any(isinstance(value, ProductContributionReward) for value in db.added)
    assert db.commits == 1
    notify.assert_awaited_once()
