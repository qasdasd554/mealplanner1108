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

import asyncio
import base64
import logging
import re
from datetime import date

import httpx
from bs4 import BeautifulSoup

from app.core.config import settings
from app.services.gemini_models import GEMINI_API_URL, GEMINI_MODELS

logger = logging.getLogger(__name__)

# Serwis agreguje gazetki promocyjne wielu sieci w jednym, prostym,
# statycznym miejscu — bez ochrony przed botami, w przeciwieństwie do
# stron samych sklepów.
_AGGREGATOR_SLUGS: dict[str, str] = {
    "Biedronka": "biedronka",
    "Lidl": "lidl",
    "Dino": "dino",
}

# Bezpiecznik: gazetki bywają duże (kilkadziesiąt stron) — ale Gemini
# podniosło limit danych "inline" z 20 MB do 100 MB (12 stycznia 2026).
# Wcześniejszy limit 15 MB był dużo bardziej restrykcyjny niż faktycznie
# potrzeba i odrzucał zupełnie normalne gazetki. 40 MB surowego pliku PDF
# to po zakodowaniu Base64 (+ok. 33% narzutu) wciąż bezpiecznie poniżej
# rzeczywistego limitu 100 MB, z dużym zapasem.
_MAX_PDF_BYTES = 40 * 1024 * 1024


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


async def _download_pdf(url: str, referer: str) -> bytes:
    """Pobiera plik PDF spod danego adresu.

    UWAGA (naprawa): wcześniej zapytanie leciało bez żadnych nagłówków
    przeglądarki — niektóre serwery hostujące pliki (np. odpowiedzialne
    za "server disconnected") oczekują choćby minimalnego, realistycznego
    zestawu nagłówków (w tym Referer wskazujący stronę, z której pobrano
    link) i po cichu zrywają połączenie zamiast zwrócić czytelny błąd
    HTTP. Dodatkowo: "server disconnected" bywa PRZEJŚCIOWE — ponawiamy
    próbę, zamiast od razu się poddawać.
    """
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
        ),
        "Accept": "application/pdf,*/*",
        "Referer": referer,
    }

    max_attempts = 3
    last_error: str | None = None

    for attempt in range(1, max_attempts + 1):
        timeout = httpx.Timeout(connect=15.0, read=60.0, write=15.0, pool=15.0)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            try:
                response = await client.get(url, headers=headers)
            except httpx.HTTPError as exc:
                last_error = str(exc)
                logger.warning(
                    "Pobieranie PDF-a nieudane (próba %d/%d): %s", attempt, max_attempts, exc
                )
                if attempt < max_attempts:
                    await asyncio.sleep(attempt * 2.0)
                    continue
                raise PromoAIScanError(
                    f"Nie udało się pobrać pliku PDF z gazetką mimo {max_attempts} prób: {last_error}"
                )

        if response.status_code != 200:
            raise PromoAIScanError(f"Pobieranie PDF-a zwróciło błąd ({response.status_code})")

        if len(response.content) > _MAX_PDF_BYTES:
            raise PromoAIScanError(
                f"Gazetka jest za duża ({len(response.content) // 1024 // 1024} MB) — pomijam."
            )

        return response.content

    # Nieosiągalne (pętla zawsze albo zwraca, albo rzuca wyjątek powyżej),
    # ale jawny błąd na wszelki wypadek, gdyby to się kiedyś zmieniło.
    raise PromoAIScanError(f"Nie udało się pobrać pliku PDF z gazetką: {last_error}")


