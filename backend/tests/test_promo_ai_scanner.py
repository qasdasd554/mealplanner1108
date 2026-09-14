"""Testy konfiguracji skanera gazetek promocyjnych."""

from app.services.promo_ai_scanner import _AGGREGATOR_SLUGS


def test_carrefour_has_promotion_scanner_source() -> None:
    assert _AGGREGATOR_SLUGS["Carrefour"] == "carrefour"

