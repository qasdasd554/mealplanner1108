import asyncio
from html import escape
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import httpx
import pytest

from app.api.v1 import auth
from app.services import email_service


@pytest.fixture
def sent(monkeypatch):
    payloads = []
    monkeypatch.setattr(email_service.settings, 'RESEND_API_KEY', 'synthetic-key')
    monkeypatch.setattr(email_service.settings, 'RESEND_FROM_EMAIL', 'Meal Planner <test@example.test>')

    class Client:
        def __init__(self, **kwargs):
            assert kwargs['timeout'] == 15.0
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            pass
        async def post(self, url, *, headers, json):
            assert url == 'https://api.resend.com/emails'
            payloads.append(json)
            return SimpleNamespace(status_code=200)

    monkeypatch.setattr(email_service.httpx, 'AsyncClient', Client)
    return payloads


@pytest.mark.parametrize('kind', ['verification', 'password_reset'])
@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_code_email_language_keeps_code_recipient_brand_and_expiry(sent, kind, country):
    function = getattr(email_service, f'send_{kind}_email')
    asyncio.run(function('synthetic@example.test', '123456', 'Anna', country_code=country))
    payload = sent[-1]
    assert payload['to'] == ['synthetic@example.test']
    assert 'Meal Planner Polska' in payload['subject']
    assert '123456' in payload['html']
    assert '15' in payload['html']
    assert ('Hi Anna!' if country == 'GB' else 'Cześć Anna!') in payload['html']
    if country == 'GB':
        assert ('verification code' if kind == 'verification' else 'Password reset') in payload['subject']
        assert '15 minutes' in payload['html']


def test_legacy_email_defaults_to_polish(sent):
    asyncio.run(email_service.send_verification_email('synthetic@example.test', '123456', None))
    assert sent[-1]['subject'] == 'Twój kod weryfikacyjny — Meal Planner Polska'
    assert 'Cześć!' in sent[-1]['html']


def test_display_name_cannot_inject_markup_into_code_email(sent):
    name = '<b>A & B</b>'
    asyncio.run(email_service.send_verification_email('synthetic@example.test', '123456', name))
    assert escape(name) in sent[-1]['html']
    assert name not in sent[-1]['html']


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_resend_uses_persisted_account_market(monkeypatch, country):
    user = SimpleNamespace(id=uuid4(), email='synthetic@example.test', display_name='Anna', country_code=country, is_email_verified=False)
    send = AsyncMock()
    monkeypatch.setattr(auth, 'send_verification_email', send)
    monkeypatch.setattr(auth, 'enforce_user_rate_limit', lambda *args: None)
    db = AsyncMock()
    asyncio.run(auth.resend_verification_code(current_user=user, db=db))
    assert send.await_args.kwargs == {'country_code': country}
    assert len(send.await_args.args[1]) == 6


@pytest.mark.parametrize('country', ['PL', 'GB'])
def test_password_reset_uses_account_not_request_region(monkeypatch, country):
    user = SimpleNamespace(email='synthetic@example.test', display_name='Anna', country_code=country)
    result = MagicMock()
    result.scalar_one_or_none.return_value = user
    db = AsyncMock()
    db.execute.return_value = result
    send = AsyncMock()
    monkeypatch.setattr(auth, 'send_password_reset_email', send)
    monkeypatch.setattr(auth, 'enforce_password_reset_rate_limit', lambda *args: None)
    request = SimpleNamespace(json=AsyncMock(return_value={'email': user.email, 'device_region': 'PL' if country == 'GB' else 'GB'}), headers={})
    asyncio.run(auth.forgot_password(request, db=db))
    assert send.await_args.kwargs == {'country_code': country}
    assert len(send.await_args.args[1]) == 6
