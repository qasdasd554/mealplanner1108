"""Do not turn cooking ingredients into a similarly named ready-made meal."""

from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import select, func

from app.models import ShoppingList, User, Store, Product, StoreProduct, Recipe, RecipeIngredient
from decimal import Decimal
from uuid import uuid4
from app.services.ai_recipe_import import match_product_name, _build_prompt
from tests.test_regional_shopping import db, run, make_plan, ShoppingListBuilder


@pytest.mark.parametrize("country,recipe_name,product_name", [
    ("PL", "Schab wieprzowy w marynacie z ziemniakami", "Schab wieprzowy w marynacie"),
    ("GB", "Chicken breast in lemon marinade with potatoes", "Chicken breast in lemon marinade"),
])
@pytest.mark.parametrize("action", ["build", "from_recipes", "recalculate"])
def test_shopping_copies_declared_ingredient_without_title_heuristics(db, country, recipe_name, product_name, action):
    from app.api.v1.shopping_lists import create_shopping_list_from_recipes, ShoppingListFromRecipesRequest
    from app.schemas.shopping_list import ShoppingListResponse
    from tests.test_regional_shopping import loaded, UK_STORES
    session, adapter, user, product, _ = db
    if country == "PL":
        user = User(id=uuid4(), email="pl-integrity@example.test", password_hash="fixture", role="admin", country_code="PL")
        session.add(user)
        for store in session.scalars(select(Store)).all():
            store.country_code, store.currency_code = "PL", "PLN"
    product.name = product_name
    plan = make_plan(session, user, product, quantity="400")
    plan.entries[0].recipe.name = recipe_name
    session.commit()
    if action == "from_recipes":
        shopping = run(create_shopping_list_from_recipes(
            ShoppingListFromRecipesRequest(recipe_ids=[plan.entries[0].recipe_id], store_id=UK_STORES[0].id),
            user, adapter,
        ))
    else:
        shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
        if action == "recalculate":
            shopping = run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    response = ShoppingListResponse.model_validate(loaded(session, shopping.id))
    rows = [row for group in response.items_by_department.values() for row in group]
    assert len(rows) == 1
    # GB can display the reviewed retailer label, but identity and amount
    # must still be the selected recipe ingredient, never a title match.
    assert rows[0].product_id == product.id if country == "GB" else rows[0].product_name == product_name
    assert rows[0].required_quantity == 400 and rows[0].unit == "g"
    assert plan.entries[0].recipe.ingredients[0].product_id == product.id


def test_fuzzy_match_cannot_replace_raw_meat_with_prepared_breaded_meat():
    assert match_product_name("Chicken breast", ["Chicken breast ready meal"]) is None
    assert match_product_name("Schab wieprzowy", ["Schab wieprzowy panierowany gotowy"]) is None


@pytest.mark.parametrize("raw,prepared", [
    ("Chicken breast", "Chicken breast in sauce"),
    ("Schab wieprzowy", "Schab wieprzowy w sosie"),
    ("Rice", "Rice with veg"),
])
def test_similar_catalogue_name_cannot_change_a_raw_ai_ingredient_into_a_dish(raw, prepared):
    assert match_product_name(raw, [prepared]) is None
    # A deliberately supplied exact ingredient remains exact (e.g. a sauce
    # or prepared component explicitly used by the recipe author).
    assert match_product_name(prepared, [prepared]) == prepared


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_ai_catalogue_does_not_recommend_whole_meals_for_scratch_cooking(country):
    prompt = _build_prompt(["Schab wieprzowy", "Pork loin", "Kotlet schabowy z buraczkami i puree", "Pork schnitzel with mash ready meal"], country_code=country)
    assert "- Schab wieprzowy" in prompt and "- Pork loin" in prompt
    assert "- Kotlet schabowy z buraczkami i puree" not in prompt
    assert "- Pork schnitzel with mash ready meal" not in prompt


