"""Synthetic nutrition recovery; no live OFF, USDA or AI calls."""

from types import SimpleNamespace
import json
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.models import Product, Recipe, RecipeIngredient, RecipeTag, Store
from app.schemas.meal_plan import MealPlanResponse
from app.services import ai_recipe_import
from app.services import ingredient_nutrition_estimate as fallback
from app.services.meal_plan_generator import MealPlanGenerator
from app.services.nutrition_calculator import compute_recipe_nutrition_total
from app.services.recipe_ingredient_integrity import looks_like_whole_meal
from tests.test_regional_shopping import db, run


def _estimate(**overrides):
    row = {"id": 0, "basis_unit": "ml", "confidence": .9,
           "nutrition": {"kcal": 828, "protein": 0, "fat": 92, "carbs": 0}}
    row.update(overrides)
    return row


@pytest.mark.parametrize("bad", [None, "zero", "wrong-unit", "negative", "infinite", "energy", "confidence", "boolean", "wrong-id"])
def test_estimate_is_bounded_validated_and_never_invents_a_source(monkeypatch, bad):
    monkeypatch.setattr(fallback.settings, "GEMINI_API_KEY", "synthetic-test-key")
    monkeypatch.setattr(fallback.settings, "USDA_FDC_API_KEY", "")
    row = _estimate()
    if bad == "zero": row["nutrition"] = dict(kcal=0, protein=0, fat=0, carbs=0)
    if bad == "wrong-unit": row["basis_unit"] = "g"
    if bad == "negative": row["nutrition"]["fat"] = -1
    if bad == "infinite": row["nutrition"]["kcal"] = float("inf")
    if bad == "energy": row["nutrition"]["kcal"] = 0
    if bad == "confidence": row["confidence"] = .4
    if bad == "boolean": row["nutrition"]["carbs"] = True
    if bad == "wrong-id": row["id"] = 2
    row["source_url"] = "https://fake-source.example.test"
    call = AsyncMock(return_value=json.dumps({"ingredients": [row]}))
    monkeypatch.setattr(ai_recipe_import, "_call_gemini", call)
    result = run(fallback.estimate_missing_ingredients([
        {"product_name": "Olej roślinny", "quantity": 30, "unit": "ml"}], country="PL"))
    call.assert_awaited_once()
    assert call.await_args.kwargs["max_total_seconds"] == 9
    if bad:
        assert result == {}
    else:
        assert result["olej roslinny"]["nutrition"]["kcal"] == 828
        assert result["olej roslinny"]["source"]["status"] == "estimated"
        assert "url" not in result["olej roslinny"]["source"]


def test_optional_ai_failure_and_unknown_piece_weight_do_not_fail_recipe(monkeypatch):
    monkeypatch.setattr(fallback.settings, "GEMINI_API_KEY", "synthetic-test-key")
    call = AsyncMock(side_effect=ai_recipe_import.AIRecipeImportError("synthetic unavailable"))
    monkeypatch.setattr(ai_recipe_import, "_call_gemini", call)
    ingredient = dict(product_name="Unfamiliar ingredient", quantity=1, unit="szt")
    assert run(fallback.estimate_missing_ingredients([ingredient], country="GB")) == {}
    call.assert_not_awaited()
    ingredient["unit"] = "g"
    assert run(fallback.estimate_missing_ingredients([ingredient], country="GB")) == {}
    call.assert_awaited_once()


def test_short_optional_estimate_timeout_does_not_disable_recipe_generation(monkeypatch):
    monkeypatch.setattr(fallback.settings, "GEMINI_API_KEY", "synthetic-test-key")
    monkeypatch.setattr(ai_recipe_import, "GEMINI_MODELS", ["synthetic-model"])
    availability = {}
    monkeypatch.setattr(ai_recipe_import, "_model_unavailable_until", availability)
    monkeypatch.setattr(ai_recipe_import, "_call_gemini_model", AsyncMock(
        side_effect=ai_recipe_import._ModelUnavailableError("synthetic timeout", reason="timeout")))
    assert run(fallback.estimate_missing_ingredients([
        dict(product_name="Vegetable oil", quantity=30, unit="ml")], country="GB")) == {}
    assert availability == {}  # ordinary recipe generation may still use this model


