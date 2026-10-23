"""Account market is assigned once from device region, never from later logins."""

import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.v1 import auth
from app.api.v1.users import UserProfileUpdate
from app.models import Base, User
from app.schemas.user import UserResponse


@pytest.mark.parametrize(
    ("region", "expected"),
    [("GB", "GB"), ("gb", "GB"), (" UK ", "GB"), ("PL", "PL"),
     (None, "PL"), ("", "PL"), ("US", "PL"), (123, "PL"), ({}, "PL")],
)
def test_registration_region_is_limited_to_supported_markets(region, expected):
    from app.core.markets import registration_country

    assert registration_country(region) == expected


@pytest.mark.parametrize("field", ["country_code", "country", "device_region"])
@pytest.mark.parametrize("value", ["GB", "PL", None])
def test_profile_cannot_even_reassign_the_same_or_empty_country(field, value):
    with pytest.raises(ValidationError, match="rejestracji"):
        UserProfileUpdate.model_validate({field: value, "display_name": "Anna"})


def test_unrelated_legacy_extra_fields_still_work():
    assert UserProfileUpdate(display_name="Anna", unknown_legacy_field="x").display_name == "Anna"


def _profile(**kwargs):
    return dict(
        id=uuid4(), email="profile@example.com", household_size=1,
        created_at=datetime.now(timezone.utc), **kwargs,
    )


@pytest.mark.parametrize("extra", [{}, {"country_code": None}, {"country_code": "PL"}])
def test_legacy_response_defaults_to_poland(extra):
    assert UserResponse.model_validate(_profile(**extra)).country_code == "PL"


def test_british_response_keeps_country():
    assert UserResponse.model_validate(_profile(country_code="GB")).country_code == "GB"


@pytest.fixture
def user_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    engine.dispose()


def test_new_orm_account_defaults_to_poland(user_session):
    user = User(id=uuid4(), email="default@example.com", password_hash="test")
    user_session.add(user)
    user_session.commit()
    assert user.country_code == "PL"


def test_orm_rejects_country_change_but_allows_other_edits(user_session):
    user = User(id=uuid4(), email="british@example.com", password_hash="test", country_code="GB")
    user_session.add(user)
    user_session.commit()
    user_session.expire(user, ["country_code"])
    with pytest.raises(ValueError, match="rejestracji"):
        user.country_code = "PL"
    user.country_code = "GB"
    user.display_name = "Anna"
    user_session.commit()
    assert user.country_code == "GB"
    assert user.display_name == "Anna"


def test_orm_rejects_invalid_country_before_flush():
    with pytest.raises(ValueError):
        User(country_code="US")


class MigrationConnection:
    def __init__(self, connection):
        self.connection = connection
        self.dialect = connection.dialect

    async def execute(self, statement):
        return self.connection.execute(statement)


def test_migration_backfills_existing_polish_accounts_and_is_idempotent():
    from app.db.market_schema import ensure_account_market_schema

    engine = create_engine("sqlite:///:memory:")
    with engine.begin() as connection:
        connection.execute(text("CREATE TABLE users (id INTEGER PRIMARY KEY, display_name TEXT)"))
        connection.execute(text("INSERT INTO users (id, display_name) VALUES (1, 'Anna')"))
        adapter = MigrationConnection(connection)
        asyncio.run(ensure_account_market_schema(adapter))
        asyncio.run(ensure_account_market_schema(adapter))
        assert connection.execute(text("SELECT country_code FROM users WHERE id = 1")).scalar_one() == "PL"
        connection.execute(text("INSERT INTO users (id, country_code) VALUES (2, 'GB')"))
        asyncio.run(ensure_account_market_schema(adapter))
        assert connection.execute(text("SELECT country_code FROM users WHERE id = 2")).scalar_one() == "GB"
        connection.execute(text("INSERT INTO users (id) VALUES (3)"))
        assert connection.execute(text("SELECT country_code FROM users WHERE id = 3")).scalar_one() == "PL"
        connection.execute(text("UPDATE users SET display_name = 'Ania' WHERE id = 1"))
        connection.execute(text("UPDATE users SET country_code = 'GB' WHERE id = 2"))
        with pytest.raises(IntegrityError):
            connection.execute(text("UPDATE users SET country_code = 'PL' WHERE id = 2"))
        with pytest.raises(IntegrityError):
            connection.execute(text("INSERT INTO users (id, country_code) VALUES (4, 'US')"))
    engine.dispose()


@pytest.mark.asyncio
async def test_postgres_migration_emits_immutable_trigger_and_check():
    from app.db.market_schema import ensure_account_market_schema

    connection = SimpleNamespace(dialect=SimpleNamespace(name="postgresql"), execute=AsyncMock())
    await ensure_account_market_schema(connection)
    statements = "\n".join(str(call.args[0]) for call in connection.execute.await_args_list)
    assert "DEFAULT 'PL'" in statements
    assert "CHECK (country_code IN ('PL', 'GB'))" in statements
    assert "NEW.country_code IS DISTINCT FROM OLD.country_code" in statements
    assert "BEFORE UPDATE OF country_code ON users" in statements
    assert "tgrelid = 'users'::regclass" in statements


