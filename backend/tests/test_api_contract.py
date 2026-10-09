"""Regresje kontraktu tras używanych bezpośrednio przez aplikację."""

from pathlib import Path

from app.api.v1.users import AdminUserEntry
from app.schemas.meal_plan import MealPlanGenerateRequest
from app.core.release_version import (
    BACKEND_ONLY_FALLBACK_VERSION,
    parse_pubspec_version,
)
from app.main import app


def test_statistics_endpoint_is_present_in_openapi() -> None:
    paths = app.openapi()["paths"]
    assert "/api/v1/wellness/stats/overview" in paths


def test_recent_food_log_endpoint_is_present_in_openapi() -> None:
    assert "/api/v1/food-log/recent" in app.openapi()["paths"]


def test_meal_plan_pantry_choice_is_explicit_and_backwards_compatible() -> None:
    request = MealPlanGenerateRequest(store_id="00000000-0000-0000-0000-000000000001")
    assert request.include_pantry is True
    request_without_pantry = MealPlanGenerateRequest(
        store_id="00000000-0000-0000-0000-000000000001",
        include_pantry=False,
    )
    assert request_without_pantry.include_pantry is False


def test_scanned_products_and_custom_shopping_items_are_exposed() -> None:
    paths = app.openapi()["paths"]
    assert "/api/v1/products/scanned" in paths
    assert "/api/v1/products/search-by-name" in paths
    assert "/api/v1/shopping-lists/{list_id}/items/custom" in paths
    assert "/api/v1/shopping-lists/empty" in paths


def test_friendship_routes_are_exposed() -> None:
    paths = app.openapi()["paths"]
    assert "/api/v1/friends/" in paths
    assert "/api/v1/friends/invitations" in paths
    assert "/api/v1/friends/invitations/{connection_id}/accept" in paths
    assert "/api/v1/friends/{friend_id}/recipes" in paths
    assert "/api/v1/friends/{friend_id}/shopping-lists" in paths


def test_openapi_operation_ids_are_unique() -> None:
    operation_ids = [
        operation["operationId"]
        for path in app.openapi()["paths"].values()
        for operation in path.values()
        if isinstance(operation, dict) and "operationId" in operation
    ]
    assert len(operation_ids) == len(set(operation_ids))


def test_backend_release_matches_mobile_build() -> None:
    pubspec = Path(__file__).resolve().parents[2] / "frontend" / "pubspec.yaml"
    mobile_version = parse_pubspec_version(pubspec.read_text(encoding="utf-8"))
    assert app.version == mobile_version
    assert BACKEND_ONLY_FALLBACK_VERSION == mobile_version


def test_mobile_version_parser_rejects_invalid_value() -> None:
    try:
        parse_pubspec_version("version: latest")
    except ValueError:
        pass
    else:
        raise AssertionError("Nieprawidłowa wersja nie może zostać zaakceptowana")


def test_admin_user_contract_contains_both_avatar_variants() -> None:
    assert {"avatar", "avatar_photo_base64"} <= AdminUserEntry.model_fields.keys()


def test_weekly_automation_routes_are_exposed() -> None:
    paths = app.openapi()["paths"]
    assert "/api/v1/meal-plans/automation" in paths
    assert "/api/v1/meal-plans/automation/run-now" in paths


def test_admin_user_contract_contains_client_version() -> None:
    assert {"platform", "app_version"} <= AdminUserEntry.model_fields.keys()
