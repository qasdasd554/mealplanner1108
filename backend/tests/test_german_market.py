"""DE market regressions using the existing purchase and store paths."""

from datetime import date, timedelta
from decimal import Decimal
import json
from pathlib import Path
from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.api.v1 import pantry, products, recipes, shopping_lists, stores
from app.api.v1.price_compare import compare_prices, compare_shopping_list_prices
from app.core.config import settings
from app.core.exceptions import NotFoundException
from app.core.markets import signup_country
from app.db.de_store_catalog import (
    DE_STORES, reviewed_de_catalogue_date, seed_de_stores,
    seed_de_test_catalogue, stage_reviewed_de_catalogue,
)
from app.db.uk_store_catalog import UK_STORES
from app.models import PantryItem, Product, Recipe, RecipeIngredient, ShoppingList, Store, StoreProduct, User
from app.schemas.shopping_list import ShoppingListResponse
from app.services.meal_plan_generator import MealPlanGenerator
from app.services.pantry_shopping_sync import sync_product_in_shopping_lists
from app.services.polish_list_prices import quote_polish_list
from app.services.shopping_list_builder import ShoppingListBuilder
from app.services.system_content_language import _index
from tests.test_regional_shopping import db, loaded, make_plan, run


def test_german_approved_submission_prices_the_reported_pack(db):
    from app.services.product_measures import build_measure_options

    session, adapter, _, _, _ = db
    user = User(id=uuid4(), email="de-submission@example.test", password_hash="fixture", country_code="DE")
    session.add(user)
    run(seed_de_stores(adapter))
    shop = DE_STORES[0]
    foreign = UK_STORES[0]
    food = Product(
        id=uuid4(), name="Beispiel-Haferflocken", unit="g", default_quantity=Decimal("100"),
        serving_quantity=500, measure_options=build_measure_options("Beispiel-Haferflocken", "g", 100, 500),
        created_by_user_id=user.id, review_status="pending", submitted_country_code="DE",
        submitted_price=Decimal("1.59"), requested_store_ids=[str(shop.id), str(foreign.id)],
    )
    session.add(food)
    session.commit()
    admin = SimpleNamespace(id=uuid4(), country_code="PL", role="admin")

    def review(approve):
        run(products.review_product(food.id, approve, db=adapter, current_user=admin))

    review(True)
    review(True)
    offer = session.scalars(select(StoreProduct).where(StoreProduct.product_id == food.id)).one()
    assert (offer.store_id, offer.package_quantity, offer.package_unit) == (shop.id, Decimal("500"), "g")
    assert offer.last_verified is None
    rows = run(stores.list_store_products(
        shop.id, skip=0, limit=20, search=food.name, department_id=None,
        include_generic_foods=False, db=adapter, current_user=user,
    ))
    assert len(rows) == 1
    assert (rows[0].price, rows[0].currency_code) == (1.59, "EUR")

    item = SimpleNamespace(
        store_product=None, catalogue_product_id=food.id, custom_name=food.name,
        required_quantity=Decimal("650"), unit="g",
        regional_snapshot=None, is_checked=False, is_from_pantry=False,
    )
    quote = run(quote_polish_list(adapter, SimpleNamespace(items=[item]), [session.get(Store, shop.id)]))
    assert quote[shop.id][0][2]["price_in_store"] == 3.18

    changed = products.ProductSubmission(
        name=food.name, price=Decimal("2.19"), unit="g",
        store_ids=[shop.id], serving_quantity=400, serving_unit="g",
    )
    run(products.update_own_product(food.id, changed, db=adapter, current_user=user))
    assert not offer.is_available
    assert run(stores.list_store_products(
        shop.id, skip=0, limit=20, search=food.name, department_id=None,
        include_generic_foods=False, db=adapter, current_user=user,
    )) == []
    review(True)
    assert offer.is_available
    assert (offer.price, offer.package_quantity) == (Decimal("2.19"), Decimal("400"))
    review(False)
    assert not offer.is_available