def test_guard_preserves_real_ingredients_and_explicit_ready_components():
    from app.services.recipe_ingredient_integrity import validate_recipe_ingredients
    for title, names in [
        ("Kotlet schabowy z ziemniakami", ["Schab wieprzowy", "Ziemniaki", "Bułka tarta"]),
        ("Pork schnitzel with mash", ["Pork loin", "Potatoes", "Breadcrumbs"]),
        ("Tuna salad", ["Tinned tuna", "Mayonnaise"]),
        ("Pasta with pesto", ["Pasta", "Pesto"]),
        ("Chicken wraps", ["Ready cooked chicken", "Tortilla wraps"]),
        ("Brown rice", ["Brown rice", "Water"]),
    ]:
        recipe = SimpleNamespace(name=title, ingredients=[SimpleNamespace(product=SimpleNamespace(name=name)) for name in names])
        validate_recipe_ingredients(recipe)


def test_all_official_recipe_ingredients_pass_without_replacing_with_meals():
    from app.db.seed import RECIPES_DATA
    from app.services.recipe_ingredient_integrity import validate_ingredient_names
    for recipe in RECIPES_DATA:
        validate_ingredient_names(recipe["name"], [name for name, *_ in recipe["ingredients"]])


@pytest.mark.parametrize("title,product", [
    ("Schabowy w mlecznej marynacie z młodą kapustą i puree ziemniaczanym", "Kotlet schabowy z buraczkami i puree"),
    ("Chicken tikka masala", "Chicken tikka masala ready meal"),
    ("Turkey with vegetables and rice", "Turkey with vegetables and rice"),
    ("Indyk z kaszą i warzywami", "Indyk z puree ziemniaczanym i marchewką"),
    ("Fish and chips", "Fish and chips ready meal"),
])
def test_whole_dish_detection_is_not_limited_to_a_single_recipe_family(title, product):
    from app.services.recipe_ingredient_integrity import validate_ingredient_names
    with pytest.raises(HTTPException):
        validate_ingredient_names(title, [product])


@pytest.mark.parametrize("title,product", [
    ("Curry with rice", "Curry paste with ginger"),
    ("Curry z ryżem", "Pasta curry z imbirem"),
    ("Bread with ham", "Wholegrain bread with seeds"),
    ("Chicken with rice", "Chicken breast with skin"),
])
def test_prepared_components_are_not_confused_with_the_whole_recipe(title, product):
    from app.services.recipe_ingredient_integrity import validate_ingredient_names
    validate_ingredient_names(title, [product])


@pytest.mark.parametrize("country,title,prepared", [
    ("PL", "Domowy obiad z marynaty", "Kotlet schabowy z buraczkami i puree"),
    ("GB", "Sunday lunch", "Pork schnitzel with mash ready meal"),
])
def test_ai_cannot_hide_an_entire_meal_under_a_different_recipe_title(country, title, prepared):
    from app.services.ai_recipe_import import validate_and_clean_recipe_dict, AIRecipeImportError
    parsed = dict(name=title, ingredients=[dict(product_name=prepared, quantity=400, unit="g")])
    with pytest.raises(AIRecipeImportError):
        validate_and_clean_recipe_dict(parsed, country_code=country)


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("source", ["text", "photo", "url"])
def test_ai_source_never_saves_a_meal_as_an_ingredient_or_spends_points(db, monkeypatch, country, source):
    from unittest.mock import AsyncMock
    from app.api.v1.recipes import _create_ai_recipe
    from app.schemas.recipe import AIRecipeImportRequest
    from app.services import ai_recipe_import
    session, adapter, _, product, _ = db
    product.name = "Kotlet schabowy z buraczkami i puree" if country == "PL" else "Pork schnitzel with mash ready meal"
    product.nutrition_per_100 = {"kcal": 119, "protein": 15, "fat": 5, "carbs": 3}
    user = User(id=uuid4(), email=f"{source}-{country}@example.test", password_hash="fixture", country_code=country, premium_points=3, role="user")
    session.add(user)
    session.commit()
    parsed = dict(name="Domowy obiad" if country == "PL" else "Sunday lunch", meal_type="obiad", servings=4,
                  ingredients=[dict(product_name=product.name, quantity=4, unit="szt")], instructions=["Prepare the ingredients."])
    extract = AsyncMock(return_value=parsed)
    monkeypatch.setattr(ai_recipe_import, f"extract_recipe_from_{source}", extract)
    spend = AsyncMock()
    monkeypatch.setattr("app.services.premium_points.spend_points", spend)
    count = session.scalar(select(func.count()).select_from(Recipe))
    import base64
    from io import BytesIO
    from PIL import Image
    photo = BytesIO()
    Image.new("RGB", (2, 2), "green").save(photo, format="JPEG")
    payload = AIRecipeImportRequest(**{dict(text="text", photo="photo_base64", url="url")[source]:
                                       "https://example.test/recipe" if source == "url" else base64.b64encode(photo.getvalue()).decode() if source == "photo" else "synthetic-input"})
    with pytest.raises(HTTPException) as error:
        run(_create_ai_recipe(payload, user, adapter, skip_rate_limit=True))
    assert error.value.status_code == 422
    assert product.name not in extract.await_args.args[1]
    spend.assert_not_awaited()
    assert user.premium_points == 3
    assert session.scalar(select(func.count()).select_from(Recipe)) == count


