"""Spójne jednostki użytkowe produktów i przeliczenia na g/ml.

W bazie wartości odżywcze są zapisane na 100 g albo 100 ml. Interfejs może
jednak pokazać wygodniejsze jednostki (opakowanie, łyżeczka, szklanka),
o ile znamy ich fizyczny odpowiednik. Nie wystawiamy jednostki, której nie da
się wiarygodnie przeliczyć dla danego produktu.
"""

from __future__ import annotations

from typing import Any


LIQUID_WORDS = {
    "mleko", "napój", "sok", "woda", "cola", "pepsi", "lemoniada",
    "kawa", "herbata", "olej", "oliwa", "ocet", "bulion", "śmietana",
}
TEASPOON_GRAMS = {
    "sól": 5.0,
    "cukier": 4.0,
    "miód": 7.0,
    "masło": 5.0,
    "mąka": 3.0,
    "kakao": 3.0,
    "przypraw": 2.0,
    "cynamon": 2.6,
    "sos": 5.0,
    "majonez": 5.0,
    "musztarda": 5.0,
    "ketchup": 5.0,
}
GLASS_GRAMS = {
    "mąka": 160.0,
    "cukier": 220.0,
    "ryż": 190.0,
    "płatki": 110.0,
    "kasza": 180.0,
    "orzech": 140.0,
}

# Średnia część jadalna jednej sztuki. Wartości są używane tylko jako
# przybliżenie i w interfejsie są tak oznaczane. Jedno wspólne źródło usuwa
# wcześniejszą rozbieżność, w której ekran liczył sztukę inaczej niż przepis.
PIECE_GRAMS = {
    "Bułka kajzerka": 50.0,
    "Jajka": 50.0,
    "Jajka przepiórcze": 9.0,
    "Ogórek": 150.0,
    "Kapusta biała": 1200.0,
    "Kapusta czerwona": 1200.0,
    "Kapusta pekińska": 800.0,
    "Seler naciowy": 450.0,
    "Papryka czerwona": 200.0,
    "Papryka żółta": 200.0,
    "Papryka zielona": 200.0,
    "Sałata lodowa": 300.0,
    "Sałata rzymska": 350.0,
    "Sałata masłowa": 250.0,
    "Koperek świeży": 30.0,
    "Natka pietruszki": 30.0,
    "Szczypiorek": 30.0,
    "Kolendra świeża": 30.0,
    "Bazylia świeża": 30.0,
    "Mięta świeża": 30.0,
    "Szałwia świeża": 30.0,
    "Estragon świeży": 30.0,
    "Czosnek": 5.0,
    "Awokado": 150.0,
    "Bulion warzywny": 10.0,
    "Bulion drobiowy": 10.0,
    "Bulion wołowy": 10.0,
    "Bulion grzybowy": 10.0,
    "Cytryna": 80.0,
    "Limonka": 50.0,
    "Brokuł": 400.0,
    "Cukinia": 300.0,
    "Bakłażan": 250.0,
    "Kalafior": 500.0,
    "Por": 150.0,
    "Tortilla pszenna": 40.0,
    "Mango": 200.0,
    "Kiwi": 75.0,
    "Grejpfrut": 230.0,
    "Ananas": 900.0,
    "Melon": 900.0,
    "Granat": 180.0,
    "Kaki": 170.0,
    "Rzodkiewka": 15.0,
    "Kalarepa": 250.0,
    "Koper włoski": 250.0,
    "Seler korzeniowy": 500.0,
    "Kukurydza kolba": 180.0,
    "Rzepa": 170.0,
}


def base_unit_for_product(name: str, unit: str) -> str:
    normalized = (unit or "").lower()
    if normalized in {"ml", "l"}:
        return "ml"
    lowered = name.lower()
    if any(word in lowered for word in LIQUID_WORDS):
        return "ml"
    return "g"


def piece_weight_grams(name: str) -> float | None:
    return PIECE_GRAMS.get(name)


def build_measure_options(
    name: str,
    unit: str,
    default_quantity: float | None = None,
    serving_quantity: float | None = None,
) -> list[dict[str, Any]]:
    """Buduje bezpieczny zestaw jednostek dla produktu.

    ``serving_quantity`` ma pierwszeństwo jako masa opakowania. Dla produktów
    katalogowych bez tego pola wykorzystujemy domyślną ilość po przeliczeniu
    kg/l na g/ml. Łyżeczka i szklanka pojawiają się wyłącznie tam, gdzie mamy
    sensowny przelicznik, zamiast udawać, że każda żywność ma tę samą gęstość.
    """

    base_unit = base_unit_for_product(name, unit)
    result: list[dict[str, Any]] = [
        {
            "code": base_unit,
            "label": "gramy" if base_unit == "g" else "mililitry",
            "base_quantity": 1.0,
            "base_unit": base_unit,
            "approximate": False,
        }
    ]

    piece_weight = piece_weight_grams(name) if unit == "szt" else None
    package_size = serving_quantity
    if not package_size and default_quantity and default_quantity > 0:
        if unit == "szt" and piece_weight and default_quantity > 1:
            package_size = float(default_quantity) * piece_weight
        else:
            package_size = float(default_quantity)
        if unit in {"kg", "l"}:
            package_size *= 1000.0
        elif unit == "szt" and not piece_weight:
            package_size = None

    if package_size and package_size > 0:
        result.insert(
            0,
            {
                "code": "opak",
                "label": "opakowanie",
                "base_quantity": float(package_size),
                "base_unit": base_unit,
                "approximate": False,
            },
        )

    lowered = name.lower()
    if base_unit == "ml":
        result.extend(
            [
                {
                    "code": "lyzeczka",
                    "label": "łyżeczka",
                    "base_quantity": 5.0,
                    "base_unit": "ml",
                    "approximate": False,
                },
                {
                    "code": "szklanka",
                    "label": "szklanka",
                    "base_quantity": 250.0,
                    "base_unit": "ml",
                    "approximate": False,
                },
            ]
        )
    else:
        teaspoon = next(
            (grams for word, grams in TEASPOON_GRAMS.items() if word in lowered),
            None,
        )
        if teaspoon:
            result.append(
                {
                    "code": "lyzeczka",
                    "label": "łyżeczka",
                    "base_quantity": teaspoon,
                    "base_unit": "g",
                    "approximate": True,
                }
            )
        glass = next(
            (grams for word, grams in GLASS_GRAMS.items() if word in lowered),
            None,
        )
        if glass:
            result.append(
                {
                    "code": "szklanka",
                    "label": "szklanka",
                    "base_quantity": glass,
                    "base_unit": "g",
                    "approximate": True,
                }
            )

    if unit == "szt" and piece_weight:
        result.insert(
            0,
            {
                "code": "szt",
                "label": "sztuka",
                "base_quantity": piece_weight,
                "base_unit": "g",
                "approximate": True,
            },
        )
    return result


def measure_to_base(
    quantity: float,
    unit: str,
    options: list[dict[str, Any]] | None,
) -> tuple[float, str] | None:
    for option in options or []:
        if option.get("code") == unit:
            return (
                float(quantity) * float(option.get("base_quantity") or 0),
                str(option.get("base_unit") or "g"),
            )
    return None