def test_german_pantry_projects_the_same_generic_food_as_the_catalogue(db):
    from app.db.seed import _uid

    session, adapter, _, _, _ = db
    user = User(id=uuid4(), email="de-pantry@example.test", password_hash="fixture", country_code="DE")
    food = Product(
        id=_uid("product:Jabłka"), name="Jabłka", unit="szt",
        brand="PL sample brand", default_quantity=Decimal("1"), serving_quantity=150,
    )
    session.add_all([user, food])
    session.add(PantryItem(id=uuid4(), user_id=user.id, product_id=food.id, quantity=2, unit="szt"))
    session.commit()

    [row] = run(pantry.get_pantry(current_user=user, db=adapter))
    assert row.product.name == "Äpfel"
    assert row.product.brand is None
    assert row.product.serving_quantity is None
    assert (row.quantity, row.unit) == (2, "szt")


def test_german_registration_requires_explicit_rollout(monkeypatch):
    monkeypatch.setattr(settings, "DE_MARKET_ENABLED", False)
    with pytest.raises(HTTPException) as error:
        signup_country("de")
    assert error.value.status_code == 503
    monkeypatch.setattr(settings, "DE_MARKET_ENABLED", True)
    assert signup_country("de") == "DE"


def test_available_recipes_use_german_store_and_author_market(db):
    session, adapter, _, product, substitute = db
    german = User(id=uuid4(), email="de-recipes@example.test", password_hash="fixture", country_code="DE")
    polish = User(id=uuid4(), email="pl-recipes@example.test", password_hash="fixture", country_code="PL")
    session.add_all([german, polish])
    run(seed_de_stores(adapter))
    store = DE_STORES[0]
    session.add(StoreProduct(id=uuid4(), store_id=store.id, product_id=product.id, price=Decimal("1.25")))

    def add_recipe(name, author, ingredient, optional=None):
        recipe = Recipe(id=uuid4(), name=name, meal_type="obiad", servings=2, visibility="public",
                        created_by_user_id=author.id if author else None)
        recipe.ingredients = [RecipeIngredient(
            id=uuid4(), product_id=ingredient.id, quantity=Decimal("100"), unit="g", is_optional=False,
        )]
        if optional is not None:
            recipe.ingredients.append(RecipeIngredient(
                id=uuid4(), product_id=optional.id, quantity=Decimal("5"), unit="g", is_optional=True,
            ))
        session.add(recipe)

    add_recipe("Verfügbares Rezept", german, product)
    add_recipe("System recipe", None, product)
    add_recipe("Optionale Zutat", None, product, optional=substitute)
    add_recipe("Polski przepis", polish, product)
    add_recipe("Nicht verfügbar", german, substitute)
    session.commit()

    available = run(recipes.list_available_recipes(
        store.id, skip=0, limit=30, current_user=german, db=adapter,
    ))
    assert {recipe.name for recipe in available} == {"System recipe", "Verfügbares Rezept", "Optionale Zutat"}


