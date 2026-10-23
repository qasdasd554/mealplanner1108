"""Resolve recipe ingredients on demand; no invented nutrition, packs or prices.

Provider lookups are read-only. New shared products are staged only after the
whole recipe has been resolved, in the caller's recipe/points transaction.
"""

import asyncio
import math
import re
import unicodedata
from datetime import datetime, timezone
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.models import Product
from app.services import barcode_lookup
from app.services.recipe_ingredient_integrity import looks_like_whole_meal
from app.services.product_measures import build_measure_options


def _normal(value):
    text = unicodedata.normalize("NFKD", str(value or "").casefold().replace("ł", "l"))
    return " ".join(re.findall(r"[a-z0-9]+", "".join(c for c in text if not unicodedata.combining(c))))


# Explicit equivalents, not a fuzzy removal of qualifiers such as bone-in,
# boneless, dried, cooked, low-fat or flavoured.
_ALIASES = {
    **{name: "salt" for name in ("salt", "table salt", "sol", "sol kuchenna")},
    **{name: "water" for name in ("water", "tap water", "drinking water", "woda", "woda pitna")},
    **{name: "black pepper" for name in ("pepper", "black pepper", "ground black pepper", "pieprz", "pieprz czarny", "pieprz czarny mielony")},
}


def ingredient_key(name):
    key = _normal(name)
    return _ALIASES.get(key, key)


def has_recipe_nutrition(product):
    nutrition = product.nutrition_per_100 or {}
    try:
        values = [float(nutrition[key]) for key in ("kcal", "protein", "fat", "carbs")]
    except (KeyError, TypeError, ValueError, OverflowError):
        return False
    if any(not math.isfinite(value) or value < 0 for value in values):
        return False
    return any(value > 0 for value in values) or ingredient_key(getattr(product, "name", "")) in {"salt", "water"}


def _proposal(name, unit, nutrition, *, country, source, brand=None, barcode=None, package=None, owner_id=None):
    identifier = uuid5(NAMESPACE_URL, "mealplanner:discovered-ingredient:" +
        "|".join((ingredient_key(name), _normal(brand), unit, barcode or "", str(owner_id or "shared"))))
    product = Product(id=identifier, name=name[:300], brand=brand, unit=unit,
        default_quantity=package, serving_quantity=package,
        nutrition_per_100={**nutrition, "_source": source},
        measure_options=build_measure_options(name, unit, package, package),
        barcode=barcode, review_status="pending" if owner_id else "approved", created_by_user_id=owner_id,
        submitted_country_code=country)
    product._discovered_recipe_ingredient = True
    return product


async def _external_ingredient(name, *, country):
    results = await barcode_lookup.search_products_external(name, limit=10, country_code=country)
    for item in results:
        if (ingredient_key(item.name) != ingredient_key(name)
                or looks_like_whole_meal(item.name)
                or item.source not in {"open_food_facts", "usda_fooddata_central"}
                or item.unit not in {"g", "ml"}
                or not barcode_lookup.has_complete_nutrition(item)):
            continue
        nutrition = dict(kcal=item.kcal_per_100, protein=item.protein_per_100,
                         fat=item.fat_per_100, carbs=item.carbs_per_100)
        if nutrition["kcal"] > 2000 or any(nutrition[key] > 100 for key in ("protein", "fat", "carbs")):
            continue
        code = barcode_lookup.normalize_barcode(item.barcode) if item.barcode else None
        package = item.serving_quantity
        if package is not None and (not math.isfinite(package) or not 0 < package <= 100000):
            package = None
        source = {"provider": item.source, "name": item.name, "barcode": code,
                  "checked_at": datetime.now(timezone.utc).isoformat(),
                  "allergens_checked": False}
        if item.source == "open_food_facts":
            source.update(licence="ODbL-1.0", url=f"https://world.openfoodfacts.org/product/{code}" if code else "https://world.openfoodfacts.org")
        candidate = _proposal(item.name, item.unit, nutrition, country=country,
            source=source, brand=item.brand, barcode=code, package=package)
        if has_recipe_nutrition(candidate):
            return candidate
    return None


