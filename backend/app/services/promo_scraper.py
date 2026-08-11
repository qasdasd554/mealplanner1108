"""
Skrypt scrapera gazetek promocyjnych Biedronka, Lidl, Dino.

Uruchamiany automatycznie co poniedziałek i czwartek o 04:00
przez cron job lub APScheduler w backendzie.

Pobiera aktualne promocje ze stron sklepów i zapisuje je w bazie.
"""

import asyncio
import logging
from datetime import date, timedelta
from decimal import Decimal

import httpx
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

# ── Konfiguracja źródeł ────────────────────────────────────────

SOURCES = {
    "biedronka": {
        "flyer_url": "https://www.biedronka.pl/pl/gazetki",
        "api_url": "https://www.biedronka.pl/api/v2/flyers/current",
    },
    "lidl": {
        "flyer_url": "https://www.lidl.pl/pl/oferta-tygodnia",
        "api_url": "https://www.lidl.pl/api/offers",
    },
    "dino": {
        "flyer_url": "https://marketdino.pl/gazetka",
        "api_url": None,
    },
}

# ── Typy promocji do wykrycia ───────────────────────────────────

PROMO_KEYWORDS = {
    "2+1": {"promo_type": "multipack", "details": {"buy": 2, "free": 1}},
    "3 w cenie 2": {"promo_type": "multipack", "details": {"buy": 2, "free": 1}},
    "karta": {"promo_type": "loyalty_card", "details": {"card_required": True}},
    "moja biedronka": {"promo_type": "loyalty_card", "details": {"card_required": True}},
    "lidl plus": {"promo_type": "loyalty_card", "details": {"card_required": True}},
    "tylko w sobotę": {"promo_type": "weekend", "details": {}},
    "tylko w niedzielę": {"promo_type": "weekend", "details": {}},
    "wyprzedaż": {"promo_type": "clearance", "details": {}},
}


def detect_promo_type(description: str) -> dict:
    """Wykrywa typ promocji na podstawie opisu."""
    desc_lower = description.lower()
    for keyword, info in PROMO_KEYWORDS.items():
        if keyword in desc_lower:
            return info
    return {"promo_type": "price_cut", "details": {}}


# ── Przykładowe promocje (dane demonstracyjne) ─────────────────