def test_reviewed_aldi_catalogue_preserves_prices_and_quotes_whole_packs(db):
    from app.db.seed import PRODUCTS_DATA, RECIPES_DATA, _uid

    session, adapter, _, _, _ = db
    data_dir = Path(__file__).resolve().parents[1] / "app/data"
    evidence = json.loads((data_dir / "de_aldi_sued_reviewed_20261110.json").read_text(encoding="utf-8"))
    extension = json.loads((data_dir / "de_aldi_sued_reviewed_20261112.json").read_text(encoding="utf-8"))
    weekly = json.loads((data_dir / "de_aldi_sued_weekly_reviewed_20261112.json").read_text(encoding="utf-8"))
    staples = json.loads((data_dir / "de_aldi_sued_staples_reviewed_20261112.json").read_text(encoding="utf-8"))
    observed_on = date(2026, 11, 10)
    names = {row["canonical"] for row in evidence["products"]}
    extra_names = {row["canonical"] for row in extension["products"]}
    weekly_names = {row["canonical"] for row in weekly["products"]}
    staple_names = {row["canonical"] for row in staples["products"]}
    assert names.isdisjoint(extra_names)
    all_previous = names | extra_names | weekly_names
    assert staple_names.isdisjoint(all_previous)
    for name, unit, quantity, *_ in PRODUCTS_DATA:
        if name in all_previous | staple_names:
            session.add(Product(id=_uid(f"product:{name}"), name=name, unit=unit,
                                default_quantity=quantity, review_status="approved"))
    run(seed_de_stores(adapter))
    definition = next(store for store in DE_STORES if store.slug == "aldi-sued")
    existing = StoreProduct(id=uuid4(), store_id=definition.id,
                            product_id=_uid("product:Jogurt naturalny"), price=Decimal("1.09"))
    session.add(existing)
    session.commit()

    transaction = session.begin_nested()
    assert run(stage_reviewed_de_catalogue(adapter, evidence, as_of=observed_on)) == len(names) - 1
    transaction.rollback()
    assert session.scalars(select(StoreProduct).where(StoreProduct.store_id == definition.id)).all() == [existing]

    assert run(stage_reviewed_de_catalogue(adapter, evidence, as_of=observed_on)) == len(names) - 1
    assert run(stage_reviewed_de_catalogue(adapter, evidence, as_of=observed_on)) == 0
    assert (existing.price, existing.last_verified) == (Decimal("1.09"), None)
    item = SimpleNamespace(
        store_product=None, catalogue_product_id=_uid("product:Makaron spaghetti"),
        custom_name="Spaghetti", required_quantity=Decimal("750"), unit="g",
        regional_snapshot=None, is_checked=False, is_from_pantry=False,
    )
    store = session.get(Store, definition.id)
    quotes = run(quote_polish_list(adapter, SimpleNamespace(items=[item]), [store]))
    _, offer, quote = quotes[definition.id][0]
    assert store.currency_code == "EUR"
    assert (offer.package_quantity, offer.package_unit) == (Decimal("500"), "g")
    assert (quote["price_in_store"], quote["package_count"]) == (1.38, 2)
    assert quote["last_verified"] == observed_on
    assert quote["price_is_estimated"] is False

    extension_date = date(2026, 11, 12)
    assert run(stage_reviewed_de_catalogue(adapter, extension, as_of=extension_date)) == len(extra_names)
    assert run(stage_reviewed_de_catalogue(adapter, extension, as_of=extension_date)) == 0
    assert run(stage_reviewed_de_catalogue(adapter, weekly, as_of=extension_date)) == len(weekly_names)
    assert run(stage_reviewed_de_catalogue(adapter, staples, as_of=extension_date)) == len(staple_names)
    assert run(stage_reviewed_de_catalogue(adapter, staples, as_of=extension_date)) == 0
    cod_offer = session.scalar(select(StoreProduct).where(
        StoreProduct.store_id == store.id,
        StoreProduct.product_id == _uid("product:Dorsz filet"),
    ))
    assert cod_offer.retailer_sku == "000000000000211760"

    def price_required_ingredients(recipe_name):
        recipe = next(row for row in RECIPES_DATA if row["name"] == recipe_name)
        required_items = [SimpleNamespace(
            store_product=None, catalogue_product_id=_uid(f"product:{name}"),
            custom_name=name, required_quantity=quantity, unit=unit,
            regional_snapshot=None, is_checked=False, is_from_pantry=False,
        ) for name, quantity, unit, optional in recipe["ingredients"] if not optional]
        basket_quotes = run(quote_polish_list(adapter, SimpleNamespace(items=required_items), [store]))
        return {row.custom_name: (quote["price_in_store"], quote["package_count"], quote["last_verified"])
                for row, _, quote in basket_quotes[definition.id]}

    assert price_required_ingredients("Kanapki z pastą jajeczną") == {
        "Jajka": (2.99, 1, observed_on),
        "Chleb pszenny": (1.19, 1, extension_date),
        "Masło extra": (1.19, 1, extension_date),
    }
    assert price_required_ingredients("Kurczak curry z ryżem") == {
        "Pierś z kurczaka": (6.79, 1, extension_date),
        "Mleko kokosowe": (1.19, 1, extension_date),
        "Curry w proszku": (0.75, 1, extension_date),
        "Cebula": (1.39, 1, extension_date),
        "Ryż biały": (1.39, 1, observed_on),
    }
    cod_basket = price_required_ingredients("Dorsz pieczony z cytryną i ziołami")
    assert all(price is not None for price, _, _ in cod_basket.values())
    assert cod_basket["Dorsz filet"] == (15.98, 2, extension_date)


def test_reviewed_import_rejects_test_estimates_and_outdated_observations():
    data_dir = Path(__file__).resolve().parents[1] / "app/data"
    observed_on = date(2026, 11, 10)
    sample = json.loads((data_dir / "de_aldi_sued_starter.json").read_text(encoding="utf-8"))
    reviewed = json.loads((data_dir / "de_aldi_sued_reviewed_20261110.json").read_text(encoding="utf-8"))
    with pytest.raises(ValueError, match="Only observed"):
        reviewed_de_catalogue_date(sample, as_of=observed_on)
    for as_of in (observed_on + timedelta(days=8), observed_on - timedelta(days=1)):
        with pytest.raises(ValueError, match="stale or in the future"):
            reviewed_de_catalogue_date(reviewed, as_of=as_of)