def test_usda_generic_uses_real_exact_unbranded_evidence_only(monkeypatch):
    import httpx
    monkeypatch.setattr(fallback.settings, "USDA_FDC_API_KEY", "synthetic-usda-key")
    class Client:
        def __init__(self, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def post(self, url, **kwargs):
            assert url == "https://api.nal.usda.gov/fdc/v1/foods/search"
            assert kwargs["json"]["dataType"] == ["Foundation", "SR Legacy"]
            return httpx.Response(200, request=httpx.Request("POST", url), json={"foods": [
                {"description": "Oil soybean", "dataType": "Branded", "fdcId": 111},
                {"description": "Oil soybean", "dataType": "SR Legacy", "fdcId": 222,
                 "foodNutrients": [{"nutrientId": key, "value": value} for key, value in
                    ((1008, 884), (1003, 0), (1004, 100), (1005, 0))]}]})
    monkeypatch.setattr(fallback.httpx, "AsyncClient", Client)
    nutrition, url = run(fallback._usda_generic("Oil, soybean"))
    assert nutrition["kcal"] == 884 and "/222/" in url
    assert run(fallback._usda_generic("Oil olive")) is None


@pytest.mark.parametrize("raw", [{}, {"kcal": None}, {"kcal": float("nan")}, {"kcal": -10}])
def test_invalid_legacy_nutrition_is_missing_not_zero(raw):
    total = compute_recipe_nutrition_total([SimpleNamespace(product=Product(name="Food", nutrition_per_100=raw),
        quantity=100, unit="g")])
    assert total["kcal"] is None and total["_incomplete"] is True


def test_missing_oil_uses_private_estimate_without_losing_known_macros(db, monkeypatch):
    from app.api.v1.recipes import _create_ai_recipe
    from app.schemas.recipe import AIRecipeImportRequest
    from app.services import barcode_lookup
    session, adapter, user, product, _ = db
    product.name = "Chicken breast"
    product.nutrition_per_100 = dict(kcal=120, protein=22, fat=3, carbs=0)
    session.commit()
    monkeypatch.setattr(fallback.settings, "GEMINI_API_KEY", "synthetic-test-key")
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value={
        "name": "Chicken", "servings": 4, "instructions": ["Cook the chicken in oil."],
        "ingredients": [dict(product_name="Chicken breast", quantity=600, unit="g"),
                        dict(product_name="Vegetable oil", quantity=30, unit="ml")]}))
    search = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", search)
    call = AsyncMock(return_value=json.dumps({"ingredients": [_estimate()]}))
    monkeypatch.setattr(ai_recipe_import, "_call_gemini", call)
    recipe = run(_create_ai_recipe(AIRecipeImportRequest(text="Chicken"), user, adapter, skip_rate_limit=True))
    oil = next(ingredient.product for ingredient in recipe.ingredients if ingredient.product.name == "Vegetable oil")
    assert recipe.nutrition_total["kcal"] == pytest.approx(968.4)
    assert recipe.nutrition_total["_estimated"] is True
    assert recipe.nutrition_total["_estimated_ingredients"] == ["Vegetable oil"]
    assert oil.created_by_user_id == user.id and oil.review_status == "pending"
    assert oil.barcode is None and oil.serving_quantity is None
    from app.schemas.recipe import RecipeResponse
    response = RecipeResponse.model_validate(recipe)
    assert response.ingredients[1].nutrition_estimated is True
    assert response.ingredients[1].kcal == 248
    run(_create_ai_recipe(AIRecipeImportRequest(text="Chicken"), user, adapter, skip_rate_limit=True))
    assert call.await_count == search.await_count == 1


def test_missing_one_ingredient_keeps_known_subtotal_not_fake_zero():
    known = SimpleNamespace(product=Product(name="Chicken", nutrition_per_100={
        "kcal": 120, "protein": 22, "fat": 3, "carbs": 0}), quantity=600, unit="g")
    missing = SimpleNamespace(product=Product(name="Vegetable oil", nutrition_per_100={
        "_source": {"status": "missing"}}), quantity=30, unit="ml")
    total = compute_recipe_nutrition_total([known, missing])
    assert total["kcal"] is None and total["_incomplete"] is True
    assert total["_known_totals"]["kcal"] == 720
    assert total["_known_totals"]["protein"] == 132


