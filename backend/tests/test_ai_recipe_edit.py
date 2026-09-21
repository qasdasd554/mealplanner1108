"""Edycja przepisu przez AI: koszt i kontekst przekazywany modelowi."""

import asyncio
import json
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from app.api.v1.recipes import edit_recipe_with_ai
from app.schemas.recipe import AIRecipeEditRequest
from app.services import ai_recipe_import


def test_edit_requires_one_point_before_any_database_or_ai_call() -> None:
    user = SimpleNamespace(id=uuid.uuid4(), premium_points=0)
    db = SimpleNamespace(execute=AsyncMock())
    with pytest.raises(HTTPException) as exc:
        asyncio.run(edit_recipe_with_ai(
            uuid.uuid4(), AIRecipeEditRequest(prompt="Dodaj marchew"),
            current_user=user, db=db,
        ))
    assert exc.value.status_code == 402
    db.execute.assert_not_awaited()


def test_edit_rejects_recipe_waiting_for_moderation() -> None:
    user = SimpleNamespace(id=uuid.uuid4(), premium_points=1)
    recipe = SimpleNamespace(created_by_user_id=user.id, visibility="pending")
    result = MagicMock()
    result.scalar_one_or_none.return_value = recipe
    db = SimpleNamespace(execute=AsyncMock(return_value=result))
    with pytest.raises(HTTPException) as exc:
        asyncio.run(edit_recipe_with_ai(
            uuid.uuid4(), AIRecipeEditRequest(prompt="Dodaj marchew"),
            current_user=user, db=db,
        ))
    assert exc.value.status_code == 409


def test_revision_receives_original_recipe_and_instruction(monkeypatch) -> None:
    response = {
        "name": "Zupa z marchewką", "meal_type": "obiad", "servings": 2,
        "difficulty": "łatwy",
        "ingredients": [{"product_name": "Marchew", "quantity": 100, "unit": "g"}],
        "instructions": ["Ugotuj marchew."], "suggested_seasonings": [],
    }
    call = AsyncMock(return_value=json.dumps(response, ensure_ascii=False))
    monkeypatch.setattr(ai_recipe_import, "_call_gemini", call)
    result = asyncio.run(ai_recipe_import.revise_recipe_with_ai(
        {"name": "Zupa", "ingredients": [], "instructions": []},
        "Dodaj marchew", ["Marchew"],
    ))
    assert result["name"] == "Zupa z marchewką"
    prompt = call.await_args.args[0][0]["text"]
    assert "ISTNIEJĄCY PRZEPIS" in prompt
    assert "Dodaj marchew" in prompt


def test_malformed_ai_fields_are_cleaned_without_crashing() -> None:
    parsed = ai_recipe_import.validate_and_clean_recipe_dict({
        "name": "  Zupa  ", "meal_type": "obiad", "servings": "999999",
        "ingredients": [None, {"product_name": "Marchew", "quantity": 100, "unit": "g"}],
        "instructions": "Nie lista", "suggested_seasonings": None,
    })
    assert parsed["name"] == "Zupa"
    assert parsed["servings"] == 100
    assert len(parsed["ingredients"]) == 1
    assert parsed["instructions"] == []
