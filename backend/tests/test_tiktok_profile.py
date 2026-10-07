import pytest
from pydantic import ValidationError

from app.api.v1.users import UserProfileUpdate
from app.schemas.user import UserResponse


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("@meal.planner", "meal.planner"),
        ("https://www.tiktok.com/@meal_planner/", "meal_planner"),
        ("", None),
    ],
)
def test_tiktok_username_is_normalized(raw: str, expected: str | None) -> None:
    payload = UserProfileUpdate(tiktok_username=raw)
    assert payload.tiktok_username == expected


@pytest.mark.parametrize("raw", ["a", "../profil", "@profil..test", "tiktok.com/x"])
def test_tiktok_username_rejects_unsafe_values(raw: str) -> None:
    with pytest.raises(ValidationError):
        UserProfileUpdate(tiktok_username=raw)


def test_profile_response_exposes_tiktok_username() -> None:
    assert "tiktok_username" in UserResponse.model_fields