def test_catalogue_coverage_counts_each_shop_and_ignores_expired_files(tmp_path, monkeypatch):
    from app.db import seed
    from scripts.import_de_catalogue import recipe_coverage

    def recipe(meal, *names):
        return {"meal_type": meal, "ingredients": [(name, 1, "g", False) for name in names]}

    monkeypatch.setattr(seed, "RECIPES_DATA", [
        recipe("breakfast", "Jajka"),
        recipe("lunch", "Jajka", "Mleko kokosowe"),
        recipe("lunch", "Jajka", "Mleko kokosowe", "Curry w proszku"),
    ])

    def source(slug, observed_on, *products):
        path = tmp_path / f"{slug}-{observed_on}.json"
        path.write_text(json.dumps({
            "store_slug": slug, "currency": "EUR", "reviewed_on": observed_on,
            "purpose": "observed retailer catalogue prices",
            "products": [{"canonical": name} for name in products],
        }), encoding="utf-8")
        return path

    aldi = source("aldi-sued", "2026-11-10", "Jajka")
    rewe = source("rewe", "2026-11-11", "Mleko kokosowe")
    expired = source("aldi-sued", "2026-11-01", "Curry w proszku")
    report = recipe_coverage([aldi, rewe, expired], as_of=date(2026, 11, 12))
    assert report["expired_sources"] == [expired.name]
    assert [(shop["store"], shop["covered_recipes"]) for shop in report["stores"]] == [
        ("aldi-sued", 1), ("rewe", 0),
    ]
    assert report["stores"][0]["next_pairs"] == [
        {"products": ("Curry w proszku", "Mleko kokosowe"), "recipes_unlocked": 2},
    ]


