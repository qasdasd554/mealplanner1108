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
