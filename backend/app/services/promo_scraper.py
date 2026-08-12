"""Scraper cen i promocji ze stron Biedronki, Lidla i Dino.

UCZCIWA INFORMACJA O STANIE TEGO MODUŁU (przeczytaj przed użyciem):

Poprzednia wersja tego pliku miała w nazwie "scraper", importowała httpx
i BeautifulSoup, i miała komentarz "uruchamiany automatycznie co poniedziałek
i czwartek przez cron/APScheduler" — ale w rzeczywistości NIC nie scrapowała.
Zwracała na sztywno wpisaną listę killku przykładowych promocji
(`get_demo_promotions()`, wprost nazwaną w kodzie jako dane demonstracyjne),
zapis do bazy był zakomentowany jako TODO, a sam plik nie był nigdzie w
aplikacji importowany ani wywoływany. Innymi słowy: ceny nigdy nie były
faktycznie aktualizowane na żywo.

Ta wersja PRÓBUJE robić to naprawdę — ale ma jasne ograniczenia:

1. Biedronka, Lidl i Dino nie udostępniają żadnego publicznego API z cenami
   produktów. Ich strony w większości renderują treść przez JavaScript,
   a Lidl dodatkowo (potwierdzone przez niezależnych deweloperów) celowo
   wstawia ceny jako OBRAZKI, żeby uniemożliwić scrapowanie.
2. Ten backend nie uruchamia przeglądarki (Playwright/Selenium) — działa
   na darmowym planie Render, gdzie headless browser byłby zbyt ciężki
   i zbyt wolny. Próbujemy więc wyłącznie technik nie wymagających
   renderowania JS: dane strukturalne JSON-LD (schema.org Product/Offer,
   które część sklepów dodaje pod SEO, niezależnie od frameworka JS)
   oraz — jako ostatnia deska ratunku — statyczny HTML.
3. Jeśli dla danego sklepu nie uda się znaleźć ŻADNYCH wiarygodnych danych,
   ten moduł NIE wymyśla ani nie zostawia nieaktualnych/fałszywych cen —
   po prostu nic dla tego sklepu nie aktualizuje. Zero danych jest lepsze
   niż fałszywe dane.

Efekt w praktyce może być taki, że któryś (lub wszystkie) sklepy zwrócą
zero wyników — to nie jest błąd tego kodu, tylko rzeczywiste ograniczenie
tych konkretnych stron. Sprawdź logi Render po wdrożeniu, żeby zobaczyć,
co faktycznie się udało.
"""

from __future__ import annotations

import difflib
import json
import logging
import re
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation

import httpx
from bs4 import BeautifulSoup
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.product import Product, StoreProduct
from app.models.promotion import Promotion
from app.models.store import Store

logger = logging.getLogger(__name__)

# Realistyczny nagłówek przeglądarki — bez tego wiele stron odrzuca
# zapytania z domyślnym User-Agentem biblioteki HTTP.
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "pl-PL,pl;q=0.9",
}

# Strony sklepów, które spróbujemy odpytać. Każdy sklep jest niezależny —
# błąd jednego (timeout, blokada, zmiana strony) nie wpływa na pozostałe.
_STORE_URLS: dict[str, list[str]] = {
    "Biedronka": [
        "https://www.biedronka.pl/pl/gazetki",
    ],
    "Lidl": [
        "https://www.lidl.pl/pl/oferta-tygodnia",
    ],
    "Dino": [
        "https://marketdino.pl/gazetka",
    ],
}

# Minimalne podobieństwo nazw (0-1), żeby uznać scrapowany produkt za
# dopasowany do naszego katalogu. Wyżej = ostrożniej (mniej fałszywych
# dopasowań, ale też mniej trafień).
_MATCH_THRESHOLD = 0.82


def _normalize(name: str) -> str:
    """Upraszcza nazwę produktu do porównania (małe litery, bez znaków
    specjalnych i typowych dopisków typu gramatura)."""
    n = name.lower()
    n = re.sub(r"\d+([.,]\d+)?\s*(g|kg|ml|l|szt)\b", "", n)
    n = re.sub(r"[^a-ząćęłńóśźż0-9\s]", " ", n)
    n = re.sub(r"\s+", " ", n).strip()
    return n


