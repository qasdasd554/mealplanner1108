"""Sprawdzanie stanu API Gemini — czy klucz jest poprawny i czy limity
(tokeny/zapytania) nie zostały wyczerpane.

Ten moduł jest współdzielony przez:
- `ai_recipe_import.py` (rozpoznawanie przepisów z tekstu/zdjęcia/linku)
- `promo_ai_scanner.py` (skanowanie gazetek promocyjnych)

Dwa zastosowania:
1. PROAKTYWNE: `check_gemini_status()` — lekki, tani "ping" do każdego
   modelu z listy, wywoływany na żądanie (np. przez administratora w
   panelu), ŻEBY sprawdzić stan PRZED tym, jak faktyczny użytkownik
   trafi na błąd.
2. REAKTYWNE: `classify_gemini_error()` — analizuje treść błędu 429
   zwróconego przez Gemini i rozróżnia "wyczerpany limit" (trzeba
   poczekać/dokupić) od innych, przejściowych problemów — używane przy
   budowaniu czytelnego komunikatu końcowego dla użytkownika.
"""

from __future__ import annotations

import logging

import httpx

from app.core.config import settings
from app.services.gemini_models import GEMINI_API_URL, GEMINI_MODELS

logger = logging.getLogger(__name__)


class GeminiModelStatus:
    """Stan pojedynczego modelu po sprawdzeniu."""

    def __init__(self, model: str, ok: bool, detail: str):
        self.model = model
        self.ok = ok
        self.detail = detail

    def to_dict(self) -> dict:
        return {"model": self.model, "ok": self.ok, "detail": self.detail}


def classify_gemini_error(status_code: int, response_body: dict | None) -> str:
    """Rozróżnia PRZYCZYNĘ błędu 429 na podstawie treści odpowiedzi
    Gemini — zwraca jedną z: "quota_exhausted" (limit tokenów/zapytań
    faktycznie wyczerpany — trzeba poczekać do resetu albo przejść na
    płatny plan), "rate_limited" (chwilowe przekroczenie liczby zapytań
    na minutę — zwykle mija w kilkadziesiąt sekund), "unknown" (nie da
    się jednoznacznie rozróżnić z treści odpowiedzi)."""
    if status_code != 429:
        return "unknown"
    if not response_body:
        return "unknown"

    error_info = response_body.get("error", {})
    status_field = str(error_info.get("status", "")).upper()
    message = str(error_info.get("message", "")).lower()

    if status_field == "RESOURCE_EXHAUSTED" or "quota" in message:
        # Gemini rozróżnia limity per-minutę od dziennych/miesięcznych w
        # treści wiadomości — jeśli wprost wspomina "per day"/"daily",
        # to prawdziwe wyczerpanie limitu, nie chwilowy natłok zapytań.
        if "per day" in message or "daily" in message or "per minute" not in message:
            return "quota_exhausted"
        return "rate_limited"
    return "unknown"


async def check_gemini_status() -> dict:
    """Wysyła minimalne, tanie zapytanie do KAŻDEGO modelu z listy, żeby
    sprawdzić, czy klucz API działa i czy limity nie są wyczerpane —
    BEZ czekania, aż na to natrafi prawdziwy użytkownik. Zwraca stan
    każdego modelu z osobna, bo każdy ma własny, niezależny limit."""
    if not settings.GEMINI_API_KEY:
        return {
            "configured": False,
            "models": [],
            "summary": "Brak klucza GEMINI_API_KEY skonfigurowanego na serwerze.",
        }

    results: list[GeminiModelStatus] = []
    for model in GEMINI_MODELS:
        url = GEMINI_API_URL.format(model=model)
        # Najmniejsze możliwe zapytanie — jedno słowo, minimalny koszt
        # tokenów, tylko po to, żeby sprawdzić czy model w ogóle
        # odpowiada.
        request_body = {
            "contents": [{"parts": [{"text": "Odpowiedz jednym słowem: OK"}], "role": "user"}],
        }
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    url,
                    headers={
                        "x-goog-api-key": settings.GEMINI_API_KEY,
                        "content-type": "application/json",
                    },
                    json=request_body,
                )
        except httpx.HTTPError as exc:
            results.append(GeminiModelStatus(model, False, f"Błąd połączenia: {exc}"))
            continue

        if response.status_code == 200:
            results.append(GeminiModelStatus(model, True, "Działa poprawnie"))
        elif response.status_code == 429:
            try:
                body = response.json()
            except Exception:
                body = None
            reason = classify_gemini_error(429, body)
            if reason == "quota_exhausted":
                results.append(
                    GeminiModelStatus(model, False, "Limit tokenów/zapytań wyczerpany na dziś")
                )
            elif reason == "rate_limited":
                results.append(
                    GeminiModelStatus(model, False, "Chwilowo za dużo zapytań — spróbuj za chwilę")
                )
            else:
                results.append(GeminiModelStatus(model, False, "Limit przekroczony (429)"))
        elif response.status_code in (401, 403):
            results.append(GeminiModelStatus(model, False, "Klucz API nieprawidłowy lub bez uprawnień"))
        else:
            results.append(
                GeminiModelStatus(model, False, f"Nieoczekiwany błąd ({response.status_code})")
            )

    any_ok = any(r.ok for r in results)
    all_quota_exhausted = all(not r.ok and "wyczerpany" in r.detail for r in results)

    if any_ok:
        summary = "Przynajmniej jeden model działa poprawnie."
    elif all_quota_exhausted:
        summary = "Limit tokenów wyczerpany dla WSZYSTKICH modeli — funkcje AI będą niedostępne do czasu resetu limitu."
    else:
        summary = "Żaden model nie odpowiada poprawnie — sprawdź klucz API i połączenie."

    return {
        "configured": True,
        "models": [r.to_dict() for r in results],
        "summary": summary,
    }
