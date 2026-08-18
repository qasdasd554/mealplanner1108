"""Serwis automatycznego wyszukiwania promocji przez AI (Google Gemini).

DLACZEGO INACZEJ NIŻ STARY SCRAPER (promo_scraper.py): bezpośrednie strony
sklepów (biedronka.pl, lidl.pl) blokują automatyczne zapytania — stary
scraper regularnie dostawał 0 wyników. Ten serwis celuje zamiast tego
w niezależne serwisy AGREGUJĄCE gazetki promocyjne (np. iUlotka.pl) —
to zwykłe, statyczne strony bez ochrony przed botami, które linkują do
PDF-ów z pełnymi gazetkami. PDF trafia bezpośrednio do Gemini (obsługuje
pliki PDF), które wyciąga z niego pary produkt+cena.

WAŻNE: wynik trafia do kolejki "pending" — NIC nie aktualizuje realnych
cen w aplikacji automatycznie. Dopiero akceptacja administratora
(PUT /promotions/{id}/approve) faktycznie zmienia ceny. To celowe —
odczyt cen z PDF-a przez AI może się mylić (błędny OCR, nieaktualna
gazetka, złe dopasowanie produktu), więc administrator zawsze weryfikuje
przed zastosowaniem.
"""

from __future__ import annotations

import base64
import logging
import re

import httpx
from bs4 import BeautifulSoup

from app.core.config import settings

logger = logging.getLogger(__name__)

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
GEMINI_MODELS = ["gemini-3.7-flash", "gemini-3.5-flash-lite"]

# Serwis agreguje gazetki promocyjne wielu sieci w jednym, prostym,
# statycznym miejscu — bez ochrony przed botami, w przeciwieństwie do
# stron samych sklepów.
_AGGREGATOR_SLUGS: dict[str, str] = {
    "Biedronka": "biedronka",
    "Lidl": "lidl",
    "Dino": "dino",
}

# Bezpiecznik: gazetki bywają bardzo duże (kilkadziesiąt stron) — powyżej
# tego rozmiaru rezygnujemy, zamiast wysyłać do AI coś, co i tak
# prawdopodobnie przekroczy limity/będzie bardzo kosztowne.
_MAX_PDF_BYTES = 15 * 1024 * 1024


class PromoAIScanError(Exception):
    """Błąd czytelny do zalogowania/pokazania administratorowi."""


async def _find_flyer_pdf_url(store_name: str) -> str:
    slug = _AGGREGATOR_SLUGS.get(store_name)
    if not slug:
        raise PromoAIScanError(f"Brak skonfigurowanego adresu agregatora dla sklepu {store_name}")

    url = f"https://www.iulotka.pl/{slug}"
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                url,
                headers={
                    "User-Agent": (
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
                    )
                },
            )
        except httpx.HTTPError as exc:
            raise PromoAIScanError(f"Nie udało się otworzyć strony z gazetkami: {exc}")

    if response.status_code != 200:
        raise PromoAIScanError(f"Strona z gazetkami zwróciła błąd ({response.status_code})")

    soup = BeautifulSoup(response.text, "html.parser")
    for link in soup.find_all("a", href=True):
        href = link["href"]
        if href.lower().endswith(".pdf"):
            return href

    raise PromoAIScanError(f"Nie znaleziono linku do PDF-a z gazetką dla {store_name}")


async def _download_pdf(url: str) -> bytes:
    async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
        try:
            response = await client.get(url)
        except httpx.HTTPError as exc:
            raise PromoAIScanError(f"Nie udało się pobrać pliku PDF z gazetką: {exc}")

    if response.status_code != 200:
        raise PromoAIScanError(f"Pobieranie PDF-a zwróciło błąd ({response.status_code})")

    if len(response.content) > _MAX_PDF_BYTES:
        raise PromoAIScanError(
            f"Gazetka jest za duża ({len(response.content) // 1024 // 1024} MB) — pomijam."
        )

    return response.content


