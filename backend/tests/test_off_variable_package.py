"""A source's variable-weight range is not a proven single package mass."""
import pytest

from app.services.barcode_lookup import _result_from_off_product


@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("text", ["300/350g", "300-350 g", "300–350g", "300 g to 350 g", "0.3 / 0.35 kg"])
def test_weight_range_is_not_offered_as_a_fixed_package(country, text):
    result = _result_from_off_product({"product_name": "Cucumber", "quantity": text,
        "product_quantity": 350, "product_quantity_unit": "g",
        "nutriments": {"energy-kcal_100g": 15, "proteins_100g": 1,
            "fat_100g": 0, "carbohydrates_100g": 3}}, country_code=country)
    assert result.serving_quantity is None
    assert result.kcal_per_100 == 15 and result.unit == "g"


@pytest.mark.parametrize("text,expected", [("350 g", 350), ("2 x 150 g", 300), ("1,5 l", 1500)])
def test_explicit_metric_packages_and_multipacks_still_work(text, expected):
    result = _result_from_off_product({"product_name": "Synthetic food", "quantity": text})
    assert result.serving_quantity == expected
