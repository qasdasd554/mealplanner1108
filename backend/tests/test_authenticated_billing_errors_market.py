"""Account-language guard copy never changes authentication or payment outcomes."""

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.api import deps
from app.api.v1 import billing, users


def _user(country, **changes):
    values = dict(id=uuid4(), country_code=country, role="user", is_premium=False,
        premium_product_id=None, premium_expires_at=None, premium_points=4,
        is_email_verified=False, is_banned=False, ban_reason=None)
    return SimpleNamespace(**(values | changes))


def _db(value=None):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return SimpleNamespace(execute=AsyncMock(return_value=result), add=MagicMock(),
        commit=AsyncMock(), refresh=AsyncMock())


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("guard,polish,english", [
    ("email", "Potwierdź swój adres e-mail, aby korzystać z aplikacji.", "Verify your email address to use the app."),
    ("admin", "Ta operacja wymaga uprawnień administratora", "This action requires administrator permissions."),
    ("premium", "Ta funkcja wymaga aktywnej subskrypcji Premium", "This feature requires an active Premium subscription."),
])
async def test_authenticated_guard_uses_saved_country_not_request_locale(monkeypatch, country, guard, polish, english):
    user, db = _user(country), _db()
    refresh = AsyncMock()
    monkeypatch.setattr("app.services.subscription_sync.refresh_subscription_if_needed", refresh)
    with pytest.raises(HTTPException) as failure:
        if guard == "email":
            await deps.get_current_user(user)
        elif guard == "admin":
            await deps.get_current_admin(user)
        else:
            await deps.get_current_premium(user, db)
    assert failure.value.status_code == 403
    assert failure.value.detail == (english if country == "GB" else polish)
    if guard == "premium":
        refresh.assert_awaited_once_with(db, user)
    else:
        refresh.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("reason", [None, "Original moderator reason — keep exactly"])
async def test_banned_account_default_is_localised_but_entered_reason_is_not(monkeypatch, country, reason):
    user = _user(country, is_banned=True, ban_reason=reason)
    db = _db(user)
    monkeypatch.setattr(deps.jwt, "decode", lambda *args, **kwargs: {"sub": str(user.id), "type": "access"})
    request = Request({"type": "http", "headers": [(b"accept-language", b"pl" if country == "GB" else b"en-GB")]})
    with pytest.raises(HTTPException) as failure:
        await deps.get_current_user_allow_unverified(request, "synthetic-token", db)
    assert failure.value.status_code == 403
    assert failure.value.detail == (reason or ("This account has been blocked by an administrator." if country == "GB"
        else "To konto zostało zablokowane przez administratora."))
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("payload", [{}, {"sub": "invalid"}, {"sub": str(uuid4()), "type": "refresh"}, {"sub": str(uuid4()), "type": "access"}])
async def test_unauthenticated_failures_keep_generic_credentials_response(monkeypatch, payload):
    db = _db()
    monkeypatch.setattr(deps.jwt, "decode", lambda *args, **kwargs: payload)
    request = Request({"type": "http", "headers": [(b"accept-language", b"en-GB"), (b"x-device-region", b"GB")]})
    with pytest.raises(HTTPException) as failure:
        await deps.get_current_user_allow_unverified(request, "synthetic-token", db)
    assert failure.value.status_code == 401
    assert failure.value.detail == "Nie udało się zweryfikować poświadczeń"
    assert failure.value.headers == {"WWW-Authenticate": "Bearer"}
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_successful_authenticated_guards_still_return_the_same_user(monkeypatch, country):
    user = _user(country, role="admin", is_email_verified=True)
    refresh = AsyncMock()
    monkeypatch.setattr("app.services.subscription_sync.refresh_subscription_if_needed", refresh)
    assert await deps.get_current_user(user) is user
    assert await deps.get_current_admin(user) is user
    assert await deps.get_current_premium(user, object()) is user
    refresh.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("platform", ["android", "ios"])
