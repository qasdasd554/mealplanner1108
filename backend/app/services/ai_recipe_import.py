"""Serwis rozpoznawania przepisów przez AI (Claude) — z wklejonego tekstu
albo zdjęcia.

WYMAGA zmiennej środowiskowej ANTHROPIC_API_KEY (klucz z
console.anthropic.com) ustawionej w środowisku backendu (Render). Bez
niej wywołania kończą się czytelnym błędem AIRecipeImportError, zamiast
niejasnym wyjątkiem.

Wideo NIE jest obsługiwane w tej wersji — wymagałoby dodatkowej
infrastruktury do wyciągania klatek/transkrypcji dźwięku.
"""

from __future__ import annotations

import json
import re

import httpx

from app.core.config import settings

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = "claude-sonnet-5"
ANTHROPIC_API_VERSION = "2023-06-01"

ALLOWED_UNITS = {"g", "kg", "ml", "l", "szt"}
ALLOWED_MEAL_TYPES = {"śniadanie", "obiad", "kolacja", "przekąska"}
ALLOWED_DIFFICULTIES = {"łatwy", "średni", "trudny"}


class AIRecipeImportError(Exception):
    """Błąd czytelny dla użytkownika (np. brak klucza API, AI nie
    rozpoznało przepisu, przekroczony limit)."""


def _build_prompt(available_products: list[str]) -> str:
    products_list = "\n".join(f"- {p}" for p in sorted(available_products))
    return f"""Jesteś asystentem kulinarnym. Twoim zadaniem jest rozpoznanie przepisu
kulinarnego z dostarczonej treści (tekstu albo zdjęcia) i zwrócenie go w
ściśle określonym formacie JSON, PO POLSKU.

WAŻNE ZASADY:
1. Odpowiedz WYŁĄCZNIE poprawnym obiektem JSON — bez żadnego tekstu przed
   ani po, bez bloków markdown (```), sam surowy JSON.
2. Pole "ingredients" MUSI używać nazw produktów WYŁĄCZNIE z poniższej
   listy dostępnych produktów. Dla każdego składnika przepisu wybierz
   NAJBLIŻSZY pasujący produkt z listy (np. jeśli przepis wymaga "cukru
   pudru", a na liście jest tylko "Cukier", użyj "Cukier"). Jeśli
   naprawdę żaden produkt z listy nie pasuje do składnika, pomiń ten
   składnik całkowicie (nie wymyślaj nowych nazw produktów).
3. Pole "unit" MUSI być jednym z: g, kg, ml, l, szt.
4. Pole "meal_type" MUSI być jednym z: śniadanie, obiad, kolacja, przekąska.
5. Pole "difficulty" MUSI być jednym z: łatwy, średni, trudny.
6. "instructions" to lista kroków po polsku, każdy z dokładnymi ilościami
   (np. "Podsmaż cebulę (100 g) na oleju"), tak jak w profesjonalnym
   przepisie kulinarnym.
7. Jeśli dostarczona treść w ogóle NIE zawiera przepisu kulinarnego (np.
   to przypadkowe zdjęcie niezwiązane z jedzeniem, albo bezsensowny
   tekst), zwróć dokładnie: {{"error": "Nie rozpoznano przepisu w podanej treści"}}

DOSTĘPNE PRODUKTY (używaj TYLKO tych nazw w "ingredients"):
{products_list}

FORMAT ODPOWIEDZI (przykład struktury, wypełnij prawdziwymi danymi):
{{
  "name": "Nazwa dania",
  "description": "Krótki, zachęcający opis (1-2 zdania)",
  "cuisine": "polska",
  "meal_type": "obiad",
  "prep_time_min": 15,
  "cook_time_min": 25,
  "servings": 4,
  "difficulty": "łatwy",
  "ingredients": [
    {{"product_name": "Cebula", "quantity": 100, "unit": "g"}},
    {{"product_name": "Jajka", "quantity": 2, "unit": "szt"}}
  ],
  "instructions": [
    "Pierwszy krok ze szczegółami i ilościami.",
    "Drugi krok..."
  ],
  "suggested_seasonings": ["oregano", "papryka słodka"]
}}"""