@pytest.mark.parametrize("ingredient", ["Tuna in spring water", "Pomidory w puszce", "Tuna in its own juice", "Tuńczyk w sosie własnym"])
def test_canned_cooking_components_are_not_complete_ready_meals(ingredient):
    from app.services.recipe_ingredient_integrity import looks_like_whole_meal, validate_ingredient_names
    assert not looks_like_whole_meal(ingredient)
    validate_ingredient_names("Lunch", [ingredient])


@pytest.mark.parametrize("ingredient", ["Pierś z kurczaka", "Filet z indyka", "Filet z dorsza", "Sok z cytryny", "Mąka z ciecierzycy", "Bułka tarta", "Masło"])
def test_real_cooking_ingredients_remain_in_ai_catalogue_and_validation(ingredient):
    from app.services.ai_recipe_import import _select_prompt_products
    from app.services.recipe_ingredient_integrity import validate_ingredient_names
    assert _select_prompt_products([ingredient], None) == [ingredient]
    validate_ingredient_names("Obiad", [ingredient])


@pytest.mark.parametrize("country", ["PL", "GB"])
def test_missing_nutrition_preserves_complete_recipe_with_private_unverified_ingredient(db, monkeypatch, country):
    from unittest.mock import AsyncMock
    monkeypatch.setattr("app.services.barcode_lookup.search_products_external", AsyncMock(return_value=[]))
    from app.api.v1.recipes import _create_ai_recipe
    from app.schemas.recipe import AIRecipeImportRequest
    from app.models import Recipe
    from app.services import ai_recipe_import
    session, adapter, _, product, _ = db
    user = User(id=uuid4(), email=f"{country}-incomplete@example.test", password_hash="fixture",
                country_code=country, premium_points=3, role="user")
    product.nutrition_per_100 = {"kcal": 100, "protein": 5, "fat": 4, "carbs": 11}
    session.add(user)
    session.commit()
    parsed = dict(name="Vegetable soup", meal_type="obiad", difficulty="łatwy", servings=1,
                  instructions=["Cook the vegetables."], ingredients=[
                      dict(product_name=product.name, quantity=100, unit="g"),
                      dict(product_name="A missing real ingredient", quantity=200, unit="g"),
                  ])
    monkeypatch.setattr(ai_recipe_import, "extract_recipe_from_text", AsyncMock(return_value=parsed))
    spend = AsyncMock()
    monkeypatch.setattr("app.services.premium_points.spend_points", spend)
    before = session.scalar(select(func.count()).select_from(Recipe))
    created = run(_create_ai_recipe(AIRecipeImportRequest(text="Vegetable soup"), user, adapter, skip_rate_limit=True))
    assert len(created.ingredients) == 2
    unknown = next(i for i in created.ingredients if i.product.name == "A missing real ingredient")
    assert unknown.quantity == 200 and unknown.unit == "g"
    assert unknown.product.review_status == "pending" and unknown.product.created_by_user_id == user.id
    assert created.nutrition_total["kcal"] is None
    spend.assert_awaited_once_with(adapter, user.id, 2)
    assert user.premium_points == 3
    assert session.scalar(select(func.count()).select_from(Recipe)) == before + 1


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("bad", [None,
    {"product_name": "Flour", "quantity": 2, "unit": "cup"},
    {"product_name": "Flour", "quantity": float("inf"), "unit": "g"},
    {"product_name": "Flour", "quantity": 0, "unit": "g"},
])
def test_required_ingredients_cannot_disappear_in_ai_cleaning(country, bad):
    from app.services.ai_recipe_import import validate_and_clean_recipe_dict, AIRecipeImportError
    parsed = dict(name="Soup", ingredients=[dict(product_name="Carrots", quantity=100, unit="g"), bad])
    with pytest.raises(AIRecipeImportError):
        validate_and_clean_recipe_dict(parsed, country_code=country)


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("action", ["build", "from_recipes", "append", "recalculate"])
def test_basket_is_exact_recipe_ingredients_even_when_cheap_ready_meal_exists(db, country, action):
    from app.api.v1.shopping_lists import create_shopping_list_from_recipes, ShoppingListFromRecipesRequest
    from app.models import MealPlanEntry
    from app.services.uk_catalogue_import import import_reviewed_uk_catalogue
    from tests.test_regional_shopping import _offer, loaded, UK_STORES
    from datetime import datetime, timezone
    session, adapter, user, _, _ = db
    if country == "PL":
        user = User(id=uuid4(), email="raw-basket@example.test", password_hash="fixture", role="admin", country_code="PL")
        session.add(user)
        for store in session.scalars(select(Store)).all():
            store.country_code, store.currency_code = "PL", "PLN"
    raw = [Product(id=uuid4(), name=name, unit="g", default_quantity=500, review_status="approved")
           for name in ["Pork loin", "Potatoes", "Eggs", "Breadcrumbs"]]
    prepared = Product(id=uuid4(), name="Pork schnitzel with mash ready meal", unit="g", default_quantity=400, review_status="approved")
    session.add_all([*raw, prepared])
    session.flush()
    if country == "PL":
        for product in [*raw, prepared]:
            session.add(StoreProduct(id=uuid4(), store_id=UK_STORES[0].id, product_id=product.id,
                                     price=Decimal("0.01") if product is prepared else Decimal("5"), is_available=True))
    else:
        records = []
        for index, product in enumerate([*raw, prepared]):
            row = _offer(product.id, "tesco", f"raw-basket-{index}", "500", "0.01" if product is prepared else "5")
            row["name_en"] = product.name
            records.append(row)
        run(import_reviewed_uk_catalogue(adapter, records, reviewer_user_id=user.id,
            reviewed_at=datetime.now(timezone.utc), as_of=datetime.now(timezone.utc).date()))
    plan = make_plan(session, user, raw[0], quantity="400", include_pantry=False)
    recipe = plan.entries[0].recipe
    recipe.name = "Pork schnitzel with mash"
    for product, amount in zip(raw[1:], [500, 100, 80]):
        recipe.ingredients.append(RecipeIngredient(id=uuid4(), product_id=product.id, quantity=amount, unit="g"))
    session.commit()
    if action == "from_recipes":
        shopping = run(create_shopping_list_from_recipes(
            ShoppingListFromRecipesRequest(recipe_ids=[recipe.id], store_id=UK_STORES[0].id), user, adapter,
        ))
    else:
        shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id, include_pantry=False))
        if action == "append":
            shopping = run(create_shopping_list_from_recipes(
                ShoppingListFromRecipesRequest(recipe_ids=[recipe.id], store_id=UK_STORES[0].id, existing_list_id=shopping.meal_plan_id),
                user, adapter,
            ))
        elif action == "recalculate":
            shopping = run(ShoppingListBuilder(adapter).recalculate(shopping.id))
    rows = loaded(session, shopping.id).items
    actual = {
        item.regional_snapshot.product_id if item.regional_snapshot else item.store_product.product_id:
        item.required_quantity for item in rows
    }
    multiplier = 2 if action == "append" else 1
    assert actual == {product.id: amount * multiplier for product, amount in zip(raw, [400, 500, 100, 80])}
    assert prepared.id not in actual
