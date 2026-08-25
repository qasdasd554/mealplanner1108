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
import json
import logging
import re

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

ALLOWED_UNITS = {"g", "kg", "ml", "l", "szt"}
ALLOWED_MEAL_TYPES = {"śniadanie", "obiad", "kolacja", "przekąska"}
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


def _build_prompt(available_products: list[str]) -> str:
    products_list = "\n".join(f"- {p}" for p in sorted(available_products))
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
   to danie (klasyczna, sprawdzona wersja), używając WYŁĄCZNIE produktów
   z dostępnego katalogu. To jest oczekiwane, normalne zachowanie — nie
   proś użytkownika o więcej informacji, po prostu zaproponuj sensowny
   przepis.

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
   przepisie kulinarnym — wystarczająco szczegółowe, żeby osoba z
   niewielkim doświadczeniem kulinarnym poradziła sobie z przygotowaniem.
7. Zwróć błąd — dokładnie {{"error": "Nie rozpoznano przepisu w podanej treści"}}
   — TYLKO gdy treść jest zupełnie NIEZWIĄZANA z jedzeniem (np. zdjęcie
   samochodu, przypadkowy, bezsensowny tekst) — NIGDY dla samej nazwy
   dania ani zdjęcia posiłku, które trzeba potraktować jak przypadek (B)
   powyżej.

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
        "generationConfig": {"responseMimeType": "application/json"},
    }

    # 503 od Gemini zwykle oznacza chwilowe przeciążenie serwerów Google
    # (typowe na darmowym poziomie) — to błąd PRZEJŚCIOWY. Zamiast od razu
    # poddawać się przy pierwszej takiej odpowiedzi, ponawiamy próbę kilka
    # razy z rosnącym opóźnieniem, zanim uznamy TEN model za niedostępny.
    # UWAGA (naprawa wydajności): 60 sekund na PRÓBĘ, x3 próby na model,
    # x3 modele w łańcuchu zapasowym — w najgorszym, ale realnym
    # scenariuszu (jeden model chwilowo przeciążony) dawało to nawet
    # kilka MINUT oczekiwania, zanim aplikacja w ogóle przeszła do
    # kolejnego modelu. Typowa, udana odpowiedź Gemini na tak duży
    # (JSON) prompt to zwykle kilka-kilkanaście sekund — 25s z zapasem
    # w pełni wystarcza normalnym zapytaniom, a znacznie szybciej
    # wykrywa i omija te faktycznie zawieszone/przeciążone.
    # UWAGA (korekta wydajności): przy rozszerzeniu łańcucha do 6 modeli,
    # 2 próby na model dawałyby w najgorszym scenariusze (wszystkie modele
    # zawiodą) nawet 5-9 minut oczekiwania — zbyt długo, koliduje z
    # wcześniejszą naprawą wydajności (skrócone timeouty). Skoro teraz
    # jest WIĘCEJ niezależnych modeli jako zapas, redundancja na poziomie
    # całego łańcucha jest silniejsza niż wcześniej — 1 próba na model
    # (bez wewnętrznego ponawiania) i szybsze przejście do KOLEJNEGO,
    # świeżego modelu jest rozsądniejsze niż tracenie czasu na ponowną
    # próbę tego samego, który właśnie zawiódł.
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
            except httpx.TimeoutException:
                if attempt < max_attempts:
                    await asyncio.sleep(attempt * 1.5)
                    continue
                raise AIRecipeImportError("Rozpoznawanie przepisu trwało zbyt długo. Spróbuj ponownie.")
            except httpx.HTTPError as exc:
                raise AIRecipeImportError(f"Nie udało się połączyć z usługą AI: {exc}")

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


async def _call_gemini(parts: list[dict], *, timeout_seconds: float = 25.0) -> str:
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
    for model in GEMINI_MODELS:
        try:
            return await _call_gemini_model(parts, model, timeout_seconds=timeout_seconds)
        except _ModelUnavailableError as exc:
            logger.warning("Gemini: %s — próbuję kolejnego modelu, jeśli jest", exc)
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

    if "error" in parsed:
        raise AIRecipeImportError(parsed["error"])

    required = {"name", "meal_type", "ingredients", "instructions"}
    if not required.issubset(parsed.keys()):
        raise AIRecipeImportError("AI zwróciło niekompletny przepis. Spróbuj ponownie.")

    return parsed


async def extract_recipe_from_text(recipe_text: str, available_products: list[str]) -> dict:
    """Zwraca ustrukturyzowany przepis (dict) rozpoznany z wklejonego tekstu."""
    prompt = _build_prompt(available_products)
    parts = [{"text": f"{prompt}\n\nTREŚĆ DO ROZPOZNANIA (tekst przepisu):\n{recipe_text}"}]
    raw = await _call_gemini(parts)
    return _parse_recipe_json(raw)


async def _fetch_url_text(url: str) -> str:
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

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
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
    body_text = soup.get_text(separator="\n", strip=True)
    if body_text:
        # Limit rozmiaru — nie chcemy wysyłać całej, ogromnej strony do AI.
        parts.append(body_text[:8000])

    combined = "\n\n".join(p for p in parts if p)
    if not combined.strip():
        raise AIRecipeImportError(
            "Nie udało się wyciągnąć żadnej treści z podanego linku."
        )
    # UWAGA (nowe): jeśli strona zwróciła bardzo mało treści — typowy
    # objaw tego, że np. TikTok pokazał generyczną stronę/wyzwanie
    # zamiast prawdziwej treści filmiku (ochrona przed botami) — lepiej
    # od razu jasno to powiedzieć, niż wysłać AI prawie pustą treść i
    # dostać mylące "nie rozpoznano przepisu", nie wiedząc dlaczego.
    if len(combined.strip()) < 40:
        raise AIRecipeImportError(
            "Nie udało się odczytać treści z tego linku (strona mogła zablokować "
            "automatyczny dostęp). Spróbuj wkleić opis/podpis filmiku bezpośrednio "
            "jako tekst, w zakładce \"Wklej tekst\"."
        )
    return combined


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
    page_text = await _fetch_url_text(url)
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
    prompt = _build_prompt(available_products)
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
    # UWAGA (naprawa wydajności): analiza ZDJĘCIA (multimodalny prompt)
    # jest z natury cięższa i wolniejsza niż czysty tekst — te same 25s,
    # które w pełni wystarczają tekstowi, czasem ucinały faktycznie udane,
    # tylko nieco wolniejsze odpowiedzi dla zdjęć, dając w efekcie błąd
    # "trwało zbyt długo" nawet gdy model by w końcu odpowiedział. 45s
    # daje zdjęciom realistyczny zapas, wciąż daleko od pierwotnych 60s.
    raw = await _call_gemini(parts, timeout_seconds=45.0)
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
