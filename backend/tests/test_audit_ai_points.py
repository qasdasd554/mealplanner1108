"""A stale auth snapshot must not permit a second AI point debit."""

import asyncio
from copy import copy
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select, update

from app.api.v1.recipes import _create_ai_recipe
from app.models import Product, Recipe, User
from app.schemas.recipe import AIRecipeImportRequest
from tests.test_meal_plan_lifecycle import db


def test_ai_import_rechecks_balance_after_extraction(db, monkeypatch):
    user = User(id=uuid4(), email=f"{uuid4()}@example.com", password_hash="test", role="user", is_premium=False, premium_points=2)
    product = Product(id=uuid4(), name="Marchew", unit="g", review_status="approved", nutrition_per_100={"kcal": 40, "protein": 1, "fat": 1, "carbs": 8})
    db.session.add_all([user, product])
    db.session.commit()
    snapshot = user
    async def extraction(*args):
        # Another operation consumed the balance after the initial check.
        db.session.execute(update(User).where(User.id == user.id).values(premium_points=0).execution_options(synchronize_session=False))
        db.session.commit()
        return {"name": "Marchew", "meal_type": "obiad", "servings": 1, "difficulty": "łatwy", "ingredients": [{"product_name": "Marchew", "quantity": 100, "unit": "g"}], "instructions": ["Ugotuj."]}
    monkeypatch.setattr("app.services.ai_recipe_import.extract_recipe_from_text", extraction)
    with pytest.raises(HTTPException) as error:
        asyncio.run(_create_ai_recipe(AIRecipeImportRequest(text="Marchew"), snapshot, db, skip_rate_limit=True))
    assert error.value.status_code == 402
    assert db.session.scalar(select(Recipe)) is None
    db.session.refresh(user)
    assert user.premium_points == 0
