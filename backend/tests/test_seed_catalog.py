"""Spójność katalogu produktów używanego w przepisach i skanowaniu."""

import httpx

from app.api.v1.products import ProductSubmission
from app.db.seed import NUTRITION_DATA, PRODUCT_BRANDS, PRODUCTS_DATA, RECIPES_DATA
from app.services.push import _fcm_error_code


NEW_RECIPE_PRODUCTS = {
    "Ciasto francuskie",
    "Ciasto filo",
    "Ciasto na pizzę",
    "Gnocchi ziemniaczane",
    "Tortellini z serem",
    "Bułka tarta panko",
    "Mleko bez laktozy",
    "Maślanka naturalna",
    "Burrata",
    "Ser halloumi",
    "Mleko skondensowane słodzone",
    "Mięso mielone z indyka",
    "Pierś z kaczki",
    "Pstrąg filet",
    "Małże mrożone",
    "Edamame mrożone",
    "Kukurydza mrożona",
    "Owoce leśne mrożone",
    "Puree z dyni",
    "Pasta miso",
    "Pasta gochujang",
    "Harissa",
    "Herbatniki maślane",
    "Biszkopty",
    "Budyń waniliowy",
}


def test_25_new_recipe_products_are_complete() -> None:
    names = {row[0] for row in PRODUCTS_DATA}
    assert len(names) == len(PRODUCTS_DATA) == 240
    assert len(NEW_RECIPE_PRODUCTS) == 25
    assert NEW_RECIPE_PRODUCTS <= names
    assert NEW_RECIPE_PRODUCTS <= PRODUCT_BRANDS.keys()
    assert NEW_RECIPE_PRODUCTS <= NUTRITION_DATA.keys()


def test_every_recipe_uses_existing_catalog_products() -> None:
    product_names = {row[0] for row in PRODUCTS_DATA}
    missing = {
        ingredient[0]
        for recipe in RECIPES_DATA
        for ingredient in recipe["ingredients"]
        if ingredient[0] not in product_names
    }
    assert missing == set()


def test_submitted_product_price_is_optional() -> None:
    submission = ProductSubmission(name="Ciasto francuskie")
    assert submission.price is None


def test_only_explicit_unregistered_fcm_error_is_stale() -> None:
    unregistered = httpx.Response(
        404,
        json={"error": {"details": [{"errorCode": "UNREGISTERED"}]}},
    )
    apns_configuration_error = httpx.Response(
        404,
        json={"error": {"details": [{"errorCode": "THIRD_PARTY_AUTH_ERROR"}]}},
    )
    assert _fcm_error_code(unregistered) == "UNREGISTERED"
    assert _fcm_error_code(apns_configuration_error) == "THIRD_PARTY_AUTH_ERROR"
