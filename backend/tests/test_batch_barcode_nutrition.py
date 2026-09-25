"""Regresje zapisu makro po seryjnym skanowaniu kodów kreskowych."""

from app.api.v1.pantry import AddPantryBarcodeRequest, merge_scanned_nutrition


def test_batch_request_keeps_nutrition_recognized_on_phone() -> None:
    payload = AddPantryBarcodeRequest(
        barcode="5901234123457",
        quantity=400,
        unit="g",
        batch=True,
        name="Jogurt naturalny",
        brand="Przykładowa marka",
        kcal_per_100=62,
        protein_per_100=4.2,
        fat_per_100=2,
        carbs_per_100=6.1,
    )

    assert payload.kcal_per_100 == 62
    assert payload.protein_per_100 == 4.2
    assert payload.fat_per_100 == 2
    assert payload.carbs_per_100 == 6.1


def test_scanned_nutrition_replaces_legacy_zero_placeholder() -> None:
    merged, changed = merge_scanned_nutrition(
        {"kcal": 0, "protein": 0, "fat": 0, "carbs": 0, "fiber": 0},
        {"kcal": 62, "protein": 4.2, "fat": 2, "carbs": 6.1},
    )

    assert changed
    assert merged == {
        "kcal": 62,
        "protein": 4.2,
        "fat": 2,
        "carbs": 6.1,
        "fiber": 0,
    }


def test_scanned_nutrition_only_fills_missing_fields_of_verified_product() -> None:
    merged, changed = merge_scanned_nutrition(
        {"kcal": 100, "protein": 5, "fat": None, "carbs": 12},
        {"kcal": 120, "protein": 6, "fat": 3, "carbs": 15},
    )

    assert changed
    assert merged["kcal"] == 100
    assert merged["protein"] == 5
    assert merged["fat"] == 3
    assert merged["carbs"] == 12
