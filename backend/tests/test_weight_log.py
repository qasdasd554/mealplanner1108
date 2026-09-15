"""Testy kontraktu dziennika masy ciała."""

import pytest
from pydantic import ValidationError

from app.api.v1.wellness import WeightLogUpsert, router


def test_weight_log_accepts_decimal_kilograms() -> None:
    assert WeightLogUpsert(weight_kg=72.4).weight_kg == 72.4


@pytest.mark.parametrize("invalid_weight", [0, -1, 401])
def test_weight_log_rejects_invalid_weight(invalid_weight: float) -> None:
    with pytest.raises(ValidationError):
        WeightLogUpsert(weight_kg=invalid_weight)


def test_fixed_weight_route_precedes_dynamic_date_route() -> None:
    get_paths = [
        route.path
        for route in router.routes
        if "GET" in getattr(route, "methods", set())
    ]
    assert get_paths.index("/weight") < get_paths.index("/{log_date}")
    assert get_paths.index("/stats/overview") < get_paths.index("/{log_date}")
