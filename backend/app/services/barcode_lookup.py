"""Wyszukiwanie produktu po kodzie kreskowym (EAN/UPC).

Dwuetapowe: najpierw WŁASNY katalog (produkty, które ktoś już zeskanował
i zgłosił wcześniej — natychmiastowe, bez zapytania na zewnątrz), potem
Open Food Facts (https://openfoodfacts.org) jako zewnętrzne źródło.

Open Food Facts to otwarta, darmowa baza budowana wspólnie przez
użytkowników na całym świecie — nie ma tam ŻADNEJ gwarancji pokrycia,
zwłaszcza dla mniej popularnych, lokalnych polskich marek. To jednak
najlepsza realnie dostępna, darmowa opcja bez wymogu klucza API. Kod
kreskowy (EAN-13) jest globalnie unikalny niezależnie od kraju produktu,
więc odpytujemy globalny endpoint, ale PREFERUJEMY polską nazwę produktu
(`product_name_pl`), jeśli OFF ją ma — stąd "skup się na Polsce" w
praktyce oznacza dobór właściwego pola nazwy, nie osobny endpoint.
"""

from __future__ import annotations

import httpx

OFF_API_URL = "https://world.openfoodfacts.org/api/v2/product/{barcode}.json"


class BarcodeLookupResult:
    """Znormalizowany wynik — niezależnie od tego, czy dane przyszły
    z własnego katalogu, czy z Open Food Facts."""

    def __init__(
        self,
        *,
        name: str,
        brand: str | None,
        kcal_per_100: float | None,
        protein_per_100: float | None,
        fat_per_100: float | None,
        carbs_per_100: float | None,
        source: str,
    ) -> None:
        self.name = name
        self.brand = brand
        self.kcal_per_100 = kcal_per_100
        self.protein_per_100 = protein_per_100
        self.fat_per_100 = fat_per_100
        self.carbs_per_100 = carbs_per_100
        self.source = source  # "catalog" | "open_food_facts"


async def lookup_barcode_external(barcode: str) -> BarcodeLookupResult | None:
    """Pyta Open Food Facts o dany kod kreskowy.

    Zwraca None (nie wyjątek) przy braku wyniku LUB błędzie sieciowym —
    to zewnętrzna usługa poza naszą kontrolą, jej chwilowa niedostępność
    nie może wywrócić żądania użytkownika. Wywołujący i tak ma wtedy
    ścieżkę zapasową: ręczne wypełnienie formularza.
    """
    try:
        async with httpx.AsyncClient(timeout=6.0) as client:
            response = await client.get(
                OFF_API_URL.format(barcode=barcode),
                headers={
                    # OFF prosi o identyfikowalny User-Agent w swoich
                    # wytycznych API — bez tego część zapytań bywa
                    # ograniczana.
                    "User-Agent": "MealPlannerPolska/1.0 (adamcygan9@gmail.com)",
                },
            )
    except httpx.HTTPError:
        return None

    if response.status_code != 200:
        return None

    try:
        data = response.json()
    except ValueError:
        return None

    if data.get("status") != 1:
        # status=0 = "produkt nieznaleziony" w API OFF — to normalny,
        # oczekiwany wynik przy mniej popularnych/lokalnych produktach,
        # nie błąd.
        return None

    product = data.get("product") or {}

    # Nazwa: polska wersja ma pierwszeństwo, jeśli OFF ją zna.
    name = (
        product.get("product_name_pl")
        or product.get("product_name")
        or product.get("generic_name_pl")
        or product.get("generic_name")
    )
    if not name:
        return None

    nutriments = product.get("nutriments") or {}

    def _num(*keys: str) -> float | None:
        for key in keys:
            val = nutriments.get(key)
            if val is not None:
                try:
                    return float(val)
                except (TypeError, ValueError):
                    continue
        return None

    return BarcodeLookupResult(
        name=name.strip(),
        brand=(product.get("brands") or "").split(",")[0].strip() or None,
        kcal_per_100=_num("energy-kcal_100g", "energy-kcal"),
        protein_per_100=_num("proteins_100g"),
        fat_per_100=_num("fat_100g"),
        carbs_per_100=_num("carbohydrates_100g"),
        source="open_food_facts",
    )
