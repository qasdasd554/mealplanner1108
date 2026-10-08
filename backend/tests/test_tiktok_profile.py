from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from app.api.v1.users import UserProfileUpdate, ensure_tiktok_premium_access
from app.models.user import User
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


def _user(*, active_premium: bool) -> User:
    return User(
        id=uuid4(),
        email="autor@example.com",
        password_hash="test",
        household_size=1,
        tiktok_username="autor.kuchni",
        is_email_verified=True,
        role="user",
        is_premium=True,
        premium_points=0,
        premium_expires_at=(
            datetime.now(timezone.utc) + timedelta(days=7)
            if active_premium
            else datetime.now(timezone.utc) - timedelta(seconds=1)
        ),
        created_at=datetime.now(timezone.utc),
    )


def test_profile_response_hides_tiktok_after_premium_expires() -> None:
    response = UserResponse.model_validate(_user(active_premium=False))

    assert response.has_premium_access is False
    assert response.tiktok_username is None


def test_profile_response_keeps_tiktok_for_active_premium() -> None:
    response = UserResponse.model_validate(_user(active_premium=True))

    assert response.has_premium_access is True
    assert response.tiktok_username == "autor.kuchni"


def test_standard_user_cannot_add_tiktok_username() -> None:
    with pytest.raises(HTTPException) as exc_info:
        ensure_tiktok_premium_access(
            {"tiktok_username": "autor.kuchni"},
            _user(active_premium=False),
        )

    assert exc_info.value.status_code == 403


def test_standard_user_can_remove_saved_tiktok_username() -> None:
    ensure_tiktok_premium_access(
        {"tiktok_username": None},
        _user(active_premium=False),
    )