def _result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


@pytest.fixture
def auth_mocks(monkeypatch):
    monkeypatch.setattr(auth.settings, "UK_MARKET_ENABLED", True)
    monkeypatch.setattr(auth, "verify_turnstile_token", AsyncMock())
    monkeypatch.setattr(auth, "enforce_signup_rate_limit", lambda request: None)
    monkeypatch.setattr(auth, "enforce_google_auth_rate_limit", lambda request: None)
    monkeypatch.setattr(auth, "get_password_hash", lambda value: "hashed")
    monkeypatch.setattr(auth, "generate_unique_display_name", AsyncMock(return_value="Anna"))
    monkeypatch.setattr(auth, "send_verification_email", AsyncMock())
    monkeypatch.setattr(auth, "_session_tokens", lambda user: {"access_token": "test"})
    monkeypatch.setattr(auth.google_id_token, "verify_oauth2_token", lambda *args: {
        "email": "anna@example.com", "email_verified": True, "name": "Anna",
    })
    monkeypatch.setattr(auth, "verify_apple_identity_token", AsyncMock(return_value={
        "email": "anna@example.com", "sub": "apple-anna",
    }))


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["register", "google", "apple"])
@pytest.mark.parametrize(("region", "expected"), [("GB", "GB"), (None, "PL"), ("US", "PL")])
async def test_all_registration_methods_assign_region_only_to_new_accounts(auth_mocks, kind, region, expected):
    body = {"email": "anna@example.com", "password": "password123", "device_region": region,
            "country_code": "GB", "country": "GB",
            "id_token": "google-token", "identity_token": "apple-token"}
    request = SimpleNamespace(json=AsyncMock(return_value=body), headers={}, client=None)
    db = AsyncMock()
    db.add = MagicMock()
    db.execute.side_effect = [_result(None), _result(None)]
    result = await getattr(auth, {"register": "register", "google": "google_login", "apple": "apple_login"}[kind])(request, db)
    assert result["access_token"] == "test"
    created = db.add.call_args.args[0]
    assert created.country_code == expected


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["google", "apple", "apple_link"])
@pytest.mark.parametrize(("stored", "device"), [("PL", "GB"), ("GB", "PL")])
async def test_existing_social_account_never_changes_country(auth_mocks, kind, stored, device):
    existing = User(id=uuid4(), email="anna@example.com", password_hash="test", country_code=stored, is_banned=False)
    request = SimpleNamespace(json=AsyncMock(return_value={
        "id_token": "google-token", "identity_token": "apple-token", "device_region": device,
    }), headers={}, client=None)
    db = AsyncMock()
    db.add = MagicMock()
    db.execute.side_effect = ([_result(None), _result(existing)] if kind == "apple_link" else [_result(existing)])
    await (auth.google_login if kind == "google" else auth.apple_login)(request, db)
    assert existing.country_code == stored
    db.add.assert_not_called()


@pytest.mark.parametrize("region", ["GB", "UK", " gb "])
def test_uk_signup_requires_explicit_server_release_switch(monkeypatch, region):
    from fastapi import HTTPException
    from app.core.markets import signup_country

    monkeypatch.setattr(auth.settings, "UK_MARKET_ENABLED", False)
    with pytest.raises(HTTPException) as error:
        signup_country(region)
    assert error.value.status_code == 503


@pytest.mark.parametrize("region", ["PL", None, "US", ""])
def test_polish_signup_is_not_changed_by_uk_rollout_switch(monkeypatch, region):
    from app.core.markets import signup_country

    monkeypatch.setattr(auth.settings, "UK_MARKET_ENABLED", False)
    assert signup_country(region) == "PL"


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["register", "google", "apple"])
async def test_disabled_uk_signup_never_persists_account(auth_mocks, monkeypatch, kind):
    from fastapi import HTTPException

    monkeypatch.setattr(auth.settings, "UK_MARKET_ENABLED", False)
    request = SimpleNamespace(json=AsyncMock(return_value={
        "email": "anna@example.com", "password": "password123", "device_region": "GB",
        "id_token": "google-token", "identity_token": "apple-token",
    }), headers={}, client=None)
    db = AsyncMock()
    db.add = MagicMock()
    db.execute.side_effect = [_result(None), _result(None)]
    with pytest.raises(HTTPException) as error:
        await getattr(auth, {"register": "register", "google": "google_login", "apple": "apple_login"}[kind])(request, db)
    assert error.value.status_code == 503
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["google", "apple", "apple_link"])
async def test_release_switch_never_prevents_existing_account_login(auth_mocks, monkeypatch, kind):
    monkeypatch.setattr(auth.settings, "UK_MARKET_ENABLED", False)
    await test_existing_social_account_never_changes_country(
        auth_mocks, kind, "PL", "GB"
    )