def _best_match(scraped_name: str, catalog: dict[str, Product]) -> Product | None:
    """Znajduje najbardziej podobny produkt z katalogu (jeśli wystarczająco
    podobny), używając wbudowanego difflib — bez dodatkowej zależności."""
    target = _normalize(scraped_name)
    if not target:
        return None

    best_ratio = 0.0
    best_product: Product | None = None
    for norm_name, product in catalog.items():
        ratio = difflib.SequenceMatcher(None, target, norm_name).ratio()
        if ratio > best_ratio:
            best_ratio = ratio
            best_product = product

    if best_ratio >= _MATCH_THRESHOLD:
        return best_product
    return None


def _parse_price(raw: str | float | int) -> Decimal | None:
    """Parsuje cenę z różnych formatów tekstowych ('12,99 zł', '12.99', 1299)."""
    try:
        if isinstance(raw, (int, float)):
            return Decimal(str(raw)).quantize(Decimal("0.01"))
        text = str(raw).strip().replace("zł", "").replace("PLN", "")
        text = text.replace(" ", "").replace(",", ".")
        text = re.sub(r"[^\d.]", "", text)
        if not text:
            return None
        value = Decimal(text)
        if value <= 0 or value > 500:  # sanity check — odrzuć śmieciowe wartości
            return None
        return value.quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        return None


def _extract_offers_from_jsonld(html: str) -> list[dict]:
    """Szuka danych strukturalnych schema.org (Product/Offer) w znacznikach
    <script type="application/ld+json">. Wiele stron dodaje je pod SEO,
    niezależnie od tego, czy reszta strony jest renderowana przez JS —
    to jedyna technika, która ma realną szansę zadziałać bez przeglądarki.
    """
    offers: list[dict] = []
    soup = BeautifulSoup(html, "lxml")
    for tag in soup.find_all("script", attrs={"type": "application/ld+json"}):
        if not tag.string:
            continue
        try:
            data = json.loads(tag.string)
        except (json.JSONDecodeError, TypeError):
            continue

        candidates = data if isinstance(data, list) else [data]
        for item in candidates:
            if not isinstance(item, dict):
                continue
            graph = item.get("@graph") if "@graph" in item else [item]
            for node in graph if isinstance(graph, list) else [graph]:
                if not isinstance(node, dict):
                    continue
                node_type = node.get("@type", "")
                if isinstance(node_type, list):
                    is_product = "Product" in node_type
                else:
                    is_product = node_type == "Product"
                if not is_product:
                    continue

                name = node.get("name")
                offer = node.get("offers")
                if isinstance(offer, list):
                    offer = offer[0] if offer else None
                price = offer.get("price") if isinstance(offer, dict) else None
                if name and price:
                    offers.append({"name": name, "price": price})
    return offers


def _extract_offers_from_html_fallback(html: str) -> list[dict]:
    """Ostatnia deska ratunku: szuka elementów z atrybutem itemprop="price"
    albo klasami zawierającymi "price" w statycznym (nie-JS) HTML-u.
    Działa tylko jeśli strona faktycznie renderuje ceny po stronie serwera —
    dla stron w pełni opartych o JS (typowe dla dużych sieci handlowych)
    zwykle nie znajdzie nic, co jest oczekiwanym, bezpiecznym wynikiem."""
    offers: list[dict] = []
    soup = BeautifulSoup(html, "lxml")

    for el in soup.select('[itemprop="price"]'):
        price = el.get("content") or el.get_text(strip=True)
        name_el = el.find_previous(attrs={"itemprop": "name"})
        name = name_el.get_text(strip=True) if name_el else None
        if name and price:
            offers.append({"name": name, "price": price})

    return offers


