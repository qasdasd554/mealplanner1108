"""Regressions from the first UK device test; never connect to a real DB."""

import asyncio
from datetime import date
from types import SimpleNamespace
from uuid import uuid4
from unittest.mock import AsyncMock

import httpx
import pytest
from sqlalchemy import select

from app.api.v1 import products, shopping_lists
from app.core.exceptions import NotFoundException
from app.models import Product, Recipe, RecipeIngredient, OffCatalogueProduct
from app.services import barcode_lookup
from app.services.market_catalog import recipe_market_availability
from app.services.meal_plan_generator import MealPlanGenerator
from tests.test_regional_shopping import db, make_plan, run, UK_STORES
from tests.test_uk_seed_off_identity import seeded_oats
from tests.test_recipe_off_refresh import reset_limits, connect_io


def test_uk_can_browse_shared_generic_food_without_a_store_or_off_import(db):
    session, adapter, user, _, _ = db
    food = seeded_oats()
    session.add(food)
    session.commit()
    rows = run(products.list_products(skip=0, limit=50, search="Oats", db=adapter, current_user=user))
    assert [row.id for row in rows] == [food.id]
    assert rows[0].name == "Oats"
    assert rows[0].brand is None and rows[0].serving_quantity is None
    assert food.name == "Płatki owsiane" and food.brand == "Sante"


def test_pinned_reviewed_starter_works_without_an_operational_import(db):
    session, adapter, user, _, _ = db
    food = seeded_oats()
    session.add(food)
    row = Recipe(id=uuid4(), name="Breakfast", meal_type="śniadanie", nutrition_total={"kcal": 389})
    row.ingredients = [RecipeIngredient(id=uuid4(), product_id=food.id, quantity=100, unit="g", is_optional=False)]
    session.add(row)
    session.commit()
    # Original OFF observations are dated 23-24 October, never today-stamped.
    query = select(Recipe.id).where(recipe_market_availability("GB", as_of=date(2026, 10, 25)))
    assert row.id in session.scalars(query).all()
    assert row.id not in session.scalars(select(Recipe.id).where(
        recipe_market_availability("GB", as_of=date(2026, 12, 1)))).all()


@pytest.mark.parametrize("own", [True, False])
def test_shopping_from_own_import_uses_saved_ingredients_without_country_stock_proof(db, own):
    session, adapter, user, _, _ = db
    food = Product(id=uuid4(), name="My cooking ingredient", unit="g", review_status="pending",
        created_by_user_id=user.id, nutrition_per_100={"kcal": 100, "protein": 3, "fat": 0, "carbs": 22})
    session.add(food)
    plan = make_plan(session, user, food, quantity="150", include_pantry=False)
    row = plan.entries[0].recipe
    row.created_by_user_id = user.id if own else uuid4()
    # Foreign public recipe is visible in general, but has no UK evidence.
    if not own:
        from app.models import User
        session.add(User(id=row.created_by_user_id, email="foreign@example.invalid", password_hash="test"))
    row.visibility = "private" if own else "public"
    session.commit()
    request = shopping_lists.ShoppingListFromRecipesRequest(recipe_ids=[row.id], store_id=UK_STORES[0].id)
    if not own:
        with pytest.raises(NotFoundException):
            run(shopping_lists.create_shopping_list_from_recipes(request, user, adapter))
        return
    result = run(shopping_lists.create_shopping_list_from_recipes(request, user, adapter))
    assert len(result.items) == 1
    assert result.items[0].regional_snapshot.product_id == food.id
    assert result.items[0].required_quantity == 150


