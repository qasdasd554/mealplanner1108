"""Diagnostic codes preserve CAPTCHA and never log credentials or account data."""
import asyncio
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException

from app.api.v1 import auth
from tests.test_auth_language import request, db, no_external_services


@pytest.mark.parametrize('country', ['PL', 'GB'])
@pytest.mark.parametrize('status,token,reason', [
    (400, None, 'captcha_missing'), (403, 'private-challenge', 'captcha_rejected'),
])
def test_captcha_reason_is_safe_and_does_not_relax_auth(country, status, token, reason, monkeypatch, caplog):
    monkeypatch.setattr(auth, 'verify_turnstile_token', AsyncMock(side_effect=HTTPException(
        status_code=status, detail='private-provider-message', headers={'Retry-After': '7'})))
    database = db()
    with caplog.at_level('WARNING'), pytest.raises(HTTPException) as failure:
        asyncio.run(auth.google_login(request({'id_token': 'private-identity',
            'email': 'private@example.invalid', 'device_region': country, 'turnstile_token': token}), database))
    assert failure.value.status_code == status
    assert failure.value.headers == {'Retry-After': '7'}
    database.execute.assert_not_awaited()
    assert f'auth_rejected provider=google reason={reason} status={status}' in caplog.text
    assert 'private-' not in caplog.text and 'private@' not in caplog.text


@pytest.mark.parametrize('reason,identity', [
    ('identity_missing', None), ('email_missing', {}),
    ('email_unverified', {'email': 'private@example.invalid', 'email_verified': False}),
])
def test_identity_rejection_logs_only_a_reason_code(reason, identity, monkeypatch, caplog):
    monkeypatch.setattr(auth.google_id_token, 'verify_oauth2_token', lambda *_: identity)
    payload = {} if identity is None else {'id_token': 'private-identity'}
    with caplog.at_level('WARNING'), pytest.raises(HTTPException) as failure:
        asyncio.run(auth.google_login(request(payload), db()))
    assert failure.value.status_code == 400
    assert f'auth_rejected provider=google reason={reason} status=400' in caplog.text
    assert 'private' not in caplog.text