def _build_prompt(store_name: str, available_products: list[str]) -> str:
    products_list = "\n".join(f"- {p}" for p in sorted(available_products))
    today_str = date.today().isoformat()
    return f"""Jesteś asystentem analizującym gazetkę promocyjną sklepu {store_name}.
Przeanalizuj załączony PDF i znajdź WSZYSTKIE produkty spożywcze objęte
promocją, których nazwa pasuje do poniższej listy produktów z naszego
katalogu (dopasuj jak najbliżej — np. "Masło Extra 200g -30%" w gazetce
pasuje do "Masło" w katalogu).

DOSTĘPNE PRODUKTY W KATALOGU (dopasowuj TYLKO do tych nazw):
{products_list}

WAŻNE — każda promocja w gazetce ma jakieś OGRANICZENIA. Zwróć na nie
szczególną uwagę i wypełnij pola:

1. "condition" — WARUNEK, jaki trzeba spełnić, żeby dostać tę cenę.
   Prawie ŻADNA promocja nie jest "po prostu taniej" — typowe przykłady:
   "Przy zakupie 2 sztuk", "Kup 2, zapłać za 1" (tzw. 2+1), "Z kartą
   lojalnościową sklepu", "Tylko dla zarejestrowanych w aplikacji",
   "Limit 3 sztuk na paragon". Jeśli w gazetce NIE MA żadnego warunku
   poza samą obniżką ceny, wpisz null.

   KLUCZOWE: jeśli promocja to "kup 2, trzeci gratis" albo podobna —
   "promo_price" MA BYĆ ceną PRZY SPEŁNIENIU warunku (np. efektywna cena
   za sztukę przy zakupie wymaganej liczby), a NIE ceną, jaką zapłaci
   ktoś kupujący tylko jedną sztukę bez spełnienia warunku. Warunek MUSI
   być opisany w "condition" — inaczej użytkownik pomyśli, że cena
   dotyczy pojedynczej sztuki bez żadnych zobowiązań.

2. "valid_until" — data, do kiedy promocja jest ważna, w formacie
   RRRR-MM-DD, DOKŁADNIE tak, jak podano w gazetce (gazetki promocyjne
   niemal zawsze mają wydrukowany zakres dat ważności, np. "Oferta ważna
   od 18.08 do 24.08.2026"). Jeśli data ważności NIE jest widoczna w
   gazetce, wpisz null — NIE zgaduj.

Dzisiejsza data (do kontekstu, np. jeśli gazetka podaje tylko dzień i
miesiąc bez roku): {today_str}.

Odpowiedz WYŁĄCZNIE poprawnym JSON-em (bez markdown, bez komentarzy) w
formacie:
{{
  "promotions": [
    {{"product_name": "Masło", "regular_price": 8.99, "promo_price": 6.49, "condition": null, "valid_until": "2026-08-24"}},
    {{"product_name": "Mleko 2%", "regular_price": 3.99, "promo_price": 2.66, "condition": "Kup 2, zapłać za 1 (2+1)", "valid_until": null}}
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

    reason_types: list[str] = []
    for model in GEMINI_MODELS:
        url = GEMINI_API_URL.format(model=model)
        # UWAGA (naprawa wydajności): 120 sekund na model x3 modele w
        # łańcuchu zapasowym dawało nawet do 6 minut oczekiwania w
        # najgorszym scenariuszu. Analiza PDF-a gazetki to zadanie
        # cięższe niż zwykły tekst (stąd trochę więcej niż w imporcie
        # przepisu), ale 45s z zapasem wciąż w pełni wystarcza typowej,
        # udanej odpowiedzi, a dużo szybciej przechodzi do kolejnego
        # modelu, gdy poprzedni faktycznie ma problem.
        async with httpx.AsyncClient(timeout=45.0) as client:
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

        # UWAGA (nowe): rozróżniamy, CZY to wyczerpany dzienny limit tokenów
        # (klasyfikacja wspólna z ai_recipe_import.py — patrz
        # gemini_status.classify_gemini_error), żeby komunikat końcowy dla
        # administratora był konkretny, zamiast ogólnego "nie zwróciła wyniku".
        if response.status_code == 429:
            from app.services.gemini_status import classify_gemini_error

            try:
                error_body = response.json()
            except Exception:
                error_body = None
            reason_types.append(classify_gemini_error(429, error_body))

    if reason_types and all(r == "quota_exhausted" for r in reason_types):
        raise PromoAIScanError(
            "Dzienny limit zapytań do AI został wyczerpany dla wszystkich dostępnych "
            "modeli. Skanowanie gazetek będzie ponownie możliwe po resecie limitu (zwykle następnego dnia)."
        )
    if reason_types and all(r == "rate_limited" for r in reason_types):
        raise PromoAIScanError(
            "Zbyt wiele zapytań do AI w krótkim czasie. Odczekaj minutę i spróbuj ponownie."
        )

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

        # UWAGA (nowe): wyciągamy WARUNEK promocji (np. "2+1", "przy
        # zakupie 2 sztuk") i prawdziwą DATĘ WAŻNOŚCI wydrukowaną na
        # gazetce — wcześniej AI było proszone TYLKO o cenę przed/po, bez
        # żadnej wzmianki o ograniczeniach, przez co "kup 2, trzeci
        # gratis" mogło wyglądać jak zwykła obniżka ceny pojedynczej
        # sztuki. Data ważności szła wcześniej na sztywno jako "+14 dni od
        # dziś", niezależnie od tego, co faktycznie było na plakacie.
        condition = p.get("condition")
        condition = condition.strip() if isinstance(condition, str) and condition.strip() else None

        valid_until_str = p.get("valid_until")
        valid_until = None
        if isinstance(valid_until_str, str) and valid_until_str.strip():
            try:
                valid_until = date.fromisoformat(valid_until_str.strip())
            except ValueError:
                valid_until = None

        cleaned_promotions.append({
            "product_name": name,
            "regular_price": regular,
            "promo_price": promo,
            "condition": condition,
            "valid_until": valid_until,
        })
    return cleaned_promotions


async def find_promotions_for_store(store_name: str, available_products: list[str]) -> list[dict]:
    """Pełny przepływ dla JEDNEGO sklepu: znajdź gazetkę -> pobierz PDF ->
    rozpoznaj promocje przez AI. Zwraca listę dictów
    {product_name, regular_price, promo_price}."""
    pdf_url = await _find_flyer_pdf_url(store_name)
    slug = _AGGREGATOR_SLUGS.get(store_name, "")
    referer = f"https://www.iulotka.pl/{slug}"
    pdf_bytes = await _download_pdf(pdf_url, referer=referer)
    raw = await _call_gemini_with_pdf(pdf_bytes, store_name, available_products)
    return _parse_promotions_json(raw)