async def _call_claude(messages: list[dict]) -> str:
    if not settings.ANTHROPIC_API_KEY:
        raise AIRecipeImportError(
            "Funkcja dodawania przepisów przez AI nie jest jeszcze skonfigurowana "
            "(brak klucza API po stronie serwera). Skontaktuj się z administratorem."
        )

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            response = await client.post(
                ANTHROPIC_API_URL,
                headers={
                    "x-api-key": settings.ANTHROPIC_API_KEY,
                    "anthropic-version": ANTHROPIC_API_VERSION,
                    "content-type": "application/json",
                },
                json={
                    "model": ANTHROPIC_MODEL,
                    "max_tokens": 2000,
                    "messages": messages,
                },
            )
        except httpx.TimeoutException:
            raise AIRecipeImportError("Rozpoznawanie przepisu trwało zbyt długo. Spróbuj ponownie.")
        except httpx.HTTPError as exc:
            raise AIRecipeImportError(f"Nie udało się połączyć z usługą AI: {exc}")

    if response.status_code != 200:
        raise AIRecipeImportError(
            f"Usługa AI zwróciła błąd ({response.status_code}). Spróbuj ponownie później."
        )

    data = response.json()
    text_blocks = [b["text"] for b in data.get("content", []) if b.get("type") == "text"]
    if not text_blocks:
        raise AIRecipeImportError("Usługa AI nie zwróciła żadnej treści.")
    return "".join(text_blocks)


def _parse_recipe_json(raw_text: str) -> dict:
    # Na wypadek, gdyby model mimo instrukcji owinął odpowiedź w blok markdown.
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip())
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        raise AIRecipeImportError(
            "Nie udało się zinterpretować odpowiedzi AI jako przepisu. Spróbuj sformułować to inaczej."
        )

    if "error" in parsed:
        raise AIRecipeImportError(parsed["error"])

    required = {"name", "meal_type", "ingredients", "instructions"}
    if not required.issubset(parsed.keys()):
        raise AIRecipeImportError("AI zwróciło niekompletny przepis. Spróbuj ponownie.")

    return parsed


async def extract_recipe_from_text(recipe_text: str, available_products: list[str]) -> dict:
    """Zwraca ustrukturyzowany przepis (dict) rozpoznany z wklejonego tekstu."""
    prompt = _build_prompt(available_products)
    messages = [
        {
            "role": "user",
            "content": f"{prompt}\n\nTREŚĆ DO ROZPOZNANIA (tekst przepisu):\n{recipe_text}",
        }
    ]
    raw = await _call_claude(messages)
    return _parse_recipe_json(raw)


async def extract_recipe_from_photo(photo_base64: str, available_products: list[str]) -> dict:
    """Zwraca ustrukturyzowany przepis (dict) rozpoznany ze zdjęcia (np.
    fotografii karty przepisu, strony książki kucharskiej, albo
    gotowego dania — AI oszacuje wtedy prawdopodobny przepis)."""
    prompt = _build_prompt(available_products)
    messages = [
        {
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {"type": "base64", "media_type": "image/jpeg", "data": photo_base64},
                },
                {"type": "text", "text": prompt},
            ],
        }
    ]
    raw = await _call_claude(messages)
    return _parse_recipe_json(raw)


def validate_and_clean_recipe_dict(parsed: dict) -> dict:
    """Domyka luki/niepoprawne wartości w odpowiedzi AI zamiast na ślepo
    ufać, że model dokładnie trzymał się instrukcji formatu."""
    parsed["meal_type"] = parsed.get("meal_type") if parsed.get("meal_type") in ALLOWED_MEAL_TYPES else "obiad"
    parsed["difficulty"] = (
        parsed.get("difficulty") if parsed.get("difficulty") in ALLOWED_DIFFICULTIES else "łatwy"
    )
    try:
        parsed["servings"] = max(1, int(parsed.get("servings", 2)))
    except (TypeError, ValueError):
        parsed["servings"] = 2

    cleaned_ingredients = []
    for ing in parsed.get("ingredients", []):
        unit = ing.get("unit")
        if unit not in ALLOWED_UNITS:
            continue
        try:
            qty = float(ing.get("quantity"))
        except (TypeError, ValueError):
            continue
        if qty <= 0 or not ing.get("product_name"):
            continue
        cleaned_ingredients.append({"product_name": ing["product_name"], "quantity": qty, "unit": unit})
    parsed["ingredients"] = cleaned_ingredients

    parsed["instructions"] = [
        s.strip() for s in parsed.get("instructions", []) if isinstance(s, str) and s.strip()
    ]
    parsed["suggested_seasonings"] = [
        s.strip() for s in parsed.get("suggested_seasonings", []) if isinstance(s, str) and s.strip()
    ]
    return parsed
