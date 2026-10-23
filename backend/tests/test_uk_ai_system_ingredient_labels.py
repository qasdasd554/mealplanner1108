"""English seed labels are the same ingredient identity, not a UK stock claim."""

import base64
from datetime import datetime, timezone
from io import BytesIO
import json
from pathlib import Path
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from PIL import Image
from sqlalchemy import func, select

from app.api.v1 import recipes
from app.models import Product, Recipe, RecipeIngredient, User
from app.schemas.recipe import AIRecipeEditRequest, AIRecipeImportRequest
from app.services import ai_recipe_import, barcode_lookup, system_content_language
from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients
from app.services.off_availability import off_available_product_ids
from tests.test_regional_shopping import db, run


INDEX = json.loads((Path(__file__).resolve().parents[1] /
    "app/data/system_content_index.json").read_text(encoding="utf-8"))["ingredients"]


def seed_product(english="Potatoes"):
    identity, row = next((key, row) for key, row in INDEX.items() if row["en_GB"] == english)
    return Product(id=UUID(identity), name=row["source"], unit="g", review_status="approved",
        nutrition_per_100={"kcal": 77, "protein": 2, "fat": 0.1, "carbs": 17})


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("english", ["Potatoes", "Onion", "Breadcrumbs"])
async def test_translated_system_ingredient_uses_existing_identity_without_external_lookup(monkeypatch, country, english):
    product = seed_product(english)
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    ingredient = dict(product_name=english if country == "GB" else product.name, quantity=120, unit="g")
    pairs = await resolve_recipe_ingredients([ingredient], [product], country=country, user_id=uuid4())
    assert pairs[0][1] is product
    assert pairs[0][0] is ingredient
    search.assert_not_awaited()


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("changed", ["none", "identity", "name", "owner"])
def test_ingredient_label_requires_exact_system_identity_and_unchanged_name(country, changed):
    product = seed_product()
    if changed == "identity": product.id = uuid4()
    if changed == "name": product.name = "Changed canonical ingredient"
    if changed == "owner": product.created_by_user_id = uuid4()
    actual = system_content_language.ingredient_display_name(product, country_code=country)
    assert actual == ("Potatoes" if country == "GB" and changed == "none" else product.name)


@pytest.mark.asyncio
async def test_existing_english_product_has_priority_over_translated_alias(monkeypatch):
    original = seed_product()
    authored = Product(id=uuid4(), name="Potatoes", created_by_user_id=uuid4(), unit="g",
        nutrition_per_100=dict(original.nutrition_per_100))
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    pairs = await resolve_recipe_ingredients([dict(product_name="Potatoes", quantity=100, unit="g")],
        [original, authored], country="GB", user_id=authored.created_by_user_id)
    assert pairs[0][1] is authored
    search.assert_not_awaited()


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("source", ["text", "photo", "url"])
def test_ai_import_passes_account_language_labels_and_does_not_duplicate_seed(db, monkeypatch, country, source):
    session, adapter, account, _, _ = db
    if country == "PL":
        account = User(id=uuid4(), email="pl-seed-label@example.invalid", password_hash="fixture",
            country_code=country, role="admin", is_premium=True)
        session.add(account)
    product = seed_product()
    session.add(product); session.commit()
    name = "Potatoes" if country == "GB" else product.name
    raw = dict(name="Example", servings=2, meal_type="obiad", instructions=["Cook."],
        ingredients=[dict(product_name=name, quantity=120, unit="g")])
    provider = AsyncMock(return_value=raw)
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(ai_recipe_import, f"extract_recipe_from_{source}", provider)
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    before = session.scalar(select(func.count()).select_from(Product))
    image = BytesIO()
    Image.new("RGB", (2, 2), "green").save(image, format="JPEG")
    payload = AIRecipeImportRequest(**{dict(text="text", photo="photo_base64", url="url")[source]:
        base64.b64encode(image.getvalue()).decode() if source == "photo" else
        "https://example.test/recipe" if source == "url" else "Example"})
    created = run(recipes._create_ai_recipe(payload, account, adapter, skip_rate_limit=True))
    assert name in provider.call_args.args[1]
    if country == "GB": assert product.name not in provider.call_args.args[1]
    assert created.ingredients[0].product_id == product.id
    assert created.ingredients[0].quantity == 120
    assert created.nutrition_total["kcal"] == pytest.approx(92.4)
    assert session.scalar(select(func.count()).select_from(Product)) == before
    assert product.name == INDEX[str(product.id)]["source"]
    # A translated label does not manufacture a UK availability record.
    assert run(off_available_product_ids(adapter, [product.id], as_of=datetime.now(timezone.utc).date())) == set()
    search.assert_not_awaited()


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_all_reviewed_system_ingredient_labels_keep_the_same_ids(country):
    for identity, row in INDEX.items():
        product = Product(id=UUID(identity), name=row["source"], created_by_user_id=None)
        assert system_content_language.ingredient_display_name(product, country_code=country) == (
            row["en_GB"] if country == "GB" else row["source"])
        assert product.id == UUID(identity) and product.name == row["source"]


def test_english_ai_edit_with_no_actual_change_does_not_charge_or_create_product(db, monkeypatch):
    session, adapter, account, _, _ = db
    account.premium_points = 3
    product = seed_product()
    recipe = Recipe(id=uuid4(), name="Example", meal_type="obiad", servings=2,
        difficulty="łatwy", visibility="private", created_by_user_id=account.id,
        instructions=["Original step."])
    session.add_all([product, recipe]); session.flush()
    session.add(RecipeIngredient(id=uuid4(), recipe_id=recipe.id, product_id=product.id,
        quantity=120, unit="g", is_optional=False)); session.commit()
    async def unchanged(snapshot, instruction, names, **kwargs):
        assert "Potatoes" in names and product.name not in names
        return {**snapshot, "ingredients": [dict(product_name="Potatoes", quantity=120, unit="g")]}
    monkeypatch.setattr(ai_recipe_import, "revise_recipe_with_ai", AsyncMock(side_effect=unchanged))
    search, spend = AsyncMock(return_value=[]), AsyncMock()
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    monkeypatch.setattr("app.services.premium_points.spend_points", spend)
    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    async def rollback(): session.rollback()
    adapter.rollback = rollback
    with pytest.raises(HTTPException) as failure:
        run(recipes.edit_recipe_with_ai(recipe.id, AIRecipeEditRequest(prompt="Keep everything"), account, adapter))
    assert failure.value.status_code == 422
    assert failure.value.detail == "AI made no changes. No point was charged."
    spend.assert_not_awaited()
    search.assert_not_awaited()
