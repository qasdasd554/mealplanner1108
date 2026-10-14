"""A checked DNS answer must be the address used for the connection."""

import asyncio
import socket
from contextlib import asynccontextmanager

import httpx
import pytest

from app.services import ai_recipe_import


@pytest.mark.asyncio
async def test_url_import_connects_to_checked_ip_and_preserves_https_identity(monkeypatch):
    lookups = []
    def resolve(host, port, **kwargs):
        lookups.append(host)
        ip = "93.184.216.34" if len(lookups) == 1 else "127.0.0.1"
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (ip, port))]
    monkeypatch.setattr(socket, "getaddrinfo", resolve)
    attempts = []
    class Client:
        def __init__(self, **kwargs):
            self.options = kwargs
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            pass
        @asynccontextmanager
        async def stream(self, method, url, *, headers, **kwargs):
            attempts.append((str(url), headers, kwargs, self.options))
            yield httpx.Response(200, headers={"content-type": "text/html"}, content=b'<script type="application/ld+json">{"@type":"Recipe","name":"Omlet","recipeIngredient":["2 jajka"],"recipeInstructions":"Gotuj."}</script>')
    monkeypatch.setattr(httpx, "AsyncClient", Client)
    await ai_recipe_import.extract_recipe_from_url("https://example.com/recipe", ["Jajka"])
    target, headers, kwargs, options = attempts[0]
    assert httpx.URL(target).host == "93.184.216.34"
    assert headers["Host"] == "example.com"
    assert kwargs["extensions"]["sni_hostname"] == "example.com"
    assert options["trust_env"] is False
    assert len(lookups) == 1