@pytest.mark.asyncio
async def test_off_503_opens_bounded_provider_cooldown_for_other_ingredient_names(monkeypatch):
    barcode_lookup._text_search_cache.clear()
    monkeypatch.setattr(barcode_lookup, "_text_search_unavailable_until", 0.0, raising=False)
    request = httpx.Request("GET", barcode_lookup.OFF_TEXT_SEARCH_URL)
    response = httpx.Response(503, request=request, headers={"Retry-After": "60"})
    get = AsyncMock(side_effect=httpx.HTTPStatusError("unavailable", request=request, response=response))
    client = SimpleNamespace(get=get)

    class ClientContext:
        async def __aenter__(self):
            return client
        async def __aexit__(self, *args):
            return False

    monkeypatch.setattr(barcode_lookup.httpx, "AsyncClient", lambda **kwargs: ClientContext())
    assert await barcode_lookup.search_products_external("Dynia (hokkaido lub piżmowa)") == []
    assert await barcode_lookup.search_products_external("Inny składnik") == []
    assert get.await_count == 1


@pytest.mark.asyncio
async def test_off_downtime_does_not_block_recipe_with_missing_ingredient(monkeypatch):
    from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients
    monkeypatch.setattr(barcode_lookup, "search_products_external", AsyncMock(return_value=[]))
    monkeypatch.setattr("app.services.ingredient_nutrition_estimate.estimate_missing_ingredients",
        AsyncMock(return_value={}))
    raw = {"product_name": "Dynia (hokkaido lub piżmowa)", "quantity": 200, "unit": "g"}
    rows = await resolve_recipe_ingredients([raw], [], country="PL", user_id=uuid4())
    assert rows[0][0] == raw and rows[0][1] is not None
    assert rows[0][1].review_status == "pending"


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_plan_generation_insufficient_recipes_uses_account_language(monkeypatch, country):
    from fastapi import HTTPException
    from app.api.v1 import meal_plans
    from app.schemas.meal_plan import MealPlanGenerateRequest
    from app.services.exceptions import InsufficientRecipesError

    monkeypatch.setattr("app.core.rate_limit.enforce_user_rate_limit", lambda *args: None)
    monkeypatch.setattr("app.services.meal_plan_quota.ensure_can_create_meal_plan", AsyncMock())
    monkeypatch.setattr(MealPlanGenerator, "generate", AsyncMock(side_effect=InsufficientRecipesError(
        meal_type="śniadanie", required=1, available=0)))
    with pytest.raises(HTTPException) as failure:
        await meal_plans.generate_meal_plan(MealPlanGenerateRequest(store_id=uuid4()),
            current_user=SimpleNamespace(id=uuid4(), country_code=country), db=object())
    assert failure.value.status_code == 422
    if country == "GB":
        assert "breakfast" in failure.value.detail and "śniadanie" not in failure.value.detail
        assert "Not enough" in failure.value.detail
    else:
        assert "Niewystarczająca" in failure.value.detail


@pytest.mark.asyncio
@pytest.mark.parametrize(("name", "food"), [
    ("Dynia (hokkaido lub piżmowa)", "Dynia hokkaido"),
    ("Pumpkin (hokkaido or butternut)", "Pumpkin hokkaido"),
])
async def test_explicit_recipe_alternative_reuses_exact_local_food_before_off(monkeypatch, name, food):
    from app.services.recipe_ingredient_catalogue import resolve_recipe_ingredients
    product = Product(id=uuid4(), name=food, unit="g", review_status="approved",
        nutrition_per_100={"kcal": 63, "protein": 1.7, "fat": .6, "carbs": 13.6})
    external = AsyncMock(return_value=[])
    monkeypatch.setattr(barcode_lookup, "search_products_external", external)
    rows = await resolve_recipe_ingredients([dict(product_name=name, quantity=200, unit="g")],
        [product], country="PL", user_id=uuid4())
    assert rows[0][1] is product
    assert rows[0][0]["quantity"] == 200
    external.assert_not_awaited()


