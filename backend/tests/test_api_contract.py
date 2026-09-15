"""Regresje kontraktu tras używanych bezpośrednio przez aplikację."""

from app.main import app


def test_statistics_endpoint_is_present_in_openapi() -> None:
    paths = app.openapi()["paths"]
    assert "/api/v1/wellness/stats/overview" in paths


def test_openapi_operation_ids_are_unique() -> None:
    operation_ids = [
        operation["operationId"]
        for path in app.openapi()["paths"].values()
        for operation in path.values()
        if isinstance(operation, dict) and "operationId" in operation
    ]
    assert len(operation_ids) == len(set(operation_ids))


def test_backend_release_matches_mobile_build() -> None:
    assert app.version == "1.0.14"
