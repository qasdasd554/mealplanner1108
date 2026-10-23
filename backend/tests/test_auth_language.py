import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException, Request

from app.api.v1 import auth


def request(payload):
    data = json.dumps(payload).encode()
    async def receive():
        return {'type': 'http.request', 'body': data, 'more_body': False}
    return Request({'type': 'http', 'method': 'POST', 'path': '/', 'headers': [],
                    'client': ('127.0.0.1', 1000)}, receive)


@pytest.fixture(autouse=True)
def no_external_services(monkeypatch):
    monkeypatch.setattr(auth, 'verify_turnstile_token', AsyncMock())
    monkeypatch.setattr(auth, 'enforce_signup_rate_limit', lambda *_: None)
    monkeypatch.setattr(auth, 'enforce_login_rate_limit', lambda *_: 'synthetic-rate-key')
    monkeypatch.setattr(auth, 'enforce_google_auth_rate_limit', lambda *_: None)
    monkeypatch.setattr(auth, 'enforce_password_reset_rate_limit', lambda *_: None)
    monkeypatch.setattr(auth.login_limiter, 'register_failure', lambda *_: None)
    monkeypatch.setattr(auth, 'send_password_reset_email', AsyncMock())


def db(value=None):
    return SimpleNamespace(execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: value)), commit=AsyncMock())


@pytest.mark.parametrize('payload', [[], 123, None])
def test_non_object_json_is_a_400_not_a_server_exception(payload):
    with pytest.raises(HTTPException) as failure:
        asyncio.run(auth.get_parsed_body(request(payload)))
    assert failure.value.status_code == 400


@pytest.mark.parametrize('country', ['PL', 'GB'])
@pytest.mark.parametrize('route,payload,english', [
    ('login', {}, 'Email and password are required'),
    ('register', {}, 'Email and password are required'),
    ('register', {'email': 'bad', 'password': 'synthetic-password'}, 'Invalid email address format'),
    ('register', {'email': 'synthetic@example.invalid', 'password': 'a'}, 'Password must contain at least 8 characters'),
    ('register', {'email': 'synthetic@example.invalid', 'password': 'synthetic', 'display_name': 'x' * 201}, 'Display name is too long (maximum 200 characters)'),
    ('google_login', {}, 'A Google id_token is required'),
    ('apple_login', {}, 'An Apple identity_token is required'),
    ('reset_password', {}, 'Invalid or expired password reset code.'),
    ('reset_password', {'email': 'synthetic@example.invalid', 'code': '123456', 'new_password': 'a'}, 'New password must contain at least 8 characters'),
])
def test_pre_auth_messages_follow_ui_hint_without_country_reassignment(route, payload, english, country):
    payload = {**payload, 'device_region': country}
    with pytest.raises(HTTPException) as failure:
        asyncio.run(getattr(auth, route)(request(payload), db=db()))
    assert failure.value.status_code == 400
    if country == 'GB':
        assert failure.value.detail == english
    else:
        assert failure.value.detail != english


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_wrong_credentials_do_not_disclose_account_country(country, monkeypatch):
    monkeypatch.setattr(auth, 'verify_password', lambda *_: False)
    messages = []
    for account in [None, SimpleNamespace(password_hash='synthetic', country_code='PL')]:
        with pytest.raises(HTTPException) as failure:
            asyncio.run(auth.login(request({'email': 'synthetic@example.invalid', 'password': 'synthetic', 'device_region': country}), db=db(account)))
        assert failure.value.status_code == 401
        messages.append(failure.value.detail)
    assert messages[0] == messages[1]
    assert messages[0] == ('Invalid email or password' if country == 'GB' else 'Nieprawidłowy e-mail lub hasło')


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_password_reset_response_is_identical_for_unknown_and_known_accounts(country):
    known = SimpleNamespace(email='synthetic@example.invalid', display_name='Original user', country_code='PL')
    body = {'email': known.email, 'device_region': country}
    unknown_result = asyncio.run(auth.forgot_password(request(body), db=db()))
    known_result = asyncio.run(auth.forgot_password(request(body), db=db(known)))
    assert unknown_result == known_result
    if country == 'GB':
        assert known_result['detail'] == 'If this email address is registered, we have sent a password reset code.'
    assert known.country_code == 'PL'
    assert auth.send_password_reset_email.call_args.kwargs['country_code'] == 'PL'


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_email_verification_uses_the_persisted_country(country):
    user = SimpleNamespace(country_code=country, is_email_verified=False, email_verification_code=None)
    with pytest.raises(HTTPException) as failure:
        asyncio.run(auth.verify_email(request({'code': '123456', 'device_region': 'GB' if country == 'PL' else 'PL'}), current_user=user, db=db()))
    assert failure.value.status_code == 400
    assert failure.value.detail == ('Invalid or expired verification code.' if country == 'GB' else 'Nieprawidłowy albo wygasły kod weryfikacyjny.')


@pytest.mark.parametrize('country', ['PL', 'GB'])
@pytest.mark.parametrize('route', ['register', 'login', 'google_login', 'apple_login'])
def test_captcha_remains_before_credentials_and_preserves_status_and_headers(country, route, monkeypatch):
    message = 'Potwierdź, że nie jesteś robotem.'
    monkeypatch.setattr(auth, 'verify_turnstile_token', AsyncMock(side_effect=HTTPException(
        status_code=400, detail=message, headers={'X-Synthetic-Check': 'preserved'})))
    database = db()
    with pytest.raises(HTTPException) as failure:
        asyncio.run(getattr(auth, route)(request({'device_region': country}), db=database))
    assert failure.value.status_code == 400
    assert failure.value.detail == ('Please confirm that you are not a robot.' if country == 'GB' else message)
    assert failure.value.headers == {'X-Synthetic-Check': 'preserved'}
    database.execute.assert_not_awaited()
    auth.verify_turnstile_token.assert_awaited_once()


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_rejected_captcha_does_not_become_an_accepted_login(country, monkeypatch):
    message = 'Weryfikacja nie powiodła się. Spróbuj ponownie.'
    monkeypatch.setattr(auth, 'verify_turnstile_token', AsyncMock(side_effect=HTTPException(status_code=403, detail=message)))
    with pytest.raises(HTTPException) as failure:
        asyncio.run(auth.login(request({'device_region': country}), db=db()))
    assert failure.value.status_code == 403
    assert failure.value.detail == ('Verification failed. Please try again.' if country == 'GB' else message)


def test_double_encoded_legacy_json_object_is_still_supported():
    assert asyncio.run(auth.get_parsed_body(request(json.dumps({'email': 'synthetic@example.invalid'})))) == {'email': 'synthetic@example.invalid'}