def _build_prompt(store_name: str, available_products: list[str]) -> str:
    products_list = "\n".join(f"- {p}" for p in sorted(available_products))
    return f"""Jesteś asystentem analizującym gazetkę promocyjną sklepu {store_name}.
Przeanalizuj załączony PDF i znajdź WSZYSTKIE produkty spożywcze objęte
promocją, których nazwa pasuje do poniższej listy produktów z naszego
katalogu (dopasuj jak najbliżej — np. "Masło Extra 200g -30%" w gazetce
pasuje do "Masło" w katalogu).

DOSTĘPNE PRODUKTY W KATALOGU (dopasowuj TYLKO do tych nazw):
{products_list}

Odpowiedz WYŁĄCZNIE poprawnym JSON-em (bez markdown, bez komentarzy) w
formacie:
{{
  "promotions": [
    {{"product_name": "Masło", "regular_price": 8.99, "promo_price": 6.49}}
  ]
}}

Jeśli nie znajdziesz żadnych pasujących promocji, zwróć {{"promotions": []}}.
Ceny podawaj jako liczby w złotych (np. 6.49), bez symbolu waluty."""


async def _call_gemini_with_pdf(pdf_bytes: bytes, store_name: str, available_products: list[str]) -> str:
    if not settings.GEMINI_API_KEY:
        raise PromoAIScanError("Brak klucza GEMINI_API_KEY — skanowanie AI nie jest skonfigurowane.")

    prompt = _build_prompt(store_name, available_products)
    pdf_base64 = base64.b64encode(pdf_bytes).decode()
    parts = [
        {"inlineData": {"mimeType": "application/pdf", "data": pdf_base64}},
        {"text": prompt},
    ]

    for model in GEMINI_MODELS:
        url = GEMINI_API_URL.format(model=model)
        async with httpx.AsyncClient(timeout=120.0) as client:
            try:
                response = await client.post(
                    url,
                    headers={
                        "x-goog-api-key": settings.GEMINI_API_KEY,
                        "content-type": "application/json",
                    },
                    json={
                        "contents": [{"parts": parts, "role": "user"}],
                        "generationConfig": {"responseMimeType": "application/json"},
                    },
                )
            except httpx.HTTPError as exc:
                logger.warning("Gemini (skan promocji, model %s): błąd połączenia: %s", model, exc)
                continue

        if response.status_code == 200:
            data = response.json()
            try:
                candidates = data["candidates"]
                text_parts = candidates[0]["content"]["parts"]
                return "".join(p.get("text", "") for p in text_parts)
            except (KeyError, IndexError):
                continue

        logger.warning("Gemini (skan promocji, model %s): status %d", model, response.status_code)

    raise PromoAIScanError("Usługa AI nie zwróciła wyniku dla żadnego z wypróbowanych modeli.")


def _parse_promotions_json(raw_text: str) -> list[dict]:
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip())
    try:
        import json

        parsed = json.loads(cleaned)
    except Exception:
        raise PromoAIScanError("Nie udało się zinterpretować odpowiedzi AI jako listy promocji.")

    promotions = parsed.get("promotions", [])
    cleaned_promotions = []
    for p in promotions:
        try:
            regular = float(p["regular_price"])
            promo = float(p["promo_price"])
        except (KeyError, TypeError, ValueError):
            continue
        name = p.get("product_name")
        if not name or promo <= 0 or promo >= regular:
            continue
        cleaned_promotions.append({"product_name": name, "regular_price": regular, "promo_price": promo})
    return cleaned_promotions


async def find_promotions_for_store(store_name: str, available_products: list[str]) -> list[dict]:
    """Pełny przepływ dla JEDNEGO sklepu: znajdź gazetkę -> pobierz PDF ->
    rozpoznaj promocje przez AI. Zwraca listę dictów
    {product_name, regular_price, promo_price}."""
    pdf_url = await _find_flyer_pdf_url(store_name)
    pdf_bytes = await _download_pdf(pdf_url)
    raw = await _call_gemini_with_pdf(pdf_bytes, store_name, available_products)
    return _parse_promotions_json(raw)
