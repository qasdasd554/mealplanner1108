"""Account market follows AI requests without changing recipe API identifiers."""

import asyncio
import base64
from io import BytesIO
import json
from contextlib import asynccontextmanager
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import httpx
import pytest
from fastapi import HTTPException
from sqlalchemy import select
from PIL import Image
from bs4 import BeautifulSoup

from app.api.v1 import recipes, recipe_import_jobs
from app.models import Notification, Product, Recipe, RecipeImportJob, RecipeIngredient, User
from app.schemas.recipe import AIRecipeEditRequest, AIRecipeImportRequest
from app.services import ai_recipe_import as ai, recipe_import_worker as worker
from tests.test_meal_plan_lifecycle import db


def recipe_data():
    return {
        "name": "Carrot soup", "description": "A warming soup.",
        "meal_type": "obiad", "difficulty": "łatwy", "servings": 2,
        "ingredients": [{"product_name": "Marchew", "quantity": 200, "unit": "g"}],
        "instructions": ["Simmer the carrots (200 g)."], "suggested_seasonings": [],
    }


def test_gb_prompt_requires_english_but_preserves_protocol_and_product_names():
    prompt = ai._build_prompt(["Marchew", "Mövenpick"], country_code="GB")
    assert "British English" in prompt
    assert "śniadanie, obiad, kolacja, przekąska, deser" in prompt
    assert "łatwy, średni, trudny" in prompt
    assert "g, kg, ml, l, szt" in prompt
    assert "- Marchew" in prompt and "- Mövenpick" in prompt
    assert "PO POLSKU" not in prompt
    assert "availability" in prompt


def test_legacy_prompt_is_unchanged_for_poland_and_unknown_market():
    assert "PO POLSKU" in ai._build_prompt(["Marchew"])
    assert ai._build_prompt(["Marchew"], country_code="unsupported") == ai._build_prompt(["Marchew"])


@pytest.mark.parametrize("kind", ["text", "photo", "edit"])
def test_gb_service_prompt_and_timeout_keep_existing_request_budget(monkeypatch, kind):
    call = AsyncMock(return_value=json.dumps(recipe_data()))
    monkeypatch.setattr(ai, "_call_gemini", call)
    if kind == "text":
        result = asyncio.run(ai.extract_recipe_from_text("Carrot soup", ["Marchew"], country_code="GB"))
    elif kind == "photo":
        result = asyncio.run(ai.extract_recipe_from_photo("photo", ["Marchew"], hint="Soup", country_code="GB"))
    else:
        result = asyncio.run(ai.revise_recipe_with_ai(recipe_data(), "Add herbs", ["Marchew"], country_code="GB"))
    assert result["name"] == "Carrot soup"
    assert result["meal_type"] == "obiad" and result["ingredients"][0]["unit"] == "g"
    assert call.await_count == 1
    prompt = next(part["text"] for part in call.await_args.args[0] if "text" in part)
    assert "British English" in prompt
    assert call.await_args.kwargs["country_code"] == "GB"
    if kind == "photo":
        assert call.await_args.kwargs["timeout_seconds"] == 45.0
    else:
        assert "timeout_seconds" not in call.await_args.kwargs


@pytest.mark.parametrize("raw", ["not JSON", "[]", '{"name":"Soup"}', '{"error":"No recipe was recognised."}'])
def test_invalid_gb_ai_responses_have_english_errors(raw):
    with pytest.raises(ai.AIRecipeImportError) as exc:
        ai._parse_recipe_json(raw, country_code="GB")
    assert not any(word in str(exc.value) for word in ("przepis", "ponownie", "udało"))


def test_gb_validation_missing_name_is_english():
    with pytest.raises(ai.AIRecipeImportError, match="name"):
        ai.validate_and_clean_recipe_dict({}, country_code="GB")


def test_gb_missing_api_configuration_is_english_and_does_not_request(monkeypatch):
    monkeypatch.setattr(ai.settings, "GEMINI_API_KEY", "")
    call = AsyncMock()
    monkeypatch.setattr(ai, "_call_gemini_model", call)
    with pytest.raises(ai.AIRecipeImportError, match="configured"):
        asyncio.run(ai._call_gemini([{"text": "soup"}], country_code="GB"))
    call.assert_not_awaited()