@pytest.mark.parametrize("case", ["unknown_subscription", "inactive_subscription", "unknown_points", "unconfirmed_points", "spent_points"])
async def test_billing_fixed_rejections_keep_verification_and_awards_unchanged(monkeypatch, country, platform, case):
    user = _user(country)
    db = _db(SimpleNamespace(transaction_id="synthetic-token") if case == "spent_points" else None)
    verify_sub = AsyncMock(return_value={"is_active": False})
    verify_points = AsyncMock(return_value={"is_purchased": case == "spent_points", "is_consumed": case == "spent_points"})
    consume = AsyncMock()
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_subscription", verify_sub)
    monkeypatch.setattr("app.services.google_play_billing.verify_subscription_purchase", verify_sub)
    monkeypatch.setattr("app.services.apple_app_store.verify_apple_consumable", verify_points)
    monkeypatch.setattr("app.services.google_play_billing.verify_consumable_purchase", verify_points)
    monkeypatch.setattr("app.services.google_play_billing.consume_purchase", consume)
    product_id = "unknown" if case.startswith("unknown") else "premium_monthly" if case.endswith("subscription") else "points_10"
    payload = billing.VerifyPurchaseRequest(purchase_token="synthetic-token", product_id=product_id, platform=platform)
    with pytest.raises(HTTPException) as failure:
        if case.endswith("subscription"):
            await billing.verify_purchase(payload, user, db)
        else:
            await billing.verify_points_purchase(payload, user, db)
    messages = {
        "unknown_subscription": (400, "Nieznany identyfikator subskrypcji.", "Unknown subscription product."),
        "inactive_subscription": (422, "Ten zakup nie jest aktywną subskrypcją (może być wygasła albo anulowana).", "This purchase is not an active subscription (it may have expired or been cancelled)."),
        "unknown_points": (400, "Nieznany pakiet punktów.", "Unknown points package."),
        "unconfirmed_points": (422, "Ten zakup nie został potwierdzony przez " + ("Apple." if platform == "ios" else "Google."), "This purchase was not confirmed by " + ("Apple." if platform == "ios" else "Google.")),
        "spent_points": (422, "Ten zakup został już wcześniej rozliczony.", "This purchase has already been processed."),
    }
    status, polish, english = messages[case]
    assert failure.value.status_code == status
    assert failure.value.detail == (english if country == "GB" else polish)
    assert user.is_premium is False and user.premium_points == 4
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
    consume.assert_not_awaited()
    if case.startswith("unknown"):
        verify_sub.assert_not_awaited()
        verify_points.assert_not_awaited()
    elif case.endswith("subscription"):
        verify_sub.assert_awaited_once_with("synthetic-token", "premium_monthly")
    else:
        verify_points.assert_awaited_once_with("synthetic-token", "points_10")


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("platform", ["android", "ios"])
async def test_external_verification_errors_are_not_heuristically_translated(monkeypatch, country, platform):
    from app.services import apple_app_store, google_play_billing
    module = apple_app_store if platform == "ios" else google_play_billing
    name = "verify_apple_subscription" if platform == "ios" else "verify_subscription_purchase"
    message = "Original verification failure / opaque upstream reason"
    verification = AsyncMock(side_effect=module.PurchaseVerificationError(message))
    monkeypatch.setattr(module, name, verification)
    db, user = _db(), _user(country)
    with pytest.raises(HTTPException) as failure:
        await billing.verify_purchase(billing.VerifyPurchaseRequest(purchase_token="synthetic-token",
            product_id="premium_monthly", platform=platform), user, db)
    assert failure.value.status_code == 422 and failure.value.detail == message
    assert user.is_premium is False and user.premium_points == 4
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
async def test_subscription_refresh_still_happens_before_premium_guard(monkeypatch, country):
    user = _user(country, premium_product_id="premium_monthly")
    db = _db()
    async def renewed(database, account):
        assert database is db and account is user
        user.is_premium = True
        user.premium_expires_at = datetime.now(timezone.utc) + timedelta(days=30)
    refresh = AsyncMock(side_effect=renewed)
    monkeypatch.setattr("app.services.subscription_sync.refresh_subscription_if_needed", refresh)
    assert await deps.get_current_premium(user, db) is user
    refresh.assert_awaited_once_with(db, user)


@pytest.mark.asyncio
@pytest.mark.parametrize("country", ["PL", "GB"])
@pytest.mark.parametrize("field,value,polish,english", [
    ("weight_kg", 0, "Nieprawidłowa waga.", "Invalid weight."),
    ("height_cm", 0, "Nieprawidłowy wzrost.", "Invalid height."),
    ("age", 0, "Nieprawidłowy wiek.", "Invalid age."),
    ("gender", "unknown", "Płeć musi być 'male' albo 'female'.", "Gender must be 'male' or 'female'."),
    ("activity_level", "unknown", "Nieznany poziom aktywności — dozwolone: sedentary, light, moderate, active, very_active.",
        "Unknown activity level — allowed values: sedentary, light, moderate, active, very_active."),
])
async def test_calculator_defensive_service_errors_use_authenticated_country(country, field, value, polish, english):
    # Bypass request-model validation only to exercise the existing defensive
    # service catch; this does not relax the HTTP request schema.
    data = dict(weight_kg=70, height_cm=175, age=30, gender="male", activity_level="moderate")
    data[field] = value
    payload = users.CalorieCalculatorRequest.model_construct(**data)
    with pytest.raises(HTTPException) as failure:
        await users.calculate_calorie_needs_endpoint(payload, _user(country))
    assert failure.value.status_code == 400
    assert failure.value.detail == (english if country == "GB" else polish)


@pytest.mark.asyncio
async def test_calculator_results_and_canonical_values_remain_identical_between_markets():
    payload = users.CalorieCalculatorRequest(weight_kg=70, height_cm=175, age=30,
        gender="male", activity_level="moderate")
    polish = await users.calculate_calorie_needs_endpoint(payload, _user("PL"))
    english = await users.calculate_calorie_needs_endpoint(payload, _user("GB"))
    assert polish == english == {"maintenance": 2556, "weight_loss": 2056, "weight_gain": 3056}