async def resolve_recipe_ingredients(ingredients, catalogue, *, country, user_id=None):
    from app.services.ai_recipe_import import match_product_name
    usable = [product for product in catalogue if has_recipe_nutrition(product)
              and not looks_like_whole_meal(product.name)]
    by_name = {product.name.casefold(): product for product in usable}
    names = list(by_name)
    pairs = []
    missing = {}
    for ingredient in ingredients:
        match = match_product_name(ingredient["product_name"], names)
        product = by_name.get(match.casefold()) if match else None
        key = ingredient_key(ingredient["product_name"])
        if product is None and key == "water":
            # Plain cooking water is a known zero-energy ingredient, not
            # an assumed package or a guessed branded food's nutrition.
            product = _proposal("Water" if country == "GB" else "Woda", "ml",
                {"kcal": 0, "protein": 0, "fat": 0, "carbs": 0}, country=country,
                source={"provider": "plain_cooking_water", "allergens_checked": True})
        pairs.append((ingredient, product))
        if product is None:
            missing.setdefault(key, ingredient["product_name"])
    if not missing:
        return pairs
    semaphore = asyncio.Semaphore(3)
    async def lookup(name):
        async with semaphore:
            try:
                return await asyncio.wait_for(_external_ingredient(name, country=country), timeout=4)
            except (TimeoutError, ValueError, TypeError, ArithmeticError):
                return None
    tasks = {key: asyncio.create_task(lookup(name)) for key, name in list(missing.items())[:30]}
    try:
        done, pending = await asyncio.wait(tasks.values(), timeout=12)
        found = {key: task.result() for key, task in tasks.items() if task in done and not task.cancelled() and task.exception() is None}
    finally:
        for task in tasks.values():
            if not task.done(): task.cancel()
        await asyncio.gather(*tasks.values(), return_exceptions=True)
    resolved = []
    for ingredient, product in pairs:
        product = product or found.get(ingredient_key(ingredient["product_name"]))
        if product is None and user_id is not None:
            # Preserve the exact required ingredient and quantity, but never
            # publish unverified nutrition or invent a GTIN/package/price.
            base_unit = ("szt" if ingredient["unit"] == "szt" else
                         "ml" if ingredient["unit"] in {"ml", "l"} else "g")
            product = _proposal(ingredient["product_name"], base_unit, {}, country=country,
                owner_id=user_id, source={"provider": "unresolved_recipe_ingredient",
                    "status": "missing", "allergens_checked": False})
        resolved.append((ingredient, product))
    return resolved


async def materialize_recipe_ingredients(db, pairs):
    """Idempotent insert, no commit, and no promoting another user's product."""
    if not any(getattr(product, "_discovered_recipe_ingredient", False) for _, product in pairs):
        return pairs
    stored = {}
    factory = sqlite_insert if db.get_bind().dialect.name == "sqlite" else pg_insert
    for _, product in pairs:
        if not getattr(product, "_discovered_recipe_ingredient", False) or product.id in stored:
            continue
        values = {key: getattr(product, key) for key in (
            "id", "name", "brand", "unit", "default_quantity", "serving_quantity",
            "nutrition_per_100", "measure_options", "barcode", "review_status", "submitted_country_code", "created_by_user_id")}
        await db.execute(factory(Product).values(**values).on_conflict_do_nothing())
        actual = await db.get(Product, product.id)
        if actual is None and product.barcode:
            actual = (await db.execute(select(Product).where(Product.barcode == product.barcode,
                Product.review_status == "approved"))).scalar_one_or_none()
        if (actual is None or actual.review_status != product.review_status
                or actual.created_by_user_id != product.created_by_user_id
                or ingredient_key(actual.name) != ingredient_key(product.name)):
            raise ValueError("The discovered product conflicts with an existing catalogue identity")
        if not has_recipe_nutrition(actual):
            actual.nutrition_per_100 = product.nutrition_per_100
            if actual.serving_quantity is None and product.serving_quantity is not None:
                actual.serving_quantity = product.serving_quantity
                actual.measure_options = build_measure_options(actual.name, actual.unit, None, actual.serving_quantity)
        stored[product.id] = actual
    return [(ingredient, stored.get(product.id, product)) for ingredient, product in pairs]


async def refresh_incomplete_recipes_for_product(db, product_id):
    """After the owner fills in nutrition, remove stale 'missing' totals."""
    from sqlalchemy.orm import selectinload
    from app.models import Recipe, RecipeIngredient
    from app.services.nutrition_calculator import compute_recipe_nutrition_total

    await db.flush()
    result = await db.execute(select(Recipe).where(Recipe.id.in_(
        select(RecipeIngredient.recipe_id).where(RecipeIngredient.product_id == product_id)
    )).options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product)))
    for recipe in result.scalars().all():
        if (recipe.nutrition_total or {}).get("_incomplete"):
            recipe.nutrition_total = compute_recipe_nutrition_total(recipe.ingredients)
