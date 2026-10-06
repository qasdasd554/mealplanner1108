from app.db.fast_food_catalog import FAST_FOOD_PRODUCTS
from app.services.product_measures import build_measure_options, measure_to_base


def test_liquid_has_contextual_measures() -> None:
    options = build_measure_options("Mleko 2%", "l", 1, 1000)
    by_code = {option["code"]: option for option in options}

    assert by_code["opak"]["base_quantity"] == 1000
    assert by_code["lyzeczka"]["base_quantity"] == 5
    assert by_code["szklanka"]["base_quantity"] == 250
    assert measure_to_base(2, "szklanka", options) == (500.0, "ml")


def test_solid_does_not_receive_fake_glass_conversion() -> None:
    options = build_measure_options("Pierś z kurczaka", "g", 500, 500)
    codes = {option["code"] for option in options}

    assert {"opak", "g"} <= codes
    assert "porcja" not in codes
    assert "szklanka" not in codes
    assert "lyzeczka" not in codes


def test_flour_has_explicit_approximate_kitchen_measures() -> None:
    options = build_measure_options("Mąka pszenna", "kg", 1, 1000)
    by_code = {option["code"]: option for option in options}

    assert by_code["lyzeczka"]["base_quantity"] == 3
    assert by_code["szklanka"]["base_quantity"] == 160
    assert by_code["szklanka"]["approximate"] is True


def test_piece_uses_product_specific_weight_instead_of_100g_fallback() -> None:
    options = build_measure_options("Czosnek", "szt", 1, None)
    by_code = {option["code"]: option for option in options}

    assert by_code["szt"]["base_quantity"] == 5
    assert measure_to_base(2, "szt", options) == (10.0, "g")


def test_fast_food_catalog_has_real_portions_and_macros() -> None:
    brands = {row[1] for row in FAST_FOOD_PRODUCTS}
    assert {
        "McDonald's", "KFC", "Żabka Café", "Burger King",
        "MAX Premium Burgers", "North Fish",
    } <= brands
    assert len(FAST_FOOD_PRODUCTS) >= 36
    assert all(row[2] > 0 and row[3] > 0 for row in FAST_FOOD_PRODUCTS)
