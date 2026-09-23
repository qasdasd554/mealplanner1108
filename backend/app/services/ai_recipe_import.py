"""Serwis rozpoznawania przepisów przez AI (Google Gemini) — z wklejonego
tekstu albo zdjęcia.

WYMAGA zmiennej środowiskowej GEMINI_API_KEY (klucz z
aistudio.google.com) ustawionej w środowisku backendu (Render). Bez niej
wywołania kończą się czytelnym błędem AIRecipeImportError, zamiast
niejasnym wyjątkiem.

Użyty jest darmowy poziom Google Gemini — hojniejszy limit niż wiele
innych darmowych API i jeden z nielicznych, który dobrze radzi sobie
zarówno z tekstem, jak i obrazami bez opłat. Żaden dostawca nie oferuje
FAKTYCZNIE nieograniczonego darmowego dostępu — zawsze jest jakiś dzienny
limit, więc endpoint ma też WŁASNY, niezależny limit (patrz
app/core/rate_limit.py) jako dodatkowe zabezpieczenie.

Wideo NIE jest obsługiwane w tej wersji — wymagałoby dodatkowej
infrastruktury do wyciągania klatek/transkrypcji dźwięku.
"""

from __future__ import annotations

import asyncio
from difflib import SequenceMatcher
import json
import logging
import math
import re
import time
import unicodedata

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# Kolejność modeli do wypróbowania — każdy model na darmowym poziomie
# Gemini ma WŁASNY, OSOBNY limit (RPM/TPM/RPD), więc wyczerpanie limitu
# głównego modelu wcale nie oznacza, że limit "lite" jest też wyczerpany.
# Jeśli główny model odmawia (limit dzienny/minutowy albo uporczywe
# przeciążenie mimo ponawiania), automatycznie próbujemy kolejnego z listy
# zamiast od razu poddawać się użytkownikowi.
# UWAGA (naprawa — centralizacja): lista modeli była wcześniej
# zduplikowana osobno w tym pliku, promo_ai_scanner.py i
# gemini_status.py — co doprowadziło do realnego rozjazdu (panel admina
# przez długi czas pokazywał tylko 3 stare modele, mimo że tutaj
# faktycznie próbowano już 6). Teraz JEDNO źródło prawdy w
# gemini_models.py, importowane wszędzie tam, gdzie potrzebne.
from app.services.gemini_models import GEMINI_MODELS

# Krótka pamięć niedostępnych modeli chroni następnych użytkowników przed
# powtarzaniem tych samych 429/503 na początku każdego importu.
_model_unavailable_until: dict[str, float] = {}

ALLOWED_UNITS = {"g", "kg", "ml", "l", "szt"}
ALLOWED_MEAL_TYPES = {"śniadanie", "obiad", "kolacja", "przekąska", "deser"}
ALLOWED_DIFFICULTIES = {"łatwy", "średni", "trudny"}


class AIRecipeImportError(Exception):
    """Błąd czytelny dla użytkownika (np. brak klucza API, AI nie
    rozpoznało przepisu, przekroczony limit)."""


class _ModelUnavailableError(Exception):
    """Wewnętrzny sygnał (NIE pokazywany użytkownikowi wprost) — ten
    KONKRETNY model jest chwilowo niedostępny (wyczerpany limit albo
    uporczywe przeciążenie mimo ponowień). Funkcja nadrzędna łapie ten
    wyjątek i próbuje KOLEJNEGO modelu z listy GEMINI_MODELS, zamiast
    od razu poddawać się użytkownikowi.

    `reason` niesie ROZPOZNANĄ przyczynę ("quota_exhausted" /
    "rate_limited" / "overloaded" / "unknown") — używane do zbudowania
    trafniejszego komunikatu KOŃCOWEGO, jeśli WSZYSTKIE modele zawiodą."""

    def __init__(self, message: str, reason: str = "unknown"):
        super().__init__(message)
        self.reason = reason


def _normalize_product_name(value: str) -> str:
    ascii_text = "".join(
        char for char in unicodedata.normalize("NFKD", value.casefold())
        if not unicodedata.combining(char)
    )
    return " ".join(re.findall(r"[\w]+", ascii_text, flags=re.UNICODE))


def match_product_name(name: str, available_products: list[str]) -> str | None:
    """Zwraca pewne dopasowanie; nie podmienia niepodobnych składników."""
    target = _normalize_product_name(name)
    if not target:
        return None
    normalized = [(candidate, _normalize_product_name(candidate)) for candidate in available_products]
    for candidate, key in normalized:
        if key == target:
            return candidate
    scored = sorted(
        ((SequenceMatcher(None, target, key).ratio(), candidate) for candidate, key in normalized),
        reverse=True,
    )
    if not scored or scored[0][0] < 0.78:
        return None
    if len(scored) > 1 and scored[0][0] - scored[1][0] < 0.04:
        return None
    return scored[0][1]