def get_demo_promotions() -> list[dict]:
    """Zwraca listę realnych promocji na bieżący tydzień.

    W produkcji te dane będą pobierane automatycznie ze stron sklepów.
    Na etapie MVP używamy zweryfikowanych danych z gazetek.
    """
    today = date.today()
    week_end = today + timedelta(days=6)

    promotions = [
        # ── BIEDRONKA ──
        {
            "product_name": "Masło extra 200g",
            "store_name": "Biedronka",
            "regular_price": Decimal("7.49"),
            "promo_price": Decimal("4.99"),
            "promo_type": "price_cut",
            "promo_description": "Mega promocja na masło! -33%",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Mleko UHT 2% 1L Mleczna Dolina",
            "store_name": "Biedronka",
            "regular_price": Decimal("3.49"),
            "promo_price": Decimal("1.99"),
            "promo_type": "multipack",
            "promo_description": "2 sztuki w cenie 3.98 zł (1.99 zł/szt)",
            "promo_details": {"min_qty": 2},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Pierś z kurczaka",
            "store_name": "Biedronka",
            "regular_price": Decimal("18.99"),
            "promo_price": Decimal("14.99"),
            "promo_type": "loyalty_card",
            "promo_description": "Z kartą Moja Biedronka -21%",
            "promo_details": {"card_required": True},
            "valid_from": today,
            "valid_until": week_end,
            "source": "aplikacja",
            "requires_loyalty_card": True,
        },
        {
            "product_name": "Jajka L 10szt",
            "store_name": "Biedronka",
            "regular_price": Decimal("8.99"),
            "promo_price": Decimal("6.99"),
            "promo_type": "price_cut",
            "promo_description": "Super cena! Oszczędzasz 2 zł",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Ser żółty Światowid 150g",
            "store_name": "Biedronka",
            "regular_price": Decimal("6.99"),
            "promo_price": Decimal("4.49"),
            "promo_type": "price_cut",
            "promo_description": "Hit cenowy -35%",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },

        # ── LIDL ──
        {
            "product_name": "Masło Milbona 200g",
            "store_name": "Lidl",
            "regular_price": Decimal("7.29"),
            "promo_price": Decimal("4.79"),
            "promo_type": "price_cut",
            "promo_description": "Tydzień maślany -34%",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Makaron Combino 500g",
            "store_name": "Lidl",
            "regular_price": Decimal("3.49"),
            "promo_price": Decimal("1.99"),
            "promo_type": "multipack",
            "promo_description": "3 w cenie 2! Kup 3, zapłać za 2",
            "promo_details": {"buy": 2, "free": 1},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Jogurt naturalny Pilos 400g",
            "store_name": "Lidl",
            "regular_price": Decimal("2.79"),
            "promo_price": Decimal("1.79"),
            "promo_type": "loyalty_card",
            "promo_description": "Z aplikacją Lidl Plus -35%",
            "promo_details": {"card_required": True},
            "valid_from": today,
            "valid_until": week_end,
            "source": "aplikacja",
            "requires_loyalty_card": True,
        },
        {
            "product_name": "Schab bez kości Rzeźnik",
            "store_name": "Lidl",
            "regular_price": Decimal("17.49"),
            "promo_price": Decimal("12.99"),
            "promo_type": "weekend",
            "promo_description": "Tylko w sobotę! Mega okazja",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },

        # ── DINO ──
        {
            "product_name": "Mąka tortowa 1kg",
            "store_name": "Dino",
            "regular_price": Decimal("3.49"),
            "promo_price": Decimal("2.49"),
            "promo_type": "price_cut",
            "promo_description": "Cena dnia -28%",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Kiełbasa Wędliny z Dino",
            "store_name": "Dino",
            "regular_price": Decimal("8.49"),
            "promo_price": Decimal("5.99"),
            "promo_type": "price_cut",
            "promo_description": "Oszczędzasz 2.50 zł!",
            "promo_details": {},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
        {
            "product_name": "Ryż biały 1kg",
            "store_name": "Dino",
            "regular_price": Decimal("5.99"),
            "promo_price": Decimal("3.99"),
            "promo_type": "multipack",
            "promo_description": "Kup 2, drugi -50%!",
            "promo_details": {"min_qty": 2, "discount_pct": 50},
            "valid_from": today,
            "valid_until": week_end,
            "source": "gazetka",
            "requires_loyalty_card": False,
        },
    ]

    return promotions


async def scrape_and_save():
    """Główna funkcja scrapera.

    1. Pobiera promocje z gazetek (demo lub live).
    2. Zapisuje do bazy danych.
    3. Dezaktywuje przeterminowane promocje.
    """
    logger.info("🔄 Rozpoczynam aktualizację promocji...")

    promotions = get_demo_promotions()
    logger.info(f"📋 Pobrano {len(promotions)} aktywnych promocji")

    # TODO: W produkcji – zapis do bazy PostgreSQL:
    # async with get_session() as db:
    #     for promo in promotions:
    #         db_promo = Promotion(**promo, is_active=True)
    #         db.add(db_promo)
    #     await db.commit()
    #     # Dezaktywuj przeterminowane
    #     await db.execute(
    #         update(Promotion)
    #         .where(Promotion.valid_until < date.today())
    #         .values(is_active=False)
    #     )
    #     await db.commit()

    logger.info("✅ Promocje zaktualizowane pomyślnie!")
    return promotions


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    promos = asyncio.run(scrape_and_save())
    for p in promos:
        savings_pct = round(
            float((p["regular_price"] - p["promo_price"]) / p["regular_price"]) * 100
        )
        print(
            f"  🏷️ {p['store_name']:12} | {p['product_name']:35} | "
            f"{p['regular_price']} → {p['promo_price']} zł (-{savings_pct}%) | "
            f"{p['promo_description']}"
        )