async def _scrape_store(client: httpx.AsyncClient, store_name: str) -> list[dict]:
    """Próbuje pobrać oferty dla jednego sklepu. Zwraca pustą listę (nigdy
    nie rzuca wyjątku wyżej) jeśli się nie uda — błąd jednego sklepu nie
    może zepsuć aktualizacji pozostałych."""
    all_offers: list[dict] = []
    for url in _STORE_URLS.get(store_name, []):
        try:
            resp = await client.get(url, headers=_HEADERS, timeout=15.0, follow_redirects=True)
            if resp.status_code != 200:
                logger.info(
                    "[%s] %s -> HTTP %s, pomijam", store_name, url, resp.status_code
                )
                continue

            offers = _extract_offers_from_jsonld(resp.text)
            if not offers:
                offers = _extract_offers_from_html_fallback(resp.text)

            logger.info("[%s] %s -> znaleziono %d ofert (surowych)", store_name, url, len(offers))
            all_offers.extend(offers)
        except httpx.RequestError as e:
            logger.info("[%s] %s -> błąd połączenia: %s", store_name, url, e)
        except Exception:
            logger.exception("[%s] %s -> nieoczekiwany błąd parsowania", store_name, url)

    return all_offers


async def scrape_and_update_prices(db: AsyncSession) -> dict:
    """Główna funkcja: próbuje pobrać aktualne ceny dla każdego sklepu
    niezależnie i zaktualizować `StoreProduct.price` dla dopasowanych
    produktów z naszego katalogu. Zapisuje też wpis w `Promotion`, jeśli
    znaleziona cena jest niższa od dotychczasowej (do wglądu/historii).

    Zwraca podsumowanie — ile ofert znaleziono i zaktualizowano per sklep,
    żeby dało się to zweryfikować w logach bez zaglądania do bazy.
    """
    summary: dict[str, dict] = {}

    stores_result = await db.execute(select(Store))
    stores_by_name = {s.name: s for s in stores_result.scalars().all()}

    products_result = await db.execute(select(Product))
    catalog = {_normalize(p.name): p for p in products_result.scalars().all()}

    async with httpx.AsyncClient() as client:
        for store_name in _STORE_URLS:
            store = stores_by_name.get(store_name)
            if not store:
                summary[store_name] = {"error": "sklep nie istnieje w bazie"}
                continue

            raw_offers = await _scrape_store(client, store_name)
            updated = 0
            matched = 0

            for offer in raw_offers:
                price = _parse_price(offer.get("price"))
                name = offer.get("name")
                if not price or not name:
                    continue

                product = _best_match(name, catalog)
                if not product:
                    continue
                matched += 1

                sp_result = await db.execute(
                    select(StoreProduct).where(
                        StoreProduct.store_id == store.id,
                        StoreProduct.product_id == product.id,
                    )
                )
                store_product = sp_result.scalar_one_or_none()
                if not store_product:
                    continue

                old_price = store_product.price
                if old_price and price < old_price:
                    # Znaleziona cena jest niższa — zapisz jako promocję
                    # (widoczną do wglądu/historii), oprócz aktualizacji
                    # bieżącej ceny.
                    promo = Promotion(
                        product_name=product.name,
                        store_name=store_name,
                        regular_price=old_price,
                        promo_price=price,
                        promo_type="price_cut",
                        promo_description=f"Cena zaktualizowana ze strony {store_name}",
                        source="scraper",
                        valid_from=date.today(),
                        valid_until=date.today() + timedelta(days=7),
                        is_active=True,
                    )
                    db.add(promo)

                store_product.price = price
                store_product.last_verified = date.today()
                updated += 1

            summary[store_name] = {
                "raw_offers": len(raw_offers),
                "matched_to_catalog": matched,
                "prices_updated": updated,
            }

    await db.commit()

    total_updated = sum(s.get("prices_updated", 0) for s in summary.values())
    if total_updated == 0:
        logger.warning(
            "Scraper cen nie zaktualizował ŻADNEJ ceny w tym przebiegu. "
            "To oczekiwane, jeśli sklepy renderują ceny przez JavaScript "
            "lub blokują automatyczne zapytania (np. Lidl celowo wstawia "
            "ceny jako obrazki). Ceny w bazie pozostają takie, jak wcześniej "
            "— nic nie zostało zmyślone ani nadpisane fałszywymi danymi. "
            "Podsumowanie per sklep: %s",
            summary,
        )
    else:
        logger.info("Scraper cen zaktualizował %d cen. Podsumowanie: %s", total_updated, summary)

    return summary