def test_real_runtime_seed_text_not_just_generated_fixtures_has_english_translation():
    from app.db.seed import RECIPES_DATA, _uid
    from app.services.system_content_language import _recipe_translations, recipe_display_content

    translations = _recipe_translations()
    for seed in RECIPES_DATA:
        row = SimpleNamespace(id=_uid("recipe:" + seed["name"]), created_by_user_id=None,
            **{key: seed[key] for key in ("name", "description", "instructions", "suggested_seasonings")})
        english = recipe_display_content(row, country_code="GB")
        assert english == translations[seed["name"]], seed["name"]
        assert recipe_display_content(row, country_code="PL")["name"] == seed["name"]
        row.created_by_user_id = uuid4()
        assert recipe_display_content(row, country_code="GB")["name"] == seed["name"]


@pytest.mark.parametrize("change", ["id", "name", "owner", "barcode", "brand", "pending", "newer_off"])
def test_bundled_country_reference_never_approves_changed_identity_or_overrides_newer_facts(db, change):
    from app.services.off_availability import off_available_product_ids
    from app.services.uk_bundled_availability import _reviewed_rows
    from datetime import datetime, timezone

    session, adapter, user, _, _ = db
    food = seeded_oats()
    link, record = next((link, record) for link, record in _reviewed_rows() if link.product_id == food.id)
    if change == "id": food.id = uuid4()
    if change == "name": food.name = "Chocolate oats"
    if change == "owner": food.created_by_user_id = user.id
    if change == "barcode": food.barcode = "5099801003339"
    if change == "brand": food.brand = "A different product"
    if change == "pending": food.review_status = "pending"
    if change == "newer_off":
        values = dict(record.values)
        values["fingerprint"] = "f" * 64
        values["retrieved_at"] = datetime(2026, 10, 25, tzinfo=timezone.utc)
        session.add(OffCatalogueProduct(**values))
    session.add(food)
    session.commit()
    assert run(off_available_product_ids(adapter, [food.id], as_of=date(2026, 10, 25))) == set()


def test_uk_breakfast_selection_has_real_candidates_without_importing_off_into_neon(db):
    from app.db.seed import PRODUCTS_DATA, PRODUCT_BRANDS, NUTRITION_DATA, RECIPES_DATA, _uid
    from app.services.nutrition_calculator import compute_recipe_nutrition_total
    from app.services.uk_bundled_availability import _reviewed_rows
    from unittest.mock import patch

    session, adapter, user, _, _ = db
    names = {link.product_name for link, _ in _reviewed_rows()}
    foods = {}
    for name, unit, quantity, *_ in PRODUCTS_DATA:
        foods[name] = Product(id=_uid("product:" + name), name=name, unit=unit,
            brand=PRODUCT_BRANDS[name], review_status="approved", nutrition_per_100=NUTRITION_DATA[name])
    session.add_all(foods.values())
    eligible_ids = set()
    for seed in RECIPES_DATA:
        if not all(name in names or optional for name, _, _, optional in seed["ingredients"]):
            continue
        row = Recipe(id=_uid("recipe:" + seed["name"]), name=seed["name"], meal_type=seed["meal_type"],
            servings=seed["servings"], visibility="public", is_active=True)
        row.ingredients = [RecipeIngredient(id=uuid4(), product=foods[name],
            quantity=quantity, unit=unit, is_optional=optional)
            for name, quantity, unit, optional in seed["ingredients"]]
        row.nutrition_total = compute_recipe_nutrition_total(row.ingredients)
        session.add(row)
        eligible_ids.add(row.id)
    session.commit()
    with patch("app.services.meal_plan_generator.utc_market_date", return_value=date(2026, 10, 25)):
        values = run(MealPlanGenerator(adapter)._filter_eligible_recipes(
            store_id=UK_STORES[0].id, allergen_ids=set(), user_id=user.id, country_code="GB"))
    assert {row.id for row in values} == eligible_ids
    assert sum(row.meal_type == "śniadanie" for row in values) >= 7
    assert session.scalar(select(OffCatalogueProduct.barcode).limit(1)) is None
    catalogue = [row for skip in (0, 200) for row in run(products.list_products(
        skip=skip, limit=200, search=None, db=adapter, current_user=user))]
    assert {row.id for row in catalogue} == {food.id for food in foods.values()}
    with patch("app.services.meal_plan_generator.utc_market_date", return_value=date(2026, 10, 25)):
        plan = run(MealPlanGenerator(adapter).generate(user.id, UK_STORES[0].id,
            duration_days=7, meals_per_day=3, target_kcal=2000, household_size=1,
            include_pantry=False))
    # The existing calorie-balancing mechanism may add supplementary meals.
    assert len(plan.entries) >= 21
    assert {entry.day_number for entry in plan.entries} == set(range(1, 8))
    for day in range(1, 8):
        daily = [entry for entry in plan.entries if entry.day_number == day]
        assert len(daily) >= 3
        assert len({entry.recipe_id for entry in daily}) == len(daily)
    assert {entry.recipe_id for entry in plan.entries} <= eligible_ids
    assert all(entry.recipe.nutrition_total["kcal"] > 0 for entry in plan.entries)