@pytest.mark.parametrize("name", ["Cordon Bleu Szynka & Ser", "Cordon bleu ham and cheese", "Chicken cordon bleu"])
def test_ready_cordon_bleu_is_never_an_ingredient_candidate(name):
    assert looks_like_whole_meal(name)
    assert ai_recipe_import.match_product_name("Szynka", [name]) is None
    assert ai_recipe_import.match_product_name("Ser", [name]) is None
    assert name not in ai_recipe_import._select_prompt_products([name, "Szynka", "Ser"], "Cordon bleu")


@pytest.mark.parametrize("requested,candidate", [
    ("Ham", "Ham cheese"), ("Ham", "Ham bake"),
    ("Ser żółty", "Ser żółty zapiekany"),
    ("Schab wieprzowy", "Schab wieprzowy gotowy"),
    ("Chicken", "Chicken pie"), ("Rice", "Rice pudding"),
    ("Masło", "Masło z truflami"), ("Mleko 2%", "Mleko 3.2%"),
])
def test_no_spelling_score_can_change_ingredient_identity(requested, candidate):
    assert ai_recipe_import.match_product_name(requested, [candidate]) is None


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_arbitrary_catalogue_meals_never_guide_recipe_generation(country):
    import json
    from pathlib import Path
    from uuid import UUID
    from app.services.recipe_ingredient_catalogue import recipe_prompt_ingredient_names
    index = json.loads((Path(__file__).resolve().parents[1] / "app/data/system_content_index.json").read_text(encoding="utf-8"))["ingredients"]
    identifier, known = next(iter(index.items()))
    ordinary = Product(id=UUID(identifier), name=known["source"], review_status="approved", created_by_user_id=None)
    # Deliberately includes names no prepared-food blacklist recognises.
    names = ["Restaurant special 42", "Krokiet z mięsem", "Sernik na zimno", "Cordon Bleu Szynka & Ser",
             "Lunchbox ABC", "Plain looking retail item", known["source"]]
    retail = [Product(id=uuid4(), name=name, review_status="approved") for name in names]
    assert recipe_prompt_ingredient_names([ordinary, *retail], country=country) == [
        known["en_GB"] if country == "GB" else known["source"]]


def test_generated_plan_response_needs_no_lazy_io_after_building_list(db, monkeypatch):
    session, adapter, user, product, _ = db
    product.nutrition_per_100 = {"kcal": 370, "protein": 12, "fat": 7, "carbs": 65}
    recipe = Recipe(id=uuid4(), name="Synthetic porridge", meal_type="obiad", servings=1,
        instructions=["Cook."], nutrition_total={"kcal": 370, "protein": 12, "fat": 7, "carbs": 65})
    recipe.tags = [RecipeTag(id=uuid4(), tag="quick")]
    recipe.ingredients = [RecipeIngredient(id=uuid4(), product=product, quantity=100, unit="g", is_optional=False)]
    session.add(recipe); session.commit()
    generator = MealPlanGenerator(adapter)
    # Data selection is isolated here; the actual persistence, list builder,
    # populate_existing reload and response serializer all execute normally.
    monkeypatch.setattr(generator, "_filter_eligible_recipes", AsyncMock(return_value=[recipe]))
    plan = run(generator.generate(user.id, session.query(Store).first().id,
        duration_days=1, meals_per_day=1, preferences={"meal_types": ["obiad"]}))
    session.expunge_all()
    response = MealPlanResponse.model_validate(plan)
    assert response.entries[0].recipe.tags == ["quick"]
    assert response.entries[0].recipe.ingredients[0].product_name == product.name


def test_old_zero_totals_are_recomputed_on_read_without_mutating_recipe(db):
    from app.schemas.recipe import RecipeResponse
    session, _, _, product, _ = db
    product.nutrition_per_100 = dict(kcal=120, protein=22, fat=3, carbs=0)
    zero = dict(kcal=0, protein=0, fat=0, carbs=0)
    recipe = Recipe(id=uuid4(), name="Existing recipe", meal_type="obiad", servings=4,
        nutrition_total=zero, tags=[], ingredients=[RecipeIngredient(id=uuid4(), product=product,
            quantity=600, unit="g", is_optional=False)])
    session.add(recipe); session.commit()
    response = RecipeResponse.model_validate(recipe)
    assert response.nutrition_total["kcal"] == 720
    assert recipe.nutrition_total == zero  # serializer is not a production migration