def test_gb_structured_url_retains_original_author_text_without_ai(monkeypatch):
    data = recipe_data()
    data["name"] = "Oryginalna zupa autora"
    fetch = AsyncMock(return_value=("", data))
    call = AsyncMock()
    monkeypatch.setattr(ai, "_fetch_url_text", fetch)
    monkeypatch.setattr(ai, "extract_recipe_from_text", call)
    result = asyncio.run(ai.extract_recipe_from_url("https://example.com/recipe", ["Marchew"], country_code="GB"))
    assert result["name"] == "Oryginalna zupa autora"
    assert fetch.await_args.kwargs == {"country_code": "GB"}
    call.assert_not_awaited()


def test_gb_unstructured_url_propagates_market_to_one_ai_request(monkeypatch):
    monkeypatch.setattr(ai, "_fetch_url_text", AsyncMock(return_value=("Carrot soup recipe text", None)))
    call = AsyncMock(return_value=recipe_data())
    monkeypatch.setattr(ai, "extract_recipe_from_text", call)
    asyncio.run(ai.extract_recipe_from_url("https://example.com/recipe", ["Marchew"], country_code="GB"))
    assert call.await_count == 1 and call.await_args.kwargs == {"country_code": "GB"}


def test_gb_url_uses_english_header_without_changing_safe_request_contract(monkeypatch):
    attempts = []
    async def target(url):
        return "https://93.184.216.34/recipe", {"Host": "example.com"}, {"sni_hostname": "example.com"}
    monkeypatch.setattr("app.core.safe_url.public_http_request_target", target)
    class Client:
        def __init__(self, **kwargs):
            self.options = kwargs
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            pass
        @asynccontextmanager
        async def stream(self, method, url, *, headers, **kwargs):
            attempts.append((method, url, headers, kwargs, self.options))
            yield httpx.Response(200, headers={"content-type": "text/html"}, content=b"<article>Carrot soup: boil 200 g carrots with water until tender.</article>")
    monkeypatch.setattr(httpx, "AsyncClient", Client)
    asyncio.run(ai._fetch_url_text("https://example.com/recipe", country_code="GB"))
    assert len(attempts) == 1
    method, url, headers, kwargs, options = attempts[0]
    assert headers["Accept-Language"].startswith("en-GB")
    assert headers["Host"] == "example.com" and kwargs["extensions"]["sni_hostname"] == "example.com"
    assert options["trust_env"] is False and options["timeout"] == 12.0 and options["follow_redirects"] is False


@pytest.mark.parametrize("country", ["GB", "PL"])
@pytest.mark.parametrize("kind", ["text", "photo", "url"])
def test_import_endpoint_uses_account_market_and_preserves_product_id(db, monkeypatch, country, kind):
    user = User(id=uuid4(), email=f"{uuid4()}@example.com", password_hash="test", role="admin", country_code=country)
    product = Product(id=uuid4(), name="Marchew", unit="g", review_status="approved", nutrition_per_100={"kcal": 40, "protein": 1, "fat": 1, "carbs": 8})
    db.session.add_all([user, product])
    db.session.commit()
    call = AsyncMock(return_value=recipe_data())
    monkeypatch.setattr(ai, f"extract_recipe_from_{'photo' if kind == 'photo' else kind}", call)
    photo = BytesIO()
    Image.new("RGB", (2, 2), "green").save(photo, format="JPEG")
    value = "https://example.com/recipe" if kind == "url" else base64.b64encode(photo.getvalue()).decode() if kind == "photo" else "Carrot soup"
    payload = AIRecipeImportRequest(**{"photo_base64" if kind == "photo" else kind: value})
    result = asyncio.run(recipes._create_ai_recipe(payload, user, db, skip_rate_limit=True))
    assert call.await_args.kwargs.get("country_code", "PL") == country
    assert result.ingredients[0].product_id == product.id
    assert result.ingredients[0].quantity == 200 and result.ingredients[0].unit == "g"
    assert result.visibility == "private" and result.name == "Carrot soup"