def test_german_development_catalogue_keeps_prices_and_package_units(db, monkeypatch):
    from app.db.seed import AUTUMN_PRODUCT_NAMES, NUTRITION_DATA, PRODUCTS_DATA, RECIPES_DATA, _uid, calculate_nutrition
    from app.services.product_measures import build_measure_options

    session, adapter, _, _, _ = db
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    run(seed_de_stores(adapter))
    directory = Path(__file__).resolve().parents[1] / "app/data"
    catalogues = {}
    for path in sorted(directory.glob("de_*_starter.json")):
        evidence = json.loads(path.read_text(encoding="utf-8"))
        catalogues[evidence["store_slug"]] = {entry["canonical"] for entry in evidence["products"]}
    assert catalogues.keys() == {store.slug for store in DE_STORES}
    for name, unit, quantity, *_ in PRODUCTS_DATA:
        serving = None
        if name not in AUTUMN_PRODUCT_NAMES and unit != "szt":
            serving = float(quantity) * (1000 if unit in {"kg", "l"} else 1)
        session.add(Product(
            id=_uid(f"product:{name}"), name=name, unit=unit,
            default_quantity=quantity, review_status="approved", serving_quantity=serving,
            nutrition_per_100=NUTRITION_DATA.get(name),
            measure_options=build_measure_options(name, unit, float(quantity), serving),
        ))
    session.flush()

    definitions = {store.slug: store for store in DE_STORES}
    for slug, catalogue in catalogues.items():
        assert run(seed_de_test_catalogue(adapter, store_slug=slug)) == len(catalogue)
        assert run(seed_de_test_catalogue(adapter, store_slug=slug)) == 0
    store = definitions["aldi-sued"]
    offers = session.scalars(select(StoreProduct).where(StoreProduct.store_id == store.id)).all()
    assert len(offers) == len(catalogues["aldi-sued"]) and all(row.last_verified is None for row in offers)
    butter = next(row for row in offers if row.product_id == _uid("product:Masło extra"))
    assert (butter.package_quantity, butter.package_unit, butter.price) == (Decimal(250), "g", Decimal("1.19"))
    assert butter.product.default_quantity == Decimal(200)

    user = User(id=uuid4(), email="aldi-pilot@example.test", password_hash="fixture", country_code="DE", is_premium=True)
    session.add(user)
    meal_types = {"śniadanie", "obiad", "kolacja"}
    for data in RECIPES_DATA:
        ingredients = data["ingredients"]
        kcal = sum(calculate_nutrition(name, float(quantity), unit).get("kcal", 0)
                   for name, quantity, unit, _ in ingredients)
        recipe = Recipe(
            id=_uid(f'recipe:{data["name"]}'), name=data["name"], description=data["description"],
            meal_type=data["meal_type"], servings=data["servings"], nutrition_total={"kcal": round(kcal, 1)},
            instructions=data.get("instructions", []), suggested_seasonings=data.get("suggested_seasonings", []),
        )
        recipe.ingredients = [RecipeIngredient(
            id=uuid4(), product_id=_uid(f"product:{name}"), quantity=quantity, unit=unit, is_optional=optional,
        ) for name, quantity, unit, optional in ingredients]
        session.add(recipe)
    session.commit()
    for slug, days in (("aldi-sued", 5), ("aldi-nord", 3), ("kaufland", 3)):
        plan = run(MealPlanGenerator(adapter).generate(
            user.id, definitions[slug].id, duration_days=days, meals_per_day=3, include_pantry=False,
            preferences={"meal_types": ["śniadanie", "obiad", "kolacja"]}, household_size=2,
        ))
        for day in range(1, days + 1):
            entries = [entry for entry in plan.entries if entry.day_number == day]
            assert {entry.meal_slot for entry in entries} == meal_types
            assert all(entry.recipe.meal_type == entry.meal_slot for entry in entries)
            assert len(entries) == len({entry.recipe_id for entry in entries})
        shopping_id = session.scalar(select(ShoppingList.id).where(ShoppingList.meal_plan_id == plan.id))
        result = ShoppingListResponse.model_validate(loaded(session, shopping_id))
        assert result.currency_code == "EUR"
        required = {
            ingredient.product_id for entry in plan.entries
            for ingredient in entry.recipe.ingredients if not ingredient.is_optional
        }
        items = [item for department in result.items_by_department.values() for item in department]
        priced = {item.product_id for item in items if item.estimated_price is not None}
        unpriced = [item.product_name for item in items if item.estimated_price is None]
        assert required <= priced, (slug, unpriced)
        assert any(item.estimated_price and item.estimated_price > 0 for item in items)
        assert result.has_unpriced_items == bool(unpriced)
        if unpriced:
            assert result.total_estimated_price is None
            assert plan.estimated_min_budget is None
        else:
            assert result.total_estimated_price is not None and result.total_estimated_price > 0
            assert plan.estimated_min_budget == Decimal(str(result.total_estimated_price)).quantize(Decimal("0.01"))

    eggs = session.get(Product, _uid("product:Jajka"))
    eggs_plan = make_plan(session, user, eggs, quantity="8", unit="szt", include_pantry=False, store_id=store.id)
    run(ShoppingListBuilder(adapter).build_from_meal_plan(eggs_plan.id))
    session.commit()
    compared = {row.store_name: row for row in run(compare_shopping_list_prices(eggs_plan.id, adapter, user))}
    assert compared["ALDI SÜD"].total_price == 2.99
    assert compared["ALDI Nord"].total_price == 2.49
    assert compared["ALDI Nord"].items[0].package_count == 1
    assert compared["ALDI Nord"].items[0].product_name == "Eier"

    honey = session.get(Product, _uid("product:Miód"))
    honey_plan = make_plan(session, user, honey, quantity="300", include_pantry=False, store_id=store.id)
    run(ShoppingListBuilder(adapter).build_from_meal_plan(honey_plan.id))
    session.commit()
    compared = {row.store_name: row for row in run(compare_shopping_list_prices(honey_plan.id, adapter, user))}
    assert compared["ALDI SÜD"].total_price == compared["ALDI Nord"].total_price == 3.95
    assert compared["Kaufland"].total_price == 4.98
    assert compared["Kaufland"].items[0].package_count == 2
    assert compared["Kaufland"].items[0].price_is_estimated

    butter_plan = make_plan(session, user, butter.product, quantity="225", include_pantry=False, store_id=store.id)
    run(ShoppingListBuilder(adapter).build_from_meal_plan(butter_plan.id))
    session.commit()
    compared = {row.store_name: row for row in run(compare_shopping_list_prices(butter_plan.id, adapter, user))}
    assert compared["EDEKA"].total_price == 1.29
    assert compared["EDEKA"].items[0].package_count == 1

    corn = session.get(Product, _uid("product:Kukurydza konserwowa"))
    corn_plan = make_plan(session, user, corn, quantity="286", include_pantry=False, store_id=store.id)
    run(ShoppingListBuilder(adapter).build_from_meal_plan(corn_plan.id))
    session.commit()
    compared = {row.store_name: row for row in run(compare_shopping_list_prices(corn_plan.id, adapter, user))}
    assert compared["REWE"].total_price == 2.22
    assert compared["REWE"].items[0].package_count == 2

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    with pytest.raises(RuntimeError, match="development"):
        run(seed_de_test_catalogue(adapter))


