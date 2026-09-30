"""Ochrona importu przepisu z linku przed SSRF."""

import socket

import pytest

from app.core.safe_url import UnsafeUrlError, validate_public_http_url


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/admin",
        "http://169.254.169.254/latest/meta-data/",
        "http://10.0.0.1/private",
        "http://[::1]/",
        "file:///etc/passwd",
        "http://user:password@example.com/recipe",
    ],
)
async def test_private_or_unsafe_recipe_urls_are_rejected(url: str) -> None:
    with pytest.raises(UnsafeUrlError):
        await validate_public_http_url(url)


@pytest.mark.asyncio
async def test_public_recipe_domain_is_allowed(monkeypatch) -> None:
    monkeypatch.setattr(
        socket,
        "getaddrinfo",
        lambda *_args, **_kwargs: [
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443)),
        ],
    )

    value = await validate_public_http_url("https://example.com/przepis")

    assert value == "https://example.com/przepis"
