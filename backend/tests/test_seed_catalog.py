"""Spójność katalogu produktów używanego w przepisach i skanowaniu."""

import httpx

from app.api.v1.products import ProductSubmission
from app.db.seed import (
    ADDITIONAL_RECIPE_PRODUCTS_100,
    AIRFRYER_RECIPES,
    NUTRITION_DATA,
    PRODUCT_BRANDS,
    PRODUCTS_DATA,
    RECIPES_DATA,
)
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

NEW_SAUCES_AND_SPICES = {
    "Sos teriyaki", "Sos sweet chili", "Sos barbecue", "Sos czosnkowy",
    "Sos curry mango", "Pesto rosso", "Pasta curry zielona", "Sambal oelek",
    "Ajvar", "Oliwki kalamata", "Jalapeño konserwowe", "Mleczko kokosowe light",
    "Pomidory krojone z bazylią", "Fasola cannellini", "Sos tikka masala",
    "Sos butter chicken", "Sos marinara", "Salsa pomidorowa", "Sos chipotle",
    "Sos ponzu", "Mirin", "Pasta tamaryndowa", "Pasta z trawy cytrynowej",
    "Pasta z czosnku i imbiru", "Krem balsamiczny", "Melasa z granatu",
    "Masło klarowane ghee", "Bulion grzybowy", "Fond drobiowy", "Papryka ostra",
    "Garam masala", "Cynamon cejloński", "Kardamon mielony", "Zioła prowansalskie",
    "Płatki chili", "Czarnuszka", "Sumak", "Za'atar", "Ras el hanout",
    "Przyprawa pięć smaków", "Anyż gwiazdkowy", "Kozieradka mielona",
    "Goździki mielone", "Szafran", "Estragon suszony", "Nasiona kopru włoskiego",
    "Agar", "Mąka tempura", "Tortilla kukurydziana", "Skrobia kukurydziana",
}


def test_25_new_recipe_products_are_complete() -> None:
    names = {row[0] for row in PRODUCTS_DATA}
    assert len(names) == len(PRODUCTS_DATA) == 390
    assert len(NEW_RECIPE_PRODUCTS) == 25
    assert NEW_RECIPE_PRODUCTS <= names
    assert NEW_RECIPE_PRODUCTS <= PRODUCT_BRANDS.keys()
    assert NEW_RECIPE_PRODUCTS <= NUTRITION_DATA.keys()
    assert len(NEW_SAUCES_AND_SPICES) == 50
    assert NEW_SAUCES_AND_SPICES <= names
    assert NEW_SAUCES_AND_SPICES <= PRODUCT_BRANDS.keys()
    assert NEW_SAUCES_AND_SPICES <= NUTRITION_DATA.keys()


def test_100_additional_recipe_products_are_complete_and_unique() -> None:
    product_names = [row[0] for row in PRODUCTS_DATA]
    additional_names = [row[0] for row in ADDITIONAL_RECIPE_PRODUCTS_100]

    assert len(additional_names) == len(set(additional_names)) == 100
    assert len(product_names) == len(set(product_names)) == 390
    assert {"Mandarynki", "Pomarańcze"} <= set(additional_names)
    assert set(additional_names) <= PRODUCT_BRANDS.keys()
    assert set(additional_names) <= NUTRITION_DATA.keys()


def test_25_airfryer_recipes_are_new_and_complete() -> None:
    airfryer_names = [recipe["name"] for recipe in AIRFRYER_RECIPES]
    existing_names = {
        recipe["name"].strip().casefold()
        for recipe in RECIPES_DATA
        if recipe not in AIRFRYER_RECIPES
    }

    assert len(AIRFRYER_RECIPES) == len(set(airfryer_names)) == 25
    assert len(RECIPES_DATA) == 137
    assert not {name.strip().casefold() for name in airfryer_names} & existing_names
    assert all("airfryer" in recipe["tags"] for recipe in AIRFRYER_RECIPES)
    assert all(recipe["instructions"] for recipe in AIRFRYER_RECIPES)
    assert all(recipe["ingredients"] for recipe in AIRFRYER_RECIPES)


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