def test_german_shops_and_unpriced_references_stay_separate_from_actual_offers(db):
    session, adapter, gb, _, _ = db
    de = SimpleNamespace(id=uuid4(), role="user", country_code="DE")
    run(seed_de_stores(adapter))
    run(seed_de_stores(adapter))
    session.commit()
    definitions = sorted(DE_STORES, key=lambda store: store.name)
    german_stores = run(stores.list_stores(adapter, de, market=None))
    assert [(row.id, row.currency_code) for row in german_stores] == [(row.id, "EUR") for row in definitions]
    assert all(row.country_code == "GB" for row in run(stores.list_stores(adapter, gb, market=None)))
    source = definitions[0]
    ingredients = list(_index()["ingredients"].items())[:2]
    for product_id, info in ingredients:
        session.add(Product(id=UUID(product_id), name=info["source"], unit="g", review_status="approved"))
    session.flush()
    offered_id = UUID(ingredients[0][0])
    session.add(StoreProduct(id=uuid4(), store_id=source.id, product_id=offered_id,
                             price=Decimal("1.80"), package_quantity=Decimal(125), package_unit="g"))
    session.commit()

    def page(*, skip=0, search=None):
        return run(stores.list_store_products(
            source.id, skip=skip, limit=1, search=search, department_id=None,
            include_generic_foods=True, db=adapter, current_user=de, market=None,
        ))

    offer, = page()
    assert (offer.product_id, offer.price, offer.currency_code) == (offered_id, 1.8, "EUR")
    assert (offer.package_quantity, offer.package_unit) == (125, "g")
    reference, = page(skip=1)
    assert reference.product_id == UUID(ingredients[1][0])
    assert reference.catalogue_kind == "generic_food"
    assert reference.product.name == ingredients[1][1]["de"]
    assert reference.price is None and reference.is_available is None
    assert page(skip=2) == []
    assert page(search=ingredients[1][1]["de"])[0].product_id == reference.product_id


def test_german_shopping_uses_eur_and_rejects_switch_to_gb(db):
    session, adapter, _, product, _ = db
    user = User(id=uuid4(), email="de-shopping@example.test", password_hash="fixture", country_code="DE", is_premium=True)
    session.add(user)
    run(seed_de_stores(adapter))
    source, target = DE_STORES[:2]
    for store, price, size in ((source, Decimal("1.25"), 125), (target, Decimal("2.00"), 250)):
        session.add(StoreProduct(id=uuid4(), store_id=store.id, product_id=product.id, price=price,
                                 package_quantity=Decimal(size), package_unit="g"))
    session.commit()

    plan = make_plan(session, user, product, quantity="200", include_pantry=False, store_id=source.id)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    session.commit()
    shopping = loaded(session, shopping.id)
    listed = ShoppingListResponse.model_validate(shopping)
    assert listed.currency_code == "EUR"
    assert {item.currency_code for items in listed.items_by_department.values() for item in items} == {"EUR"}

    compare = run(compare_shopping_list_prices(plan.id, adapter, user))
    assert {row.currency_code for row in compare} == {"EUR"}
    assert {row.store_id for row in compare} == {row.id for row in DE_STORES}
    quoted = next(row for row in compare if row.store_id == target.id)
    assert quoted.total_price == 2.0
    assert quoted.items[0].package_count == 1
    plan_prices = run(compare_prices(plan.id, adapter, user))
    assert next(row for row in plan_prices if row.store_id == target.id).total_price == quoted.total_price
    unpriced = next(row for row in compare if row.store_id == DE_STORES[2].id)
    assert unpriced.total_price is None

    payload = shopping_lists.ShoppingListStoreRequest(store_id=UK_STORES[0].id)
    with pytest.raises(NotFoundException):
        run(shopping_lists.update_shopping_list_store(plan.id, payload, user, adapter))
    assert session.scalar(select(Store.country_code).where(Store.id == shopping.store_id)) == "DE"
    payload = shopping_lists.ShoppingListStoreRequest(store_id=target.id)
    switched = run(shopping_lists.update_shopping_list_store(plan.id, payload, user, adapter))
    assert switched.store_id == target.id
    assert ShoppingListResponse.model_validate(switched).total_estimated_price == quoted.total_price
    switched.items[0].is_checked = True
    session.commit()
    run(shopping_lists.complete_shopping_list(plan.id, True, user, adapter))
    pantry = session.scalar(select(PantryItem).where(PantryItem.user_id == user.id))
    assert (pantry.quantity, pantry.unit) == (Decimal(250), "g")