def test_gb_import_denied_before_ai_is_english(monkeypatch):
    user = SimpleNamespace(id=uuid4(), country_code="GB", role="user", is_premium=False, premium_points=0)
    call = AsyncMock()
    monkeypatch.setattr(ai, "extract_recipe_from_text", call)
    with pytest.raises(HTTPException, match="Premium") as exc:
        asyncio.run(recipes._create_ai_recipe(AIRecipeImportRequest(text="Soup"), user, SimpleNamespace(), skip_rate_limit=True))
    assert "points" in exc.value.detail
    call.assert_not_awaited()


def test_gb_edit_denied_before_ai_is_english():
    user = SimpleNamespace(id=uuid4(), country_code="GB", premium_points=0)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(recipes.edit_recipe_with_ai(uuid4(), AIRecipeEditRequest(prompt="Add carrots"), user, SimpleNamespace()))
    assert exc.value.status_code == 402 and "point" in exc.value.detail


@pytest.mark.parametrize("ready", [True, False])
def test_finished_gb_job_notification_is_english_and_clears_payload(monkeypatch, ready):
    user = SimpleNamespace(country_code="GB")
    job = SimpleNamespace(id=uuid4(), user_id=uuid4(), status="processing", payload={"text": "Soup"})
    recipe = SimpleNamespace(id=uuid4(), name="Soup") if ready else None
    db = AsyncMock()
    db.get.side_effect = [job, user]
    db.add = MagicMock()
    @asynccontextmanager
    async def session():
        yield db
    push = AsyncMock()
    monkeypatch.setattr(worker, "async_session_factory", session)
    monkeypatch.setattr(worker, "push_for_notification", push)
    asyncio.run(worker._finish_job(job.id, recipe=recipe, error=None if ready else "Please try again."))
    notification = db.add.call_args.args[0]
    assert ("ready" if ready else "Could not") in notification.message
    assert job.payload is None and job.status == ("completed" if ready else "failed")
    push.assert_awaited_once()


def test_gb_job_submission_authorization_error_is_english():
    with pytest.raises(HTTPException) as exc:
        asyncio.run(recipe_import_jobs.start_recipe_import(AIRecipeImportRequest(text="Soup", url="https://example.com"), SimpleNamespace(), SimpleNamespace(country_code="GB")))
    assert exc.value.status_code == 400 and "exactly" in exc.value.detail


@pytest.mark.parametrize("measure", ["oz", "cups", "tbsp", "tsp", "fluid ounces", "mg"])
def test_structured_recipe_does_not_treat_an_unknown_measure_as_pieces(measure):
    html = '<script type="application/ld+json">' + json.dumps({
        "@type": "Recipe", "name": "Chicken", "recipeIngredient": [f"2 {measure} chicken breast"],
        "recipeInstructions": "Cook the chicken.",
    }) + '</script>'
    assert ai._jsonld_recipe_from_soup(BeautifulSoup(html, "html.parser")) is None


@pytest.mark.parametrize("country", ["GB", "PL"])
def test_edit_receives_account_country_and_preserves_original_product_id(db, monkeypatch, country):
    user = User(id=uuid4(), email=f"{uuid4()}@example.com", password_hash="test", role="admin", country_code=country, premium_points=3)
    product = Product(id=uuid4(), name="Marchew", unit="g", review_status="approved", nutrition_per_100={"kcal": 40, "protein": 1, "fat": 1, "carbs": 8})
    recipe = Recipe(id=uuid4(), name="Original soup", meal_type="obiad", difficulty="łatwy", servings=2, instructions=["Original instruction."], created_by_user_id=user.id, visibility="private")
    db.session.add_all([user, product, recipe])
    db.session.flush()
    db.session.add(RecipeIngredient(id=uuid4(), recipe_id=recipe.id, product_id=product.id, quantity=100, unit="g", is_optional=False))
    db.session.commit()
    call = AsyncMock(return_value=recipe_data())
    monkeypatch.setattr(ai, "revise_recipe_with_ai", call)
    # The endpoint imports the limiter locally, so patch its defining module.
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    async def spend(session, user_id, amount):
        assert amount == 1 and user_id == user.id
        user.premium_points -= amount
    monkeypatch.setattr("app.services.premium_points.spend_points", spend)
    # Adapter method matches the async session's add_all; no production change.
    db.add_all = db.session.add_all
    result = asyncio.run(recipes.edit_recipe_with_ai(recipe.id, AIRecipeEditRequest(prompt="Increase carrots"), user, db))
    assert call.await_args.kwargs.get("country_code", "PL") == country
    assert call.await_args.args[0]["name"] == "Original soup"
    assert result.ingredients[0].product_id == product.id
    assert result.ingredients[0].quantity == 200 and result.ingredients[0].unit == "g"
    assert user.premium_points == 2


