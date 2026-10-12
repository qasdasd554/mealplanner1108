"""Testy konfiguracji skanera gazetek promocyjnych."""

from app.services.promo_ai_scanner import _AGGREGATOR_SLUGS
import asyncio
import httpx
import pytest
from app.services import promo_ai_scanner as scanner


def test_carrefour_has_promotion_scanner_source() -> None:
    assert _AGGREGATOR_SLUGS["Carrefour"] == "carrefour"


def test_pdf_link_with_query_string_is_found(monkeypatch):
    client = httpx.AsyncClient
    transport = httpx.MockTransport(lambda request: httpx.Response(200, text='<a href="/gazetka.pdf?download=1">PDF</a>'))
    monkeypatch.setattr(scanner.httpx, 'AsyncClient', lambda **kwargs: client(transport=transport, **kwargs))
    assert asyncio.run(scanner._find_flyer_pdf_url('Carrefour')).endswith('/gazetka.pdf?download=1')


def test_html_instead_of_pdf_is_rejected_before_ai(monkeypatch):
    client = httpx.AsyncClient
    transport = httpx.MockTransport(lambda request: httpx.Response(200, content=b'<html>blocked</html>'))
    monkeypatch.setattr(scanner.httpx, 'AsyncClient', lambda **kwargs: client(transport=transport, **kwargs))
    with pytest.raises(scanner.PromoAIScanError, match='zamiast PDF'):
        asyncio.run(scanner._download_pdf('https://example.test/f.pdf', 'https://example.test'))


def test_download_size_is_bounded(monkeypatch):
    client = httpx.AsyncClient
    transport = httpx.MockTransport(lambda request: httpx.Response(200, content=b'%PDF-' + b'x' * 20))
    monkeypatch.setattr(scanner.httpx, 'AsyncClient', lambda **kwargs: client(transport=transport, **kwargs))
    monkeypatch.setattr(scanner, '_MAX_PDF_BYTES', 10)
    with pytest.raises(scanner.PromoAIScanError, match='rozmiaru'):
        asyncio.run(scanner._download_pdf('https://example.test/f.pdf', 'https://example.test'))


def test_invalid_json_shape_is_a_controlled_scan_error():
    with pytest.raises(scanner.PromoAIScanError):
        scanner._parse_promotions_json('[]')


def test_nonfinite_prices_are_never_saved():
    assert scanner._parse_promotions_json('{"promotions":[{"product_name":"Masło","regular_price":Infinity,"promo_price":4}]}') == []

