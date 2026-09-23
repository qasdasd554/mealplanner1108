import pytest

from app.services.product_label_ai import (
    ProductLabelRecognitionError,
    _parse_label_json,
)


def test_parses_confirmable_product_label_without_inventing_missing_values() -> None:
    result = _parse_label_json(
        """{
          "name": "Jogurt naturalny",
          "brand": "Przykładowa marka",
          "unit": "g",
          "serving_quantity": "180",
          "kcal_per_100": 62,
          "protein_per_100": "4,2",
          "fat_per_100": null,
          "carbs_per_100": 6.1
        }""",
        "5901234123457",
    )
    assert result["barcode"] == "5901234123457"
    assert result["serving_quantity"] == 180
    assert result["protein_per_100"] == 4.2
    assert result["fat_per_100"] is None


def test_rejects_label_when_front_photo_has_no_product_name() -> None:
    with pytest.raises(ProductLabelRecognitionError):
        _parse_label_json('{"name": null, "brand": null}', "5901234123457")


def test_discards_impossible_macro_instead_of_saving_it() -> None:
    result = _parse_label_json(
        '{"name":"Produkt","unit":"g","protein_per_100":999}',
        "5901234123457",
    )
    assert result["protein_per_100"] is None