def test_german_list_can_find_an_offer_after_starting_in_an_unpriced_shop(db):
    session, adapter, _, product, _ = db
    user = User(id=uuid4(), email="de-unpriced@example.test", password_hash="fixture", country_code="DE", is_premium=True)
    session.add(user)
    run(seed_de_stores(adapter))
    source, target = DE_STORES[:2]
    offer = StoreProduct(id=uuid4(), store_id=target.id, product_id=product.id,
                         price=Decimal("2.00"), package_quantity=Decimal(250), package_unit="g")
    session.add(offer)
    session.commit()
    plan = make_plan(session, user, product, quantity="200", include_pantry=True, store_id=source.id)
    shopping = run(ShoppingListBuilder(adapter).build_from_meal_plan(plan.id))
    session.commit()
    assert ShoppingListResponse.model_validate(loaded(session, shopping.id)).total_estimated_price is None

    def comparison(store):
        return next(row for row in run(compare_shopping_list_prices(plan.id, adapter, user))
                    if row.store_id == store.id)

    def switch(store):
        return run(shopping_lists.update_shopping_list_store(
            plan.id, shopping_lists.ShoppingListStoreRequest(store_id=store.id), user, adapter,
        ))

    assert comparison(target).total_price == 2
    priced = switch(target)
    assert priced.items[0].store_product_id == offer.id
    assert ShoppingListResponse.model_validate(priced).total_estimated_price == 2
    unpriced = switch(source)
    assert unpriced.items[0].store_product_id is None
    assert unpriced.items[0].estimated_price is None
    assert unpriced.items[0].required_quantity == Decimal(200)
    assert comparison(target).total_price == 2

    session.add(PantryItem(user_id=user.id, product_id=product.id, quantity=Decimal(100), unit="g"))
    session.flush()
    run(sync_product_in_shopping_lists(adapter, user.id, product.id))
    session.commit()
    rows = loaded(session, shopping.id).items
    assert {(item.is_from_pantry, item.required_quantity, item.estimated_price) for item in rows} == {
        (True, Decimal(100), Decimal(0)), (False, Decimal(100), None),
    }
    assert comparison(target).total_price == 2


def test_german_plan_generation_uses_real_same_market_offer(db):
    session, adapter, _, product, _ = db
    user = User(id=uuid4(), email="de-plan@example.test", password_hash="fixture", country_code="DE", is_premium=True)
    session.add(user)
    run(seed_de_stores(adapter))
    source = DE_STORES[0]
    session.add(StoreProduct(id=uuid4(), store_id=source.id, product_id=product.id, price=Decimal("1.25")))
    recipe = Recipe(id=uuid4(), name="Fixture meal", meal_type="obiad", servings=2)
    recipe.ingredients = [RecipeIngredient(
        id=uuid4(), product_id=product.id, quantity=Decimal("200"), unit="g", is_optional=False,
    )]
    session.add(recipe)
    session.commit()

    plan = run(MealPlanGenerator(adapter).generate(
        user.id, source.id, duration_days=1, meals_per_day=1,
        preferences={"meal_types": ["obiad"]}, include_pantry=False, household_size=2,
    ))
    assert [entry.recipe_id for entry in plan.entries] == [recipe.id]
    assert plan.estimated_min_budget == Decimal("2.50")
    shopping_id = session.scalar(select(ShoppingList.id).where(ShoppingList.meal_plan_id == plan.id))
    response = ShoppingListResponse.model_validate(loaded(session, shopping_id))
    assert (response.store_id, response.currency_code, response.total_estimated_price) == (source.id, "EUR", 2.5)
