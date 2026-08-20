"""Kalkulator wartości odżywczych dla przepisów i planów posiłków.

Moduł odpowiada za:
- obliczanie wartości odżywczych przepisów na podstawie składników,
- sumowanie dziennych wartości odżywczych,
- ocenę zbilansowania diety względem docelowych makroskładników.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Sequence

if TYPE_CHECKING:
    from app.models import Recipe, RecipeIngredient


def compute_recipe_nutrition_total(ingredients: Sequence["RecipeIngredient"]) -> dict[str, float]:
    """Liczy łączne wartości odżywcze CAŁEGO przepisu (wszystkich porcji
    razem) na podstawie jego składników — to źródło prawdy, z którego
    korzysta zarówno zapis przy tworzeniu przepisu, jak i (jako
    zabezpieczenie) odczyt przez API.

    UWAGA (naprawa poważnego błędu architektonicznego): ta logika
    wcześniej istniała TYLKO wewnątrz walidatora Pydantic (ensure_nutrition
    w schemas/recipe.py), uruchamianego jedynie przy budowaniu ODPOWIEDZI
    API dla konkretnego przepisu — NIGDY nie była wywoływana przy samym
    TWORZENIU przepisu, więc `nutrition_total` w bazie danych zostawało
    puste (NULL) dla KAŻDEGO przepisu dodanego ręcznie albo przez AI
    (w przeciwieństwie do 81 oficjalnych przepisów z seed.py, które mają
    tę wartość jawnie zapisaną). Każdy inny kod, który czytał
    `recipe.nutrition_total` BEZPOŚREDNIO z obiektu bazy danych (z
    pominięciem tego walidatora Pydantic) — jak np. dziennik kalorii w
    Śledzeniu — zawsze widział puste wartości dla takich przepisów,
    mimo że przepis miał kompletne, prawidłowe składniki.

    Wyciągnięcie tej logiki do jednej, współdzielonej funkcji pozwala
    wywołać ją JAWNIE przy tworzeniu przepisu (żeby zapisać prawdziwą
    wartość w bazie raz na zawsze), a walidator Pydantic zostaje jako
    dodatkowe zabezpieczenie na wypadek starszych danych.
    """
    total = {"kcal": 0.0, "protein": 0.0, "fat": 0.0, "carbs": 0.0, "fiber": 0.0}
    for ing in ingredients:
        prod = getattr(ing, "product", None)
        if prod and prod.nutrition_per_100:
            try:
                qty = float(ing.quantity)
                unit = getattr(ing, "unit", "g")
                w = quantity_to_grams(prod.name, qty, unit)
                for k in total:
                    total[k] += float(prod.nutrition_per_100.get(k, 0) or 0) * (w / 100.0)
            except Exception:
                pass
    return {k: round(v, 1) for k, v in total.items()}


@dataclass(frozen=True, slots=True)
class NutritionTargets:
    """Docelowe dzienne wartości odżywcze (domyślne wg norm)."""

    kcal: float = 2000.0
    protein: float = 50.0
    fat: float = 65.0
    carbs: float = 300.0
    fiber: float = 25.0


_MACRO_KEYS: tuple[str, ...] = ("kcal", "protein", "fat", "carbs", "fiber")

DEFAULT_TARGETS = NutritionTargets()

# Przybliżona waga (w gramach) pojedynczej sztuki dla produktów liczonych
# w sztukach, gdy nie ma dokładniejszej informacji o wadze opakowania.
# Musi być spójna z tabelą używaną przy zasilaniu bazy danych (app/db/seed.py),
# w przeciwnym razie wyświetlane kcal będą się różnić w zależności od miejsca
# w aplikacji (np. 1 ząbek czosnku liczony jako 100 g zamiast ~5 g dawał
# dwudziestokrotnie zawyżoną kaloryczność).
WEIGHT_PER_SZT_G: dict[str, float] = {
    "Bułka kajzerka": 50,
    "Jajka": 50,
    "Ogórek": 150,
    "Papryka czerwona": 200,
    "Sałata lodowa": 300,
    "Czosnek": 5,
    "Awokado": 150,
    "Jabłka": 150,
    "Banan": 120,
    # UWAGA (naprawa): tabela wcześniej miała tylko 9 pozycji — każdy inny
    # produkt użyty z jednostką "szt" (typowe dla przepisów z AI, które
    # swobodniej dobierają jednostki niż starannie wyselekcjonowane 81
    # oficjalnych przepisów) dostawał ten sam, generyczny fallback 100 g,
    # niezależnie czy to była kostka rosołowa (~10 g, 10x zawyżenie) czy
    # duży kalafior (~500 g, 5x zaniżenie). Rozszerzona lista pokrywa
    # pozostałe produkty z katalogu, które sensownie liczy się "na sztuki".
    "Papryka słodka": 180,
    "Cytryna": 80,
    "Limonka": 50,
    "Cukinia": 300,
    "Bakłażan": 250,
    "Por": 150,
    "Mango": 200,
    "Kalafior": 500,
    "Brokuł": 400,
    "Kapusta pekińska": 800,
    "Cebula": 120,
}
_DEFAULT_SZT_WEIGHT_G = 100.0


def grams_to_quantity(product_name: str, grams: float, unit: str) -> float:
    """Przelicza ilość z gramów/mililitrów z powrotem na jednostkę ``unit``.

    Odwrotność ``quantity_to_grams`` — używana np. przy wyświetlaniu sumy
    zapotrzebowania na produkt w jego naturalnej jednostce sklepowej.
    """
    if unit in ("kg", "l"):
        return grams / 1000.0
    if unit == "szt":
        weight = WEIGHT_PER_SZT_G.get(product_name, _DEFAULT_SZT_WEIGHT_G)
        return grams / weight if weight else 0.0
    return grams


def quantity_to_grams(product_name: str, quantity: float, unit: str) -> float:
    """Przelicza ilość składnika na gramy (lub mililitry, traktowane 1:1 z gramami).

    Args:
        product_name: nazwa produktu — używana do doboru wagi 1 sztuki.
        quantity: ilość w jednostce ``unit``.
        unit: jedna z wartości ``g``, ``kg``, ``ml``, ``l``, ``szt``.

    Returns:
        Ilość przeliczona na gramy/mililitry.
    """
    qty = float(quantity or 0.0)
    if unit in ("kg", "l"):
        return qty * 1000.0
    if unit == "szt":
        return qty * WEIGHT_PER_SZT_G.get(product_name, _DEFAULT_SZT_WEIGHT_G)
    # "g", "ml" i inne nieznane jednostki traktujemy jako wartość 1:1
    return qty


def _empty_nutrition() -> dict[str, float]:
    return {k: 0.0 for k in _MACRO_KEYS}


class NutritionCalculator:
    """Bezstanowy kalkulator wartości odżywczych."""

    # ------------------------------------------------------------------
    # Obliczanie wartości odżywczych przepisu
    # ------------------------------------------------------------------

    @staticmethod
    def calculate_recipe_nutrition(
        ingredients: Sequence[RecipeIngredient],
    ) -> dict[str, float]:
        """Oblicza łączne wartości odżywcze przepisu.

        Każdy ``RecipeIngredient`` musi mieć załadowaną relację ``product``.
        Wartości odżywcze produktu zapisane są *na 100 g/ml* — przeliczamy je
        proporcjonalnie do ``quantity`` składnika, uwzględniając jednostkę
        (``g``, ``kg``, ``ml``, ``l``, ``szt``) poprzez ``quantity_to_grams``.

        Args:
            ingredients: lista składników przepisu z załadowaną relacją product.

        Returns:
            Słownik z kluczami ``kcal``, ``protein``, ``fat``, ``carbs``, ``fiber``.
        """
        totals = _empty_nutrition()

        for ing in ingredients:
            product = ing.product  # type: ignore[union-attr]
            if product is None:
                continue

            weight_g = quantity_to_grams(
                product.name, float(ing.quantity or 0.0), ing.unit
            )
            factor = weight_g / 100.0

            nutrition = getattr(product, 'nutrition_per_100', None) or {}
            totals["kcal"] += (nutrition.get("kcal", 0.0) or 0.0) * factor
            totals["protein"] += (nutrition.get("protein", 0.0) or 0.0) * factor
            totals["fat"] += (nutrition.get("fat", 0.0) or 0.0) * factor
            totals["carbs"] += (nutrition.get("carbs", 0.0) or 0.0) * factor
            totals["fiber"] += (nutrition.get("fiber", 0.0) or 0.0) * factor

        # Zaokrąglamy do 1 miejsca po przecinku
        return {k: round(v, 1) for k, v in totals.items()}

    # ------------------------------------------------------------------
    # Dzienne podsumowanie
    # ------------------------------------------------------------------

    @staticmethod
    def calculate_daily_nutrition(
        recipes_for_day: Sequence[Recipe],
    ) -> dict[str, float]:
        """Sumuje wartości odżywcze wszystkich przepisów na dany dzień.

        Wymaga załadowanej relacji ``recipe.ingredients`` oraz
        ``ingredient.product`` dla każdego przepisu.

        Args:
            recipes_for_day: przepisy zaplanowane na jeden dzień.

        Returns:
            Słownik z kluczami ``kcal``, ``protein``, ``fat``, ``carbs``, ``fiber``.
        """
        daily = _empty_nutrition()

        for recipe in recipes_for_day:
            recipe_nutrition = NutritionCalculator.calculate_recipe_nutrition(
                recipe.ingredients,  # type: ignore[arg-type]
            )
            for key in _MACRO_KEYS:
                daily[key] += recipe_nutrition[key]

        return {k: round(v, 1) for k, v in daily.items()}

    # ------------------------------------------------------------------
    # Ocena zbilansowania
    # ------------------------------------------------------------------

    @staticmethod
    def check_nutrition_balance(
        daily_nutrition: dict[str, float],
        target: NutritionTargets | dict[str, float] | None = None,
    ) -> float:
        """Wyznacza wskaźnik zbilansowania diety (0.0–1.0).

        Algorytm:
        1. Dla każdego makroskładnika obliczamy względne odchylenie
           ``|actual - target| / target``.
        2. Uśredniamy odchylenia (średnia arytmetyczna).
        3. Wynik = ``max(0.0, 1.0 - mean_deviation)``.

        Wartość ``1.0`` oznacza idealne dopasowanie, ``0.0`` — poważne
        niedopasowanie.

        Args:
            daily_nutrition: faktyczne wartości dzienne.
            target: docelowe wartości (domyślnie ``DEFAULT_TARGETS``).

        Returns:
            Ocena zbilansowania jako ``float`` z przedziału [0.0, 1.0].
        """
        if target is None:
            targets = DEFAULT_TARGETS
        elif isinstance(target, dict):
            targets = NutritionTargets(**{k: target.get(k, getattr(DEFAULT_TARGETS, k)) for k in _MACRO_KEYS})
        else:
            targets = target

        deviations: list[float] = []
        for key in _MACRO_KEYS:
            target_val = getattr(targets, key)
            actual_val = daily_nutrition.get(key, 0.0)
            if target_val > 0.0:
                deviation = abs(actual_val - target_val) / target_val
            else:
                deviation = 0.0 if actual_val == 0.0 else 1.0
            deviations.append(deviation)

        mean_deviation = sum(deviations) / len(deviations) if deviations else 0.0
        score = max(0.0, 1.0 - mean_deviation)
        return round(score, 4)

    # ------------------------------------------------------------------
    # Pomocnicze — wektor odżywczy do porównań
    # ------------------------------------------------------------------

    @staticmethod
    def nutrition_vector(product_or_dict: object) -> tuple[float, ...]:
        """Zwraca wektor makroskładników — przydatny do cosine similarity.

        Akceptuje obiekt z atrybutami (Product) lub słownik.
        """
        if isinstance(product_or_dict, dict):
            return tuple(product_or_dict.get(k, 0.0) for k in _MACRO_KEYS)
        # If object has nutrition_per_100, use that
        nutrition = getattr(product_or_dict, 'nutrition_per_100', None)
        if isinstance(nutrition, dict):
            return tuple(nutrition.get(k, 0.0) or 0.0 for k in _MACRO_KEYS)
        return tuple(getattr(product_or_dict, k, 0.0) or 0.0 for k in _MACRO_KEYS)

    @staticmethod
    def cosine_similarity(a: tuple[float, ...], b: tuple[float, ...]) -> float:
        """Oblicza cosine similarity między dwoma wektorami odżywczymi."""
        dot = sum(x * y for x, y in zip(a, b))
        norm_a = math.sqrt(sum(x * x for x in a))
        norm_b = math.sqrt(sum(x * x for x in b))
        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0
        return round(dot / (norm_a * norm_b), 4)


# Mnożniki aktywności fizycznej — standardowe wartości używane przez
# większość popularnych kalkulatorów zapotrzebowania kalorycznego
# (w tym te oparte na wzorze Mifflin-St Jeor, tak jak kalkulator NFZ).
ACTIVITY_MULTIPLIERS: dict[str, float] = {
    "sedentary": 1.2,      # Brak/znikoma aktywność (praca siedząca)
    "light": 1.375,        # Lekka aktywność (1-3 dni treningu/tydzień)
    "moderate": 1.55,      # Umiarkowana aktywność (3-5 dni/tydzień)
    "active": 1.725,       # Duża aktywność (6-7 dni/tydzień)
    "very_active": 1.9,    # Bardzo duża aktywność (praca fizyczna + trening)
}


class InvalidCalorieCalculatorInput(ValueError):
    """Rzucane, gdy dane wejściowe do kalkulatora są niekompletne/błędne."""


def calculate_calorie_needs(
    weight_kg: float,
    height_cm: float,
    age: int,
    gender: str,
    activity_level: str,
) -> dict[str, int]:
    """Liczy dzienne zapotrzebowanie kaloryczne wzorem Mifflin-St Jeor —
    tym samym standardem, na którym opiera się większość popularnych
    kalkulatorów tego typu (w tym kalkulator BMI/kalorii NFZ).

    Zwraca trzy wartości:
    - "maintenance": zapotrzebowanie do UTRZYMANIA obecnej wagi (TDEE)
    - "weight_loss": deficyt ~500 kcal/dzień — standardowe, bezpieczne
      tempo redukcji ok. 0,5 kg tygodniowo (powszechnie rekomendowane
      przez dietetyków, nie tylko agresywne, krótkoterminowe diety)
    - "weight_gain": nadwyżka ~500 kcal/dzień — analogiczne, bezpieczne
      tempo przybierania na wadze ok. 0,5 kg tygodniowo

    Rzuca InvalidCalorieCalculatorInput, jeśli dane wejściowe są poza
    rozsądnym zakresem (np. ujemna waga) — lepiej jawnie odmówić niż
    zwrócić bezsensowny wynik.
    """
    if weight_kg <= 0 or weight_kg > 400:
        raise InvalidCalorieCalculatorInput("Nieprawidłowa waga.")
    if height_cm <= 0 or height_cm > 280:
        raise InvalidCalorieCalculatorInput("Nieprawidłowy wzrost.")
    if age <= 0 or age > 130:
        raise InvalidCalorieCalculatorInput("Nieprawidłowy wiek.")
    if gender not in ("male", "female"):
        raise InvalidCalorieCalculatorInput("Płeć musi być 'male' albo 'female'.")
    if activity_level not in ACTIVITY_MULTIPLIERS:
        raise InvalidCalorieCalculatorInput(
            f"Nieznany poziom aktywności — dozwolone: {', '.join(ACTIVITY_MULTIPLIERS)}."
        )

    # Wzór Mifflin-St Jeor (uznawany za dokładniejszy niż starszy wzór
    # Harrisa-Benedicta) — osobny stały człon dla każdej płci, bo przy
    # tej samej wadze/wzroście/wieku kobiety mają średnio wyższy
    # procent tkanki tłuszczowej niż mężczyźni, co przekłada się na
    # niższe tempo podstawowej przemiany materii.
    bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age
    bmr += 5 if gender == "male" else -161

    maintenance = bmr * ACTIVITY_MULTIPLIERS[activity_level]

    return {
        "maintenance": round(maintenance),
        "weight_loss": round(maintenance - 500),
        "weight_gain": round(maintenance + 500),
    }