def _select_prompt_products(available_products: list[str], context: str | None) -> list[str]:
    """Ogranicza wielkość promptu niezależnie od liczby produktów w bazie."""
    unique = list(dict.fromkeys(available_products))
    if len(unique) <= 140:
        return unique
    words = set(_normalize_product_name(context or "").split())
    scored = []
    for name in unique:
        product_words = set(_normalize_product_name(name).split())
        overlap = len(words & product_words)
        if overlap:
            scored.append((overlap, name))
    scored.sort(key=lambda entry: (-entry[0], entry[1]))
    selected = [name for _, name in scored[:140]]
    if len(selected) < 140:
        # Krótkie, ogólne nazwy są użyteczniejsze w promptcie niż setki
        # wariantów marek. Pełny katalog pozostaje dostępny do dopasowania
        # po odpowiedzi modelu.
        staples = sorted(unique, key=lambda name: (len(name.split()), len(name), name.casefold()))
        seen = set(selected)
        for name in staples:
            if name not in seen:
                selected.append(name)
                seen.add(name)
            if len(selected) == 140:
                break
    return selected


def _build_prompt(available_products: list[str], *, context: str | None = None) -> str:
    products_list = "\n".join(
        f"- {p}" for p in sorted(_select_prompt_products(available_products, context))
    )
    return f"""Jesteś asystentem kulinarnym. Otrzymujesz treść (tekst, zdjęcie albo
samą nazwę dania) i masz dostarczyć przepis kulinarny w ściśle określonym
formacie JSON, PO POLSKU.

Treść może być JEDNYM z dwóch rodzajów — rozpoznaj, z którym masz do
czynienia, i zareaguj odpowiednio:

A) GOTOWY PRZEPIS (np. wklejony tekst z blogu, zdjęcie karty przepisu albo
   strony książki kucharskiej, zawierające już listę składników i/albo
   sposób przygotowania) — WYCIĄGNIJ go wiernie, tak jak jest napisany,
   dopasowując tylko nazwy składników do dostępnego katalogu.

B) SAMA NAZWA DANIA ALBO ZDJĘCIE GOTOWEGO DANIA (np. użytkownik wpisał
   tylko "rosół" albo "lasagne", albo przesłał zdjęcie ugotowanego
   posiłku bez żadnego opisu) — to NIE jest błąd ani "brak treści do
   rozpoznania". W tym przypadku SAM UŁÓŻ autentyczny, typowy przepis na
   to danie (klasyczna, sprawdzona wersja), preferując produkty
   z poniższej listy. To jest oczekiwane, normalne zachowanie — nie
   proś użytkownika o więcej informacji, po prostu zaproponuj sensowny
   przepis.

WAŻNE ZASADY:
1. Odpowiedz WYŁĄCZNIE poprawnym obiektem JSON — bez żadnego tekstu przed
   ani po, bez bloków markdown (```), sam surowy JSON.
2. Dla każdego składnika wybierz NAJBLIŻSZY pasujący produkt z poniższej
   listy (np. "cukier puder" może odpowiadać "Cukier"). Jeśli na liście
   nie ma dobrego odpowiednika, zachowaj oryginalną nazwę składnika;
   nie pomijaj składników z przepisu. Serwer dopasuje je do pełnego katalogu.
3. Pole "unit" MUSI być jednym z: g, kg, ml, l, szt.
4. Pole "meal_type" MUSI być jednym z: śniadanie, obiad, kolacja, przekąska, deser.
5. Pole "difficulty" MUSI być jednym z: łatwy, średni, trudny.
6. "instructions" to lista kroków po polsku, każdy z dokładnymi ilościami
   (np. "Podsmaż cebulę (100 g) na oleju"), tak jak w profesjonalnym
   przepisie kulinarnym — wystarczająco szczegółowe, żeby osoba z
   niewielkim doświadczeniem kulinarnym poradziła sobie z przygotowaniem.
7. Zwróć błąd — dokładnie {{"error": "Nie rozpoznano przepisu w podanej treści"}}
   — TYLKO gdy treść jest zupełnie NIEZWIĄZANA z jedzeniem (np. zdjęcie
   samochodu, przypadkowy, bezsensowny tekst) — NIGDY dla samej nazwy
   dania ani zdjęcia posiłku, które trzeba potraktować jak przypadek (B)
   powyżej.

PREFEROWANE NAZWY PRODUKTÓW (fragment katalogu):
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


async def _call_gemini_model(parts: list[dict], model: str, *, timeout_seconds: float = 25.0) -> str:
    """Wywołuje JEDEN, konkretny model Gemini. Ponawia próbę przy błędach
    przejściowych (503/502/500), ale przy wyczerpanym limicie (429) albo
    uporczywym przeciążeniu mimo ponowień rzuca `_ModelUnavailableError`
    — to sygnał dla `_call_gemini`, żeby spróbować NASTĘPNEGO modelu
    z listy, a nie od razu poddawać się użytkownikowi."""
    url = GEMINI_API_URL.format(model=model)
    request_body = {
        "contents": [{"parts": parts, "role": "user"}],
        # Wymuszenie czystego JSON-a w odpowiedzi — bez tego trzeba by
        # ręcznie wyciągać JSON spośród ewentualnego tekstu/markdown wokół
        # niego.
        "generationConfig": {
            "responseMimeType": "application/json",
            "thinkingConfig": {"thinkingLevel": "LOW"},
            "maxOutputTokens": 8192,
        },
    }

    # Przy przeciążeniu lub timeoutcie przechodzimy do kolejnego modelu.
    # Ponawianie tej samej próby wydłużało import do kilku minut.
    max_attempts = 1

    for attempt in range(1, max_attempts + 1):
        async with httpx.AsyncClient(timeout=timeout_seconds) as client:
            try:
                response = await client.post(
                    url,
                    headers={
                        "x-goog-api-key": settings.GEMINI_API_KEY,
                        "content-type": "application/json",
                    },
                    json=request_body,
                )
            except httpx.TimeoutException as exc:
                # Timeout jednego modelu nie oznacza porażki całego importu.
                # Kolejny model może odpowiedzieć prawidłowo w kilka sekund.
                raise _ModelUnavailableError(
                    f"Model {model}: nie odpowiedział w {timeout_seconds:.0f} s",
                    reason="timeout",
                ) from exc
            except httpx.HTTPError as exc:
                raise _ModelUnavailableError(
                    f"Model {model}: błąd połączenia z usługą AI: {exc}",
                    reason="connection",
                ) from exc

        if response.status_code == 200:
            break

        if response.status_code == 429:
            # Wyczerpany limit TEGO modelu — każdy model Gemini ma własny,
            # osobny limit, więc to NIE znaczy, że kolejny model też jest
            # niedostępny. Rozróżniamy PRZYCZYNĘ (limit dzienny wyczerpany
            # vs chwilowy natłok zapytań na minutę) na podstawie treści
            # odpowiedzi, żeby komunikat końcowy dla użytkownika (jeśli
            # WSZYSTKIE modele zawiodą) mógł być trafniejszy niż ogólne
            # "spróbuj później".
            from app.services.gemini_status import classify_gemini_error

            try:
                error_body = response.json()
            except Exception:
                error_body = None
            reason = classify_gemini_error(429, error_body)
            raise _ModelUnavailableError(f"Model {model}: wyczerpany limit (429)", reason=reason)

        if response.status_code == 404:
            raise _ModelUnavailableError(
                f"Model {model}: niedostępny (404)", reason="unavailable"
            )

        if response.status_code in (503, 502, 500) and attempt < max_attempts:
            await asyncio.sleep(attempt * 1.5)
            continue

        if response.status_code in (503, 502, 500):
            attempts_word = "próby" if max_attempts == 1 else "prób"
            raise _ModelUnavailableError(
                f"Model {model}: przeciążony ({response.status_code}) mimo {max_attempts} {attempts_word}",
                reason="overloaded",
            )

        raise AIRecipeImportError(
            f"Usługa AI zwróciła błąd ({response.status_code}). Spróbuj ponownie za chwilę."
        )

    data = response.json()
    try:
        candidates = data["candidates"]
        text_parts = candidates[0]["content"]["parts"]
        text = "".join(p.get("text", "") for p in text_parts)
    except (KeyError, IndexError):
        raise AIRecipeImportError("Usługa AI nie zwróciła żadnej treści.")

    if not text.strip():
        raise AIRecipeImportError("Usługa AI nie zwróciła żadnej treści.")
    return text


async def _call_gemini(
    parts: list[dict],
    *,
    timeout_seconds: float = 35.0,
    max_total_seconds: float | None = None,
) -> str:
    """Próbuje kolejnych modeli z GEMINI_MODELS (najpierw główny, potem
    "lite" jako zapasowy), przechodząc do następnego, gdy poprzedni
    zgłosi `_ModelUnavailableError` (limit wyczerpany albo uporczywe
    przeciążenie). Dopiero gdy WSZYSTKIE modele zawiodą, zwraca
    użytkownikowi czytelny, ostateczny komunikat.

    [timeout_seconds]: analiza ZDJĘCIA (multimodalny prompt) jest z
    natury cięższa i wolniejsza niż czysty tekst — extract_recipe_from_
    photo przekazuje tu wyższą wartość niż domyślna, żeby nie odcinać
    faktycznie udanych, tylko nieco wolniejszych odpowiedzi."""
    if not settings.GEMINI_API_KEY:
        raise AIRecipeImportError(
            "Funkcja dodawania przepisów przez AI nie jest jeszcze skonfigurowana "
            "(brak klucza API po stronie serwera). Skontaktuj się z administratorem."
        )

    unavailable_reasons: list[str] = []
    reason_types: list[str] = []
    deadline = time.monotonic() + (
        max_total_seconds
        if max_total_seconds is not None
        else (120 if timeout_seconds > 35 else 95)
    )
    for model in GEMINI_MODELS:
        if _model_unavailable_until.get(model, 0) > time.monotonic():
            continue
        remaining = deadline - time.monotonic()
        if remaining < 8:
            break
        try:
            return await _call_gemini_model(
                parts, model, timeout_seconds=min(timeout_seconds, remaining),
            )
        except _ModelUnavailableError as exc:
            logger.warning("Gemini: %s — próbuję kolejnego modelu, jeśli jest", exc)
            _model_unavailable_until[model] = time.monotonic() + (
                300 if exc.reason in {"quota_exhausted", "rate_limited"} else 20
            )
            unavailable_reasons.append(str(exc))
            reason_types.append(exc.reason)
            continue

    # UWAGA (nowe): jeśli WSZYSTKIE modele zawiodły z powodu wyczerpanego
    # DZIENNEGO limitu (nie chwilowego natłoku zapytań na minutę), mówimy
    # to userowi wprost — "spróbuj za chwilę" byłoby mylące, skoro limit
    # dzienny reali się dopiero następnego dnia.
    if reason_types and all(r == "quota_exhausted" for r in reason_types):
        raise AIRecipeImportError(
            "Dzienny limit zapytań do AI został wyczerpany dla wszystkich dostępnych "
            "modeli. Spróbuj ponownie jutro, albo skontaktuj się z administratorem."
        )
    if reason_types and all(r == "rate_limited" for r in reason_types):
        raise AIRecipeImportError(
            "Zbyt wiele zapytań do AI w krótkim czasie. Odczekaj minutę i spróbuj ponownie."
        )
    if "timeout" in reason_types:
        raise AIRecipeImportError(
            "Modele AI nie odpowiedziały w wyznaczonym czasie. "
            "Przepis nie został dodany i nie pobrano punktów. Spróbuj ponownie za chwilę."
        )

    raise AIRecipeImportError(
        f"Usługa AI jest chwilowo niedostępna (wypróbowano {len(GEMINI_MODELS)} modeli, "
        "wszystkie osiągnęły limit lub są przeciążone). Spróbuj ponownie za chwilę."
    )


def _parse_recipe_json(raw_text: str) -> dict:
    # Na wypadek, gdyby model mimo instrukcji owinął odpowiedź w blok markdown
    # (responseMimeType="application/json" zwykle to eliminuje, ale nie ma
    # gwarancji przy każdym modelu/wersji API).
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip())
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        raise AIRecipeImportError(
            "Nie udało się zinterpretować odpowiedzi AI jako przepisu. Spróbuj sformułować to inaczej."
        )

    if not isinstance(parsed, dict):
        raise AIRecipeImportError("AI zwróciło niepoprawny format przepisu. Spróbuj ponownie.")
    if "error" in parsed:
        raise AIRecipeImportError(parsed["error"])

    required = {"name", "meal_type", "ingredients", "instructions"}
    if not required.issubset(parsed.keys()):
        raise AIRecipeImportError("AI zwróciło niekompletny przepis. Spróbuj ponownie.")

    return parsed


async def extract_recipe_from_text(recipe_text: str, available_products: list[str]) -> dict:
    """Zwraca ustrukturyzowany przepis (dict) rozpoznany z wklejonego tekstu."""
    prompt = _build_prompt(available_products, context=recipe_text)
    parts = [{"text": f"{prompt}\n\nTREŚĆ DO ROZPOZNANIA (tekst przepisu):\n{recipe_text}"}]
    raw = await _call_gemini(parts)
    return _parse_recipe_json(raw)


async def revise_recipe_with_ai(
    recipe: dict, instruction: str, available_products: list[str]
) -> dict:
    """Zwraca pełny przepis po jednej zmianie opisanej przez właściciela."""
    original = json.dumps(recipe, ensure_ascii=False)
    context = f"{original}\n{instruction}"
    prompt = _build_prompt(available_products, context=context)
    parts = [{"text": (
        f"{prompt}\n\nISTNIEJĄCY PRZEPIS (JSON):\n{original}\n\n"
        f"POLECENIE WŁAŚCICIELA: {instruction}\n\n"
        "Zmień istniejący przepis zgodnie z poleceniem. Zachowaj pozostałe "
        "składniki i kroki, o ile polecenie nie wymaga ich zmiany. Zwróć "
        "CAŁY przepis w formacie JSON powyżej, nie tylko fragment różnic. "
        "Nie dodawaj składników, których nie ma w katalogu."
    )}]
    raw = await _call_gemini(parts)
    return validate_and_clean_recipe_dict(_parse_recipe_json(raw))


def _jsonld_instruction_text(value) -> list[str]:
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    if isinstance(value, list):
        return [step for item in value for step in _jsonld_instruction_text(item)]
    if isinstance(value, dict):
        if value.get("text"):
            return _jsonld_instruction_text(value["text"])
        return _jsonld_instruction_text(value.get("itemListElement", []))
    return []


def _jsonld_recipe_from_soup(soup) -> dict | None:
    """Szybka ścieżka dla blogów publikujących schema.org/Recipe."""
    def find_recipe(value):
        if isinstance(value, list):
            for item in value:
                found = find_recipe(item)
                if found:
                    return found
        if isinstance(value, dict):
            types = value.get("@type", [])
            if isinstance(types, str):
                types = [types]
            if any(str(kind).split("/")[-1] == "Recipe" for kind in types):
                return value
            for nested in value.values():
                found = find_recipe(nested)
                if found:
                    return found
        return None

    for script in soup.find_all("script", attrs={"type": "application/ld+json"}):
        try:
            recipe = find_recipe(json.loads(script.string or ""))
        except (ValueError, TypeError):
            continue
        if not recipe or not isinstance(recipe.get("recipeIngredient"), list):
            continue
        if not isinstance(recipe.get("name"), str) or not recipe["name"].strip():
            continue
        raw_ingredients = recipe["recipeIngredient"]
        ingredients = []
        for raw in raw_ingredients:
            if not isinstance(raw, str):
                break
            match = re.match(
                r"^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|szt\.?|sztuk[aię]?)?\s+(.+?)\s*$",
                raw, flags=re.IGNORECASE,
            )
            if not match:
                break
            quantity, unit, name = match.groups()
            ingredients.append({
                "product_name": name.strip(" ,-"),
                "quantity": float(quantity.replace(",", ".")),
                "unit": "szt" if not unit or unit.lower().startswith("szt") else unit.lower(),
            })
        if len(ingredients) != len(raw_ingredients) or not ingredients:
            continue
        instructions = _jsonld_instruction_text(recipe.get("recipeInstructions"))
        if not instructions:
            continue
        yield_text = recipe.get("recipeYield", 2)
        if isinstance(yield_text, list):
            yield_text = yield_text[0] if yield_text else 2
        yield_match = re.search(r"\d+", str(yield_text))
        servings = int(yield_match.group()) if yield_match else 2
        category = str(recipe.get("recipeCategory") or "").casefold()
        if any(word in category for word in ("deser", "dessert", "ciasto")):
            meal_type = "deser"
        elif any(word in category for word in ("śniad", "breakfast")):
            meal_type = "śniadanie"
        elif any(word in category for word in ("kolac", "dinner", "supper")):
            meal_type = "kolacja"
        else:
            meal_type = "obiad"
        return {
            "name": recipe["name"][:300],
            "description": str(recipe.get("description") or "")[:1000],
            "meal_type": meal_type,
            "difficulty": "łatwy",
            "servings": max(1, servings),
            "ingredients": ingredients,
            "instructions": instructions,
            "suggested_seasonings": [],
        }
    return None


async def _fetch_url_text(url: str) -> tuple[str, dict | None]:
    """Pobiera i wyciąga tekst czytelny dla człowieka ze strony pod danym
    adresem — do rozpoznawania przepisu z linku (blog kulinarny, TikTok,
    Instagram itp.).

    UCZCIWE OGRANICZENIE: strony takie jak TikTok są w większości
    renderowane przez JavaScript — surowe pobranie strony (bez
    uruchamiania przeglądarki) zwykle daje dostęp TYLKO do opisu/tytułu
    w metadanych strony (Open Graph), NIE do treści samego nagrania ani
    napisów mówionych. Jeśli twórca opisał przepis w podpisie pod
    filmikiem — zadziała. Jeśli przepis pada wyłącznie w mowie w
    nagraniu — rozpoznawanie może się nie udać.
    """
    import httpx
    from bs4 import BeautifulSoup

    async with httpx.AsyncClient(timeout=12.0, follow_redirects=True) as client:
        try:
            response = await client.get(
                url,
                headers={
                    # UWAGA (naprawa): nagłówki tylko z User-Agent są łatwym
                    # sygnałem "to nie jest prawdziwa przeglądarka" dla stron
                    # z ochroną przed botami (a TikTok jest pod tym względem
                    # szczególnie agresywny, zwłaszcza na krótkich linkach
                    # przekierowujących typu vm.tiktok.com). Pełniejszy,
                    # bardziej realistyczny zestaw nagłówków (dokładnie taki,
                    # jaki wysyła prawdziwa przeglądarka) zmniejsza ryzyko
                    # trafienia na stronę z wyzwaniem/CAPTCHA zamiast
                    # prawdziwej treści.
                    "User-Agent": (
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
                    ),
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                    "Accept-Language": "pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7",
                    "Sec-Fetch-Mode": "navigate",
                    "Sec-Fetch-Dest": "document",
                    "Sec-Fetch-Site": "none",
                    "Upgrade-Insecure-Requests": "1",
                },
            )
        except httpx.HTTPError as exc:
            raise AIRecipeImportError(f"Nie udało się otworzyć podanego linku: {exc}")

    if response.status_code != 200:
        raise AIRecipeImportError(
            f"Podana strona zwróciła błąd ({response.status_code}). Sprawdź, czy link jest poprawny."
        )

    soup = BeautifulSoup(response.text, "html.parser")
    structured_recipe = _jsonld_recipe_from_soup(soup)

    parts: list[str] = []
    title = soup.find("title")
    if title and title.get_text(strip=True):
        parts.append(title.get_text(strip=True))

    for meta_name, attrs in (
        ("og:title", {"property": "og:title"}),
        ("og:description", {"property": "og:description"}),
        ("description", {"name": "description"}),
    ):
        tag = soup.find("meta", attrs=attrs)
        if tag and tag.get("content"):
            parts.append(tag["content"])

    # UWAGA (nowe): TikTok (i podobne strony renderowane po stronie serwera
    # przez React/Next.js) NIE trzyma opisu filmiku jako zwykłego,
    # widocznego tekstu HTML — jest on zaszyty w bloku JSON wewnątrz tagu
    # <script>, którego zwykłe wyciąganie tekstu (get_text) w ogóle nie
    # widzi (bo skrypty są celowo pomijane). Szukamy więc DODATKOWO w
    # treści tych skryptów, przeszukując zagnieżdżony JSON pod kątem pól
    # o nazwie "desc"/"description" — to najbardziej odporne podejście,
    # bo nie zależy od DOKŁADNEJ struktury zagnieżdżenia, którą TikTok
    # może zmieniać bez ostrzeżenia.
    json_texts = _extract_desc_fields_from_scripts(soup)
    parts.extend(json_texts)

    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()
    article = soup.find("article") or soup.find("main") or soup
    body_text = article.get_text(separator="\n", strip=True)
    if body_text:
        # Limit rozmiaru — nie chcemy wysyłać całej, ogromnej strony do AI.
        parts.append(body_text[:8000])

    combined = "\n\n".join(p for p in parts if p)
    if not combined.strip() and structured_recipe is not None:
        return "", structured_recipe
    if not combined.strip():
        raise AIRecipeImportError(
            "Nie udało się wyciągnąć żadnej treści z podanego linku."
        )
    # UWAGA (nowe): jeśli strona zwróciła bardzo mało treści — typowy
    # objaw tego, że np. TikTok pokazał generyczną stronę/wyzwanie
    # zamiast prawdziwej treści filmiku (ochrona przed botami) — lepiej
    # od razu jasno to powiedzieć, niż wysłać AI prawie pustą treść i
    # dostać mylące "nie rozpoznano przepisu", nie wiedząc dlaczego.
    if len(combined.strip()) < 40 and structured_recipe is None:
        raise AIRecipeImportError(
            "Nie udało się odczytać treści z tego linku (strona mogła zablokować "
            "automatyczny dostęp). Spróbuj wkleić opis/podpis filmiku bezpośrednio "
            "jako tekst, w zakładce \"Wklej tekst\"."
        )
    # UWAGA (naprawa — "długo się ładuje i wywala błąd"): treść WYSTARCZAJĄCO
    # długa (>40 znaków) mogła i tak być bezwartościowa — np. strona logowania
    # TikToka, baner "zaakceptuj ciasteczka" albo komunikat "włącz JavaScript"
    # mają wystarczająco dużo tekstu, żeby przejść poprzednią walidację, ale
    # NIE zawierają żadnego przepisu. Bez tego sprawdzenia taka treść leciała
    # przez CAŁY, kosztowny łańcuch 6 modeli AI (do 150s w najgorszym razie)
    # zanim ostatecznie i tak się nie udało — użytkownik czekał długo tylko
    # po to, żeby dostać ten sam, nieuchronny błąd. Wykrywanie tych sygnałów
    # PRZED wywołaniem AI daje szybki, czytelny błąd zamiast długiego czekania
    # na z góry przesądzoną porażkę.
    _BLOCKED_PAGE_SIGNALS = (
        "log in to tiktok", "zaloguj się do tiktok", "logowanie do tiktok",
        "verify you are human", "zweryfikuj, że jesteś człowiekiem",
        "enable javascript", "włącz javascript", "javascript is required",
        "captcha", "access denied", "odmowa dostępu",
        "sign up for tiktok", "zarejestruj się w tiktok",
    )
    combined_lower = combined.lower()
    signal_hits = sum(1 for s in _BLOCKED_PAGE_SIGNALS if s in combined_lower)
    # Próg 2 (nie 1) celowo — pojedyncze, przypadkowe trafienie słowa
    # (np. strona faktycznie WSPOMINA o logowaniu w treści przepisu) nie
    # powinno fałszywie blokować poprawnego rozpoznawania. Dwa niezależne
    # sygnały naraz to znacznie mocniejszy dowód, że to faktycznie strona
    # blokady, nie prawdziwa treść.
    if signal_hits >= 2 and structured_recipe is None:
        raise AIRecipeImportError(
            "Ten link prowadzi do strony logowania/weryfikacji zamiast prawdziwej "
            "treści (typowe zabezpieczenie TikToka przed automatycznym dostępem). "
            "Otwórz filmik w aplikacji TikTok, skopiuj opis pod nim i wklej go "
            "bezpośrednio jako tekst, w zakładce \"Wklej tekst\"."
        )
    return combined, structured_recipe


def _extract_desc_fields_from_scripts(soup) -> list[str]:
    """Przeszukuje wszystkie tagi <script type="application/json"> (i
    podobne) na stronie w poszukiwaniu zagnieżdżonych pól "desc" —
    dokładnie tak TikTok (i inne strony renderowane po stronie serwera)
    przechowuje opis/podpis filmiku w danych do "rehydracji" strony przez
    JavaScript. Zwraca listę znalezionych, sensownie długich tekstów."""
    import json as json_module

    found: list[str] = []

    def _walk(node, depth=0):
        if depth > 12 or len(found) >= 5:
            return
        if isinstance(node, dict):
            for key, value in node.items():
                if key in ("desc", "description", "caption") and isinstance(value, str) and len(value.strip()) > 3:
                    found.append(value.strip())
                else:
                    _walk(value, depth + 1)
        elif isinstance(node, list):
            for item in node:
                _walk(item, depth + 1)

    for script in soup.find_all("script"):
        script_type = script.get("type", "")
        script_id = script.get("id", "")
        # Ograniczamy się do skryptów, które WYGLĄDAJĄ jak dane stanu
        # aplikacji (JSON), nie każdy <script> na stronie (np. Google
        # Analytics) — po samym typie/id, albo po prostu próbując
        # sparsować jako JSON i po cichu pomijając te, które nim nie są.
        if script_type not in ("application/json", "application/ld+json") and "SIGI_STATE" not in script_id and "REHYDRATION" not in script_id:
            continue
        raw = script.string
        if not raw:
            continue
        try:
            data = json_module.loads(raw)
        except (json_module.JSONDecodeError, TypeError):
            continue
        _walk(data)

    return found


async def extract_recipe_from_url(url: str, available_products: list[str]) -> dict:
    """Rozpoznaje przepis na podstawie treści strony pod danym adresem
    URL (blog kulinarny, TikTok, Instagram itp.) — patrz ograniczenia
    w docstringu `_fetch_url_text`."""
    page_text, structured_recipe = await _fetch_url_text(url)
    if structured_recipe is not None:
        matched = []
        for ingredient in structured_recipe["ingredients"]:
            canonical = match_product_name(ingredient["product_name"], available_products)
            if canonical is None:
                break
            matched.append({**ingredient, "product_name": canonical})
        if len(matched) == len(structured_recipe["ingredients"]):
            structured_recipe["ingredients"] = matched
            logger.info("Import linku: kompletny schema.org/Recipe, bez wywołania AI")
            return structured_recipe
        # Nie zgadujemy brakujących produktów, ale przekazujemy AI krótki,
        # merytoryczny JSON-LD zamiast nawigacji/stopki strony.
        page_text = json.dumps(structured_recipe, ensure_ascii=False)
    return await extract_recipe_from_text(page_text, available_products)


async def extract_recipe_from_photo(
    photo_base64: str, available_products: list[str], hint: str | None = None
) -> dict:
    """Zwraca ustrukturyzowany przepis (dict) rozpoznany ze zdjęcia (np.
    fotografii karty przepisu, strony książki kucharskiej, albo
    gotowego dania — AI oszacuje wtedy prawdopodobny przepis).

    [hint] to opcjonalna, krótka podpowiedź od użytkownika (np. "to jest
    szarlotka") — pomaga AI, gdy zdjęcie samo w sobie jest niejednoznaczne
    (np. danie trudne do rozpoznania wizualnie)."""
    prompt = _build_prompt(available_products, context=hint)
    if hint:
        prompt += f'\n\nDODATKOWA PODPOWIEDŹ OD UŻYTKOWNIKA (potraktuj jako wskazówkę, co widać na zdjęciu): "{hint}"'
    parts = [
        # UWAGA: celowo camelCase (inlineData/mimeType) — to bezpieczniejszy,
        # szerzej udokumentowany wariant dla obrazów w Gemini API. Parser
        # Google zwykle akceptuje też snake_case, ale camelCase eliminuje
        # wszelkie wątpliwości.
        {"inlineData": {"mimeType": "image/jpeg", "data": photo_base64}},
        {"text": prompt},
    ]
    # Zdjęcie ma dłuższy limit na model, a timeout przełącza na następny.
    raw = await _call_gemini(parts, timeout_seconds=45.0)
    return _parse_recipe_json(raw)


def validate_and_clean_recipe_dict(parsed: dict) -> dict:
    """Domyka luki/niepoprawne wartości w odpowiedzi AI zamiast na ślepo
    ufać, że model dokładnie trzymał się instrukcji formatu."""
    name = parsed.get("name")
    if not isinstance(name, str) or not name.strip():
        raise AIRecipeImportError("AI nie podało nazwy przepisu. Spróbuj ponownie.")
    parsed["name"] = name.strip()[:300]
    for key in ("description", "cuisine"):
        value = parsed.get(key)
        parsed[key] = value.strip() if isinstance(value, str) and value.strip() else None
    if parsed["cuisine"]:
        parsed["cuisine"] = parsed["cuisine"][:100]
    parsed["meal_type"] = parsed.get("meal_type") if parsed.get("meal_type") in ALLOWED_MEAL_TYPES else "obiad"
    parsed["difficulty"] = (
        parsed.get("difficulty") if parsed.get("difficulty") in ALLOWED_DIFFICULTIES else "łatwy"
    )
    try:
        parsed["servings"] = min(100, max(1, int(parsed.get("servings", 2))))
    except (TypeError, ValueError):
        parsed["servings"] = 2

    for key in ("prep_time_min", "cook_time_min"):
        try:
            value = int(parsed[key]) if parsed.get(key) is not None else None
        except (TypeError, ValueError, OverflowError):
            value = None
        parsed[key] = value if value is not None and 0 <= value <= 1440 else None

    cleaned_ingredients = []
    for ing in parsed.get("ingredients", []) if isinstance(parsed.get("ingredients"), list) else []:
        if not isinstance(ing, dict):
            continue
        unit = ing.get("unit")
        if unit not in ALLOWED_UNITS:
            continue
        try:
            qty = float(ing.get("quantity"))
        except (TypeError, ValueError):
            continue
        product_name = ing.get("product_name")
        if not math.isfinite(qty) or qty <= 0 or not isinstance(product_name, str) or not product_name.strip():
            continue
        cleaned_ingredients.append({"product_name": product_name.strip(), "quantity": qty, "unit": unit})
    parsed["ingredients"] = cleaned_ingredients

    instructions = parsed.get("instructions")
    seasonings = parsed.get("suggested_seasonings")
    parsed["instructions"] = [
        s.strip() for s in instructions if isinstance(s, str) and s.strip()
    ] if isinstance(instructions, list) else []
    parsed["suggested_seasonings"] = [
        s.strip() for s in seasonings if isinstance(s, str) and s.strip()
    ] if isinstance(seasonings, list) else []
    return parsed