def test_matching_fresh_off_cache_keeps_bundled_food_available_after_initial_reference_expires(db):
    from app.services.off_availability import off_available_product_ids
    from app.services.uk_bundled_availability import _reviewed_rows
    from datetime import datetime, timezone

    session, adapter, _, _, _ = db
    food = seeded_oats()
    _, record = next((link, record) for link, record in _reviewed_rows() if link.product_id == food.id)
    values = dict(record.values)
    values["retrieved_at"] = datetime(2026, 12, 1, tzinfo=timezone.utc)
    session.add_all([food, OffCatalogueProduct(**values)])
    session.commit()
    assert run(off_available_product_ids(adapter, [food.id], as_of=date(2026, 12, 1))) == {food.id}


@pytest.mark.parametrize("cached_age", [None, 8])
def test_used_bundled_food_gets_real_bounded_background_refresh_without_admin_or_bulk_import(db, monkeypatch, cached_age):
    from datetime import datetime, timedelta, timezone
    from app.services import off_on_demand
    from app.services.off_availability import off_available_product_ids
    from app.services.uk_bundled_availability import _reviewed_rows
    from app.models import OffIngredientMapping

    session, adapter, _, _, _ = db
    food = seeded_oats()
    link, record = next((link, record) for link, record in _reviewed_rows() if link.product_id == food.id)
    identity = food.id
    row = Recipe(id=uuid4(), name="Oats breakfast", meal_type="śniadanie", is_active=True)
    row.ingredients = [RecipeIngredient(id=uuid4(), product=food, quantity=60, unit="g", is_optional=False)]
    session.add(row)
    now = datetime(2026, 12, 1, tzinfo=timezone.utc)
    if cached_age is not None:
        values = dict(record.values)
        values["retrieved_at"] = now - timedelta(days=cached_age)
        session.add(OffCatalogueProduct(**values))
    session.commit()
    async def handler(request):
        assert link.off_barcode in str(request.url)
        return httpx.Response(200, json={"status": "success", "result": {"id": "product_found"}, "product": record.raw})
    requests = connect_io(db, monkeypatch, handler)
    assert run(off_on_demand.refresh_public_recipe_evidence(now=now)) == "checked"
    assert len(requests) == 1
    assert run(off_available_product_ids(adapter, [identity], as_of=now.date())) == {identity}
    session.rollback()
    assert run(off_on_demand.refresh_public_recipe_evidence(now=now)) == "busy"
    cached = session.get(OffCatalogueProduct, link.off_barcode)
    assert cached.fingerprint == link.off_fingerprint
    assert cached.retrieved_at.replace(tzinfo=timezone.utc) == now
    assert session.scalar(select(OffIngredientMapping).where(OffIngredientMapping.product_id == identity)) is None
    assert session.get(Product, identity).nutrition_per_100["kcal"] == 389