@pytest.mark.parametrize("country", ["GB", "PL"])
def test_background_worker_reloads_account_country_not_payload_country(monkeypatch, country):
    job_id, user_id = uuid4(), uuid4()
    user = SimpleNamespace(id=user_id, country_code=country, is_banned=False, is_email_verified=True)
    job = SimpleNamespace(user_id=user_id, payload={"text": "Soup", "country_code": "PL" if country == "GB" else "GB"})
    db = AsyncMock()
    claimed, absent = MagicMock(), MagicMock()
    claimed.scalar_one_or_none.return_value = job_id
    absent.scalar_one_or_none.return_value = None
    db.execute.side_effect = [claimed, absent]
    db.get.side_effect = [job, user]
    @asynccontextmanager
    async def session():
        yield db
    imported, finished = AsyncMock(), AsyncMock()
    monkeypatch.setattr(worker, "async_session_factory", session)
    monkeypatch.setattr(worker, "_finish_job", finished)
    monkeypatch.setattr(recipes, "_create_ai_recipe", imported)
    asyncio.run(worker._process_recipe_import(job_id))
    assert imported.await_args.args[1] is user
    assert imported.await_args.args[1].country_code == country
    assert "country_code" not in imported.await_args.args[0].model_dump()
    assert imported.await_args.kwargs == {"import_job_id": job_id, "skip_rate_limit": True}
    assert finished.await_args.kwargs["recipe"] is imported.return_value


@pytest.mark.parametrize("kind", ["import", "edit"])
def test_gb_ai_rate_limit_retains_status_and_retry_header(monkeypatch, kind):
    call = MagicMock(side_effect=HTTPException(status_code=429, detail="Zbyt wiele zapytań", headers={"Retry-After": "60"}))
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", call)
    user = SimpleNamespace(id=uuid4(), country_code="GB", role="user", is_premium=False, premium_points=2)
    with pytest.raises(HTTPException) as exc:
        if kind == "import":
            asyncio.run(recipes._create_ai_recipe(AIRecipeImportRequest(text="Soup"), user, SimpleNamespace()))
        else:
            asyncio.run(recipes.edit_recipe_with_ai(uuid4(), AIRecipeEditRequest(prompt="Add herbs"), user, SimpleNamespace()))
    assert exc.value.status_code == 429 and exc.value.headers == {"Retry-After": "60"}
    assert "Too many" in exc.value.detail
    call.assert_called_once()


@pytest.mark.parametrize("reason, expected", [
    ("quota_exhausted", "daily"), ("rate_limited", "minute"),
    ("timeout", "in time"), ("overloaded", "unavailable"),
])
def test_gb_ai_unavailable_models_have_english_errors_and_same_attempt_count(monkeypatch, reason, expected):
    attempted = []
    async def model(parts, name, *, timeout_seconds, country_code):
        attempted.append((name, timeout_seconds, country_code))
        raise ai._ModelUnavailableError("Unavailable", reason=reason)
    monkeypatch.setattr(ai.settings, "GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(ai, "GEMINI_MODELS", ["first", "second"])
    monkeypatch.setattr(ai, "_call_gemini_model", model)
    monkeypatch.setattr(ai, "_model_unavailable_until", {})
    with pytest.raises(ai.AIRecipeImportError) as exc:
        asyncio.run(ai._call_gemini([{"text": "soup"}], country_code="GB"))
    assert expected in str(exc.value)
    assert [item[0] for item in attempted] == ["first", "second"]
    assert all(item[1] <= 35 and item[2] == "GB" for item in attempted)
