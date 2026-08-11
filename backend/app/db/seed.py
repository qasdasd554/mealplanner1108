"""Dane startowe (seed) bazy danych Smart Meal Planner PL.

Zawiera sklepy, działy, alergeny, produkty, powiązania sklepowe
oraz przepisy z pełnymi składnikami i tagami.

Wszystkie UUID są deterministyczne (uuid5) — wielokrotne uruchomienie
daje te same identyfikatory, co ułatwia debugowanie i testowanie.
"""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.product import Allergen, Product, ProductAllergen, StoreProduct
from app.models.recipe import Recipe, RecipeIngredient, RecipeTag
from app.models.store import Store, StoreDepartment

# ──────────────────────────────────────────────────────────────────
# Przestrzeń nazw UUID5 — gwarantuje powtarzalność seedów
# ──────────────────────────────────────────────────────────────────
NS = uuid.UUID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")


def _uid(name: str) -> uuid.UUID:
    """Generuje deterministyczny UUID5 na podstawie nazwy."""
    return uuid.uuid5(NS, name)


# ══════════════════════════════════════════════════════════════════
# SKLEPY
# ══════════════════════════════════════════════════════════════════
STORE_NAMES = ["Biedronka", "Lidl", "Dino"]

DEPARTMENT_NAMES = [
    "Warzywa i owoce",
    "Pieczywo",
    "Mięso i wędliny",
    "Ryby",
    "Nabiał",
    "Produkty suche",
    "Mrożonki",
    "Przyprawy i sosy",
]

# ══════════════════════════════════════════════════════════════════
# ALERGENY
# ══════════════════════════════════════════════════════════════════
ALLERGEN_NAMES = [
    "gluten",
    "laktoza",
    "orzechy",
    "jaja",
    "soja",
    "seler",
    "ryby",
    "skorupiaki",
]

# ══════════════════════════════════════════════════════════════════
# PRODUKTY
# ══════════════════════════════════════════════════════════════════
# Każdy tuple: (nazwa, jednostka, default_qty, dział, cena_biedronka, allergen_names)
PRODUCTS_DATA: list[tuple[str, str, Decimal, str, Decimal, list[str]]] = [
    # ── Nabiał ───────────────────────────────────────────────────
    ("Mleko 2%", "l", Decimal("1"), "Nabiał", Decimal("3.49"), ["laktoza"]),
    ("Masło extra", "g", Decimal("200"), "Nabiał", Decimal("6.99"), ["laktoza"]),
    ("Ser żółty gouda", "g", Decimal("200"), "Nabiał", Decimal("7.49"), ["laktoza"]),
    ("Jogurt naturalny", "g", Decimal("400"), "Nabiał", Decimal("3.29"), ["laktoza"]),
    ("Śmietana 18%", "ml", Decimal("200"), "Nabiał", Decimal("2.49"), ["laktoza"]),
    ("Twaróg półtłusty", "g", Decimal("250"), "Nabiał", Decimal("4.99"), ["laktoza"]),
    # ── Pieczywo ─────────────────────────────────────────────────
    ("Chleb pszenny", "g", Decimal("500"), "Pieczywo", Decimal("4.29"), ["gluten"]),
    ("Bułka kajzerka", "szt", Decimal("1"), "Pieczywo", Decimal("0.59"), ["gluten"]),
    # ── Mięso i wędliny ─────────────────────────────────────────
    ("Pierś z kurczaka", "kg", Decimal("1"), "Mięso i wędliny", Decimal("21.99"), []),
    ("Mielone wieprzowo-wołowe", "g", Decimal("500"), "Mięso i wędliny", Decimal("12.99"), []),
    ("Szynka konserwowa", "g", Decimal("100"), "Mięso i wędliny", Decimal("4.49"), []),
    ("Schab wieprzowy", "kg", Decimal("1"), "Mięso i wędliny", Decimal("18.99"), []),
    # ── Jajka ────────────────────────────────────────────────────
    ("Jajka", "szt", Decimal("10"), "Nabiał", Decimal("8.99"), ["jaja"]),
    # ── Ryby ─────────────────────────────────────────────────────
    ("Łosoś wędzony", "g", Decimal("100"), "Ryby", Decimal("9.99"), ["ryby"]),
    # ── Warzywa i owoce ──────────────────────────────────────────
    ("Pomidory", "kg", Decimal("1"), "Warzywa i owoce", Decimal("7.99"), []),
    ("Ogórek", "szt", Decimal("1"), "Warzywa i owoce", Decimal("2.49"), []),
    ("Cebula", "kg", Decimal("1"), "Warzywa i owoce", Decimal("2.99"), []),
    ("Ziemniaki", "kg", Decimal("1"), "Warzywa i owoce", Decimal("3.49"), []),
    ("Marchew", "kg", Decimal("1"), "Warzywa i owoce", Decimal("2.99"), []),
    ("Papryka czerwona", "szt", Decimal("1"), "Warzywa i owoce", Decimal("4.49"), []),
    ("Sałata lodowa", "szt", Decimal("1"), "Warzywa i owoce", Decimal("3.99"), []),
    ("Czosnek", "szt", Decimal("1"), "Warzywa i owoce", Decimal("1.99"), []),
    ("Awokado", "szt", Decimal("1"), "Warzywa i owoce", Decimal("5.99"), []),
    ("Pieczarki", "kg", Decimal("0.5"), "Warzywa i owoce", Decimal("9.99"), []),
    # ── Produkty suche ───────────────────────────────────────────
    ("Makaron penne", "g", Decimal("500"), "Produkty suche", Decimal("4.49"), ["gluten"]),
    ("Ryż biały", "kg", Decimal("1"), "Produkty suche", Decimal("5.99"), []),
    ("Mąka pszenna", "kg", Decimal("1"), "Produkty suche", Decimal("3.49"), ["gluten"]),
    ("Passata pomidorowa", "g", Decimal("500"), "Produkty suche", Decimal("4.99"), []),
    ("Pomidory krojone", "g", Decimal("400"), "Produkty suche", Decimal("3.49"), []),
    ("Fasola konserwowa", "g", Decimal("400"), "Produkty suche", Decimal("3.49"), []),
    ("Płatki owsiane", "g", Decimal("500"), "Produkty suche", Decimal("3.99"), ["gluten"]),
    ("Bułka tarta", "g", Decimal("500"), "Produkty suche", Decimal("3.99"), ["gluten"]),
    ("Quinoa", "kg", Decimal("0.5"), "Produkty suche", Decimal("12.99"), []),
    ("Nasiona chia", "g", Decimal("200"), "Produkty suche", Decimal("8.99"), []),
    # ── Oleje ────────────────────────────────────────────────────
    ("Olej rzepakowy", "l", Decimal("1"), "Produkty suche", Decimal("7.99"), []),
    ("Oliwa z oliwek", "ml", Decimal("500"), "Produkty suche", Decimal("16.99"), []),
    # ── Przyprawy i sosy ────────────────────────────────────────
    ("Sól", "kg", Decimal("1"), "Przyprawy i sosy", Decimal("1.99"), []),
    ("Pieprz czarny mielony", "g", Decimal("20"), "Przyprawy i sosy", Decimal("3.49"), []),
    ("Papryka słodka", "g", Decimal("20"), "Przyprawy i sosy", Decimal("3.29"), []),
    ("Bazylia suszona", "g", Decimal("10"), "Przyprawy i sosy", Decimal("2.99"), []),
    ("Sos sojowy", "ml", Decimal("150"), "Przyprawy i sosy", Decimal("5.99"), ["gluten", "soja"]),
    ("Bulion warzywny", "szt", Decimal("1"), "Przyprawy i sosy", Decimal("1.99"), []),
    # ── Mrożonki ─────────────────────────────────────────────────
    ("Mrożone warzywa mieszanka", "g", Decimal("450"), "Mrożonki", Decimal("5.49"), []),
    ("Mrożony szpinak", "g", Decimal("450"), "Mrożonki", Decimal("4.99"), []),
    # ── Dodatki (Snacki) ──────────────────────────────────────────
    ("Jabłka", "kg", Decimal("1"), "Warzywa i owoce", Decimal("3.49"), []),
    ("Masło orzechowe", "g", Decimal("300"), "Produkty suche", Decimal("9.99"), ["orzechy"]),
    ("Hummus", "g", Decimal("200"), "Nabiał", Decimal("4.99"), []),
    ("Banan", "kg", Decimal("1"), "Warzywa i owoce", Decimal("4.99"), []),
    ("Maliny", "g", Decimal("125"), "Warzywa i owoce", Decimal("7.99"), []),
    ("Mleko migdałowe", "l", Decimal("1"), "Produkty suche", Decimal("7.99"), ["orzechy"]),
    ("Ser feta", "g", Decimal("200"), "Nabiał", Decimal("6.49"), ["laktoza"]),
    ("Oliwki czarne", "g", Decimal("150"), "Produkty suche", Decimal("5.99"), []),
]

# Mnożniki cen — Biedronka jest bazą (1.0)
PRICE_MULTIPLIERS = {
    "Biedronka": Decimal("1.00"),
    "Lidl": Decimal("1.05"),
    "Dino": Decimal("1.12"),
}

# Wartości odżywcze na 100g/ml (lub 1 sztukę, jeśli produkt liczony w sztukach i nie ma sprecyzowanej wagi)
NUTRITION_DATA = {
    "Mleko 2%": {"kcal": 50, "protein": 3.3, "fat": 2.0, "carbs": 4.8, "fiber": 0.0},
    "Masło extra": {"kcal": 748, "protein": 0.7, "fat": 82.5, "carbs": 0.7, "fiber": 0.0},
    "Ser żółty gouda": {"kcal": 356, "protein": 24.9, "fat": 27.4, "carbs": 2.2, "fiber": 0.0},
    "Jogurt naturalny": {"kcal": 61, "protein": 4.3, "fat": 3.0, "carbs": 4.2, "fiber": 0.0},
    "Śmietana 18%": {"kcal": 186, "protein": 2.5, "fat": 18.0, "carbs": 3.6, "fiber": 0.0},
    "Twaróg półtłusty": {"kcal": 133, "protein": 18.7, "fat": 4.7, "carbs": 3.7, "fiber": 0.0},
    "Chleb pszenny": {"kcal": 265, "protein": 8.0, "fat": 1.3, "carbs": 55.0, "fiber": 3.0},
    "Bułka kajzerka": {"kcal": 296, "protein": 8.5, "fat": 1.6, "carbs": 61.0, "fiber": 2.0},
    "Pierś z kurczaka": {"kcal": 120, "protein": 22.5, "fat": 2.6, "carbs": 0.0, "fiber": 0.0},
    "Mielone wieprzowo-wołowe": {"kcal": 250, "protein": 16.0, "fat": 20.0, "carbs": 0.0, "fiber": 0.0},
    "Szynka konserwowa": {"kcal": 105, "protein": 16.0, "fat": 4.0, "carbs": 1.0, "fiber": 0.0},
    "Schab wieprzowy": {"kcal": 152, "protein": 21.0, "fat": 7.0, "carbs": 0.0, "fiber": 0.0},
    "Jajka": {"kcal": 143, "protein": 12.6, "fat": 9.5, "carbs": 0.7, "fiber": 0.0},
    "Łosoś wędzony": {"kcal": 162, "protein": 25.4, "fat": 5.4, "carbs": 0.0, "fiber": 0.0},
    "Pomidory": {"kcal": 18, "protein": 0.9, "fat": 0.2, "carbs": 3.9, "fiber": 1.2},
    "Ogórek": {"kcal": 15, "protein": 0.7, "fat": 0.1, "carbs": 3.6, "fiber": 0.5},
    "Cebula": {"kcal": 40, "protein": 1.1, "fat": 0.1, "carbs": 9.3, "fiber": 1.7},
    "Ziemniaki": {"kcal": 77, "protein": 2.0, "fat": 0.1, "carbs": 17.5, "fiber": 2.2},
    "Marchew": {"kcal": 41, "protein": 0.9, "fat": 0.2, "carbs": 9.6, "fiber": 2.8},
    "Papryka czerwona": {"kcal": 31, "protein": 1.0, "fat": 0.3, "carbs": 6.0, "fiber": 2.1},
    "Sałata lodowa": {"kcal": 14, "protein": 0.9, "fat": 0.1, "carbs": 3.0, "fiber": 1.2},
    "Czosnek": {"kcal": 149, "protein": 6.4, "fat": 0.5, "carbs": 33.0, "fiber": 2.1},
    "Awokado": {"kcal": 160, "protein": 2.0, "fat": 14.7, "carbs": 8.5, "fiber": 6.7},
    "Makaron penne": {"kcal": 350, "protein": 12.0, "fat": 1.5, "carbs": 71.0, "fiber": 3.0},
    "Ryż biały": {"kcal": 130, "protein": 2.7, "fat": 0.3, "carbs": 28.0, "fiber": 0.4},
    "Mąka pszenna": {"kcal": 364, "protein": 10.3, "fat": 1.0, "carbs": 76.0, "fiber": 2.7},
    "Passata pomidorowa": {"kcal": 32, "protein": 1.6, "fat": 0.2, "carbs": 5.3, "fiber": 1.5},
    "Fasola konserwowa": {"kcal": 85, "protein": 5.5, "fat": 0.4, "carbs": 12.0, "fiber": 5.0},
    "Płatki owsiane": {"kcal": 389, "protein": 16.9, "fat": 6.9, "carbs": 66.0, "fiber": 10.6},
    "Bułka tarta": {"kcal": 395, "protein": 14.0, "fat": 2.0, "carbs": 78.0, "fiber": 4.0},
    "Olej rzepakowy": {"kcal": 884, "protein": 0.0, "fat": 100.0, "carbs": 0.0, "fiber": 0.0},
    "Oliwa z oliwek": {"kcal": 884, "protein": 0.0, "fat": 100.0, "carbs": 0.0, "fiber": 0.0},
    "Sól": {"kcal": 0, "protein": 0.0, "fat": 0.0, "carbs": 0.0, "fiber": 0.0},
    "Pieprz czarny mielony": {"kcal": 251, "protein": 10.4, "fat": 3.3, "carbs": 64.0, "fiber": 25.3},
    "Papryka słodka": {"kcal": 282, "protein": 14.1, "fat": 12.9, "carbs": 54.0, "fiber": 34.9},
    "Bazylia suszona": {"kcal": 233, "protein": 23.0, "fat": 4.1, "carbs": 47.8, "fiber": 37.7},
    "Mrożone warzywa mieszanka": {"kcal": 35, "protein": 2.0, "fat": 0.2, "carbs": 6.0, "fiber": 2.5},
    "Mrożony szpinak": {"kcal": 23, "protein": 2.9, "fat": 0.4, "carbs": 3.6, "fiber": 2.2},
    "Jabłka": {"kcal": 52, "protein": 0.3, "fat": 0.2, "carbs": 13.8, "fiber": 2.4},
    "Masło orzechowe": {"kcal": 588, "protein": 25.0, "fat": 50.0, "carbs": 20.0, "fiber": 6.0},
    "Hummus": {"kcal": 166, "protein": 7.9, "fat": 9.6, "carbs": 14.3, "fiber": 6.0},
    "Banan": {"kcal": 89, "protein": 1.1, "fat": 0.3, "carbs": 22.8, "fiber": 2.6},
    "Maliny": {"kcal": 52, "protein": 1.2, "fat": 0.6, "carbs": 11.9, "fiber": 6.5},
    "Mleko migdałowe": {"kcal": 15, "protein": 0.5, "fat": 1.2, "carbs": 0.3, "fiber": 0.0},
    "Ser feta": {"kcal": 264, "protein": 14.2, "fat": 21.3, "carbs": 4.1, "fiber": 0.0},
    "Oliwki czarne": {"kcal": 115, "protein": 0.8, "fat": 10.7, "carbs": 6.3, "fiber": 3.2},
    "Pomidory krojone": {"kcal": 32, "protein": 1.6, "fat": 0.2, "carbs": 5.3, "fiber": 1.5},
    "Sos sojowy": {"kcal": 43, "protein": 4.0, "fat": 0.1, "carbs": 6.5, "fiber": 0.0},
    "Quinoa": {"kcal": 368, "protein": 14.1, "fat": 6.1, "carbs": 64.2, "fiber": 7.0},
    "Pieczarki": {"kcal": 22, "protein": 3.1, "fat": 0.3, "carbs": 3.3, "fiber": 1.0},
    "Bulion warzywny": {"kcal": 15, "protein": 1.0, "fat": 0.5, "carbs": 1.5, "fiber": 0.0},
    "Nasiona chia": {"kcal": 486, "protein": 16.5, "fat": 30.7, "carbs": 42.1, "fiber": 34.4},
}

WEIGHT_PER_SZT = {
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

def calculate_nutrition(prod_name: str, qty_val: float, unit_str: str) -> dict[str, float]:
    nutr = NUTRITION_DATA.get(prod_name, {"kcal":0, "protein":0, "fat":0, "carbs":0, "fiber":0})
    weight_g = float(qty_val)
    if unit_str == "kg" or unit_str == "l":
        weight_g = float(qty_val) * 1000
    elif unit_str == "g" or unit_str == "ml":
        weight_g = float(qty_val)
    elif unit_str == "szt":
        weight_g = float(qty_val) * WEIGHT_PER_SZT.get(prod_name, 100)
    
    return {k: v * (weight_g / 100.0) for k, v in nutr.items()}

# ══════════════════════════════════════════════════════════════════
# PRZEPISY
# ══════════════════════════════════════════════════════════════════
# Każdy przepis: (nazwa, opis, kuchnia, typ_posilku, czas_przygot, czas_gotow,
#                 porcje, trudnosc, tagi, składniki)
# Składnik: (nazwa_produktu, ilość, jednostka, opcjonalny)

RECIPES_DATA = [
    {
        "name": "Jabłko z masłem orzechowym",
        "description": "Szybka i pożywna przekąska na słodko.",
        "cuisine": "polska",
        "meal_type": "przekąska",
        "prep_time_min": 2,
        "cook_time_min": 0,
        "servings": 1,
        "difficulty": "łatwy",
        "tags": ["szybkie", "bezglutenowe", "wegańskie"],
        "ingredients": [
            ("Jabłka", Decimal("1"), "szt", False),
            ("Masło orzechowe", Decimal("30"), "g", False),
        ],
    },
    {
        "name": "Marchewki z hummusem",
        "description": "Chrupiące marchewki maczane w kremowym hummusie.",
        "cuisine": "azjatycka",
        "meal_type": "przekąska",
        "prep_time_min": 5,
        "cook_time_min": 0,
        "servings": 1,
        "difficulty": "łatwy",
        "tags": ["szybkie", "bezglutenowe", "wegańskie"],
        "ingredients": [
            ("Marchew", Decimal("0.2"), "kg", False),
            ("Hummus", Decimal("50"), "g", False),
        ],
    },
    {
        "name": "Jogurt naturalny z malinami",
        "description": "Lekka przekąska białkowa.",
        "cuisine": "polska",
        "meal_type": "przekąska",
        "prep_time_min": 2,
        "cook_time_min": 0,
        "servings": 1,
        "difficulty": "łatwy",
        "tags": ["szybkie", "bezglutenowe", "wegetariańskie"],
        "ingredients": [
            ("Jogurt naturalny", Decimal("150"), "g", False),
            ("Maliny", Decimal("50"), "g", False),
        ],
    },
    {
        "name": "Owsianka na mleku migdałowym",
        "description": "Owsianka na mleku roślinnym z bananem.",
        "cuisine": "polska",
        "meal_type": "śniadanie",
        "prep_time_min": 10,
        "cook_time_min": 0,
        "servings": 1,
        "difficulty": "łatwy",
        "tags": ["wegetariańskie", "zdrowe"],
        "ingredients": [
            ("Płatki owsiane", Decimal("50"), "g", False),
            ("Mleko migdałowe", Decimal("0.2"), "l", False),
            ("Banan", Decimal("1"), "szt", False),
        ],
    },
    {
        "name": "Sałatka grecka",
        "description": "Klasyczna sałatka z fetą i oliwkami.",
        "cuisine": "włoska",
        "meal_type": "kolacja",
        "prep_time_min": 15,
        "cook_time_min": 0,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["wegetariańskie", "bezglutenowe"],
        "ingredients": [
            ("Pomidory", Decimal("0.3"), "kg", False),
            ("Ogórek", Decimal("1"), "szt", False),
            ("Cebula", Decimal("0.1"), "kg", False),
            ("Ser feta", Decimal("100"), "g", False),
            ("Oliwki czarne", Decimal("50"), "g", False),
            ("Oliwa z oliwek", Decimal("20"), "ml", False),
        ],
    },
    {
        "name": "Jajecznica z pomidorami",
        "description": "Klasyczna jajecznica z dojrzałymi pomidorami, podawana z pieczywem.",
        "cuisine": "polska",
        "meal_type": "śniadanie",
        "prep_time_min": 5,
        "cook_time_min": 5,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["szybkie", "bezglutenowe"],
        "ingredients": [
            ("Jajka", Decimal("4"), "szt", False),
            ("Pomidory", Decimal("0.200"), "kg", False),
            ("Masło extra", Decimal("20"), "g", False),
            ("Sól", Decimal("2"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
        ],
    },
    {
        "name": "Kanapki z szynką i serem",
        "description": "Proste kanapki na śniadanie z szynką, serem i warzywami.",
        "cuisine": "polska",
        "meal_type": "śniadanie",
        "prep_time_min": 5,
        "cook_time_min": 0,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["szybkie"],
        "ingredients": [
            ("Chleb pszenny", Decimal("200"), "g", False),
            ("Masło extra", Decimal("20"), "g", False),
            ("Szynka konserwowa", Decimal("100"), "g", False),
            ("Ser żółty gouda", Decimal("80"), "g", False),
            ("Ogórek", Decimal("1"), "szt", False),
            ("Sałata lodowa", Decimal("0.25"), "szt", True),
        ],
    },
    {
        "name": "Owsianka z jogurtem",
        "description": "Ciepła owsianka z jogurtem naturalnym, idealna na pożywne śniadanie.",
        "cuisine": "polska",
        "meal_type": "śniadanie",
        "prep_time_min": 5,
        "cook_time_min": 5,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["wegetariańskie", "zdrowe"],
        "ingredients": [
            ("Płatki owsiane", Decimal("100"), "g", False),
            ("Mleko 2%", Decimal("0.300"), "l", False),
            ("Jogurt naturalny", Decimal("150"), "g", False),
            ("Sól", Decimal("1"), "g", False),
        ],
    },
    {
        "name": "Kotlet schabowy z ziemniakami",
        "description": "Tradycyjny polski kotlet schabowy w panierce, podawany z ziemniakami.",
        "cuisine": "polska",
        "meal_type": "obiad",
        "prep_time_min": 15,
        "cook_time_min": 25,
        "servings": 2,
        "difficulty": "średni",
        "tags": ["tradycyjne", "polska kuchnia"],
        "ingredients": [
            ("Schab wieprzowy", Decimal("0.400"), "kg", False),
            ("Mąka pszenna", Decimal("50"), "g", False),
            ("Jajka", Decimal("2"), "szt", False),
            ("Bułka tarta", Decimal("80"), "g", False),
            ("Ziemniaki", Decimal("0.500"), "kg", False),
            ("Olej rzepakowy", Decimal("0.100"), "l", False),
            ("Sól", Decimal("3"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
        ],
    },
    {
        "name": "Spaghetti bolognese",
        "description": "Klasyczne spaghetti z mięsnym sosem bolońskim na passacie pomidorowej.",
        "cuisine": "włoska",
        "meal_type": "obiad",
        "prep_time_min": 10,
        "cook_time_min": 25,
        "servings": 2,
        "difficulty": "średni",
        "tags": ["włoska kuchnia"],
        "ingredients": [
            ("Makaron penne", Decimal("250"), "g", False),
            ("Mielone wieprzowo-wołowe", Decimal("300"), "g", False),
            ("Passata pomidorowa", Decimal("250"), "g", False),
            ("Cebula", Decimal("0.150"), "kg", False),
            ("Czosnek", Decimal("0.5"), "szt", False),
            ("Oliwa z oliwek", Decimal("30"), "ml", False),
            ("Sól", Decimal("3"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
            ("Bazylia suszona", Decimal("2"), "g", False),
        ],
    },
    {
        "name": "Kurczak z ryżem i warzywami",
        "description": "Lekki obiad — grillowana pierś z kurczaka z ryżem i warzywami.",
        "cuisine": "polska",
        "meal_type": "obiad",
        "prep_time_min": 10,
        "cook_time_min": 20,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["zdrowe", "wysokobiałkowe"],
        "ingredients": [
            ("Pierś z kurczaka", Decimal("0.400"), "kg", False),
            ("Ryż biały", Decimal("0.200"), "kg", False),
            ("Marchew", Decimal("0.200"), "kg", False),
            ("Papryka czerwona", Decimal("1"), "szt", False),
            ("Cebula", Decimal("0.100"), "kg", False),
            ("Olej rzepakowy", Decimal("0.030"), "l", False),
            ("Sól", Decimal("3"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
        ],
    },
    {
        "name": "Zupa pomidorowa z makaronem",
        "description": "Domowa zupa pomidorowa na passacie, podawana z drobnym makaronem.",
        "cuisine": "polska",
        "meal_type": "obiad",
        "prep_time_min": 10,
        "cook_time_min": 20,
        "servings": 4,
        "difficulty": "łatwy",
        "tags": ["tradycyjne", "polska kuchnia", "zupy"],
        "ingredients": [
            ("Passata pomidorowa", Decimal("500"), "g", False),
            ("Makaron penne", Decimal("150"), "g", False),
            ("Marchew", Decimal("0.200"), "kg", False),
            ("Cebula", Decimal("0.100"), "kg", False),
            ("Masło extra", Decimal("20"), "g", False),
            ("Śmietana 18%", Decimal("100"), "ml", False),
            ("Sól", Decimal("5"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
        ],
    },
    {
        "name": "Sałatka z łososiem",
        "description": "Lekka sałatka z wędzonym łososiem, ogórkiem i pomidorami.",
        "cuisine": "polska",
        "meal_type": "kolacja",
        "prep_time_min": 15,
        "cook_time_min": 0,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["zdrowe", "lekkie", "wysokobiałkowe"],
        "ingredients": [
            ("Łosoś wędzony", Decimal("100"), "g", False),
            ("Sałata lodowa", Decimal("0.5"), "szt", False),
            ("Ogórek", Decimal("1"), "szt", False),
            ("Pomidory", Decimal("0.200"), "kg", False),
            ("Oliwa z oliwek", Decimal("20"), "ml", False),
            ("Sól", Decimal("2"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
        ],
    },
    {
        "name": "Naleśniki z serem",
        "description": "Delikatne naleśniki nadziewane twarogiem z masłem.",
        "cuisine": "polska",
        "meal_type": "kolacja",
        "prep_time_min": 10,
        "cook_time_min": 15,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["wegetariańskie", "tradycyjne"],
        "ingredients": [
            ("Mąka pszenna", Decimal("150"), "g", False),
            ("Jajka", Decimal("2"), "szt", False),
            ("Mleko 2%", Decimal("0.250"), "l", False),
            ("Twaróg półtłusty", Decimal("250"), "g", False),
            ("Masło extra", Decimal("30"), "g", False),
            ("Sól", Decimal("2"), "g", False),
        ],
    },
    {
        "name": "Tosty z jajkiem i awokado",
        "description": "Chrupiące tosty z jajkiem sadzonym i kremowym awokado.",
        "cuisine": "polska",
        "meal_type": "kolacja",
        "prep_time_min": 5,
        "cook_time_min": 5,
        "servings": 2,
        "difficulty": "łatwy",
        "tags": ["szybkie", "zdrowe"],
        "ingredients": [
            ("Chleb pszenny", Decimal("200"), "g", False),
            ("Jajka", Decimal("2"), "szt", False),
            ("Awokado", Decimal("1"), "szt", False),
            ("Sól", Decimal("2"), "g", False),
            ("Pieprz czarny mielony", Decimal("1"), "g", False),
            ("Oliwa z oliwek", Decimal("10"), "ml", False),
        ],
    },
    {
        "name": "Shakshuka",
        "description": "Jajka gotowane w pikantnym sosie pomidorowym z papryką i cebulą.",
        "cuisine": "bliskowschodnia",
        "meal_type": "śniadanie",
        "prep_time_min": 10,
        "cook_time_min": 20,
        "servings": 2,
        "difficulty": "średni",
        "tags": ["bezglutenowe", "wegetariańskie"],
        "ingredients": [
            ("Jajka", Decimal("4"), "szt", False),
            ("Pomidory krojone", Decimal("400"), "g", False),
            ("Papryka czerwona", Decimal("1"), "szt", False),
            ("Cebula", Decimal("0.1"), "kg", False),
            ("Czosnek", Decimal("2"), "szt", False),
            ("Oliwa z oliwek", Decimal("30"), "ml", False),
        ],
    },
    {
        "name": "Pad Thai z kurczakiem",
        "description": "Klasyczny tajski makaron smażony z kurczakiem, orzeszkami i limonką.",
        "cuisine": "azjatycka",
        "meal_type": "obiad",
        "prep_time_min": 15,
        "cook_time_min": 15,
        "servings": 2,
        "difficulty": "średni",
        "tags": ["azjatyckie"],
        "ingredients": [
            ("Pierś z kurczaka", Decimal("0.3"), "kg", False),
            ("Makaron penne", Decimal("200"), "g", False),
            ("Jajka", Decimal("2"), "szt", False),
            ("Marchew", Decimal("0.1"), "kg", False),
            ("Sos sojowy", Decimal("30"), "ml", False),
            ("Oliwa z oliwek", Decimal("15"), "ml", False),
        ],
    },
    {
        "name": "Bowl z quinoa i awokado",
        "description": "Zdrowa miska z quinoa, świeżym awokado, pomidorkami i hummusem.",
        "cuisine": "polska",
        "meal_type": "obiad",
        "prep_time_min": 15,
        "cook_time_min": 15,
        "servings": 1,
        "difficulty": "łatwy",
        "tags": ["wegańskie", "bezglutenowe", "zdrowe"],
        "ingredients": [
            ("Quinoa", Decimal("0.1"), "kg", False),
            ("Awokado", Decimal("1"), "szt", False),
            ("Pomidory krojone", Decimal("200"), "g", False),
            ("Hummus", Decimal("50"), "g", False),
            ("Oliwa z oliwek", Decimal("15"), "ml", False),
        ],
    },
    {
        "name": "Risotto z grzybami leśnymi",
        "description": "Kremowe risotto z mieszanką grzybów leśnych i parmezanem.",
        "cuisine": "włoska",
        "meal_type": "kolacja",
        "prep_time_min": 10,
        "cook_time_min": 30,
        "servings": 2,
        "difficulty": "średni",
        "tags": ["wegetariańskie", "włoskie"],
        "ingredients": [
            ("Ryż biały", Decimal("0.2"), "kg", False),
            ("Pieczarki", Decimal("0.2"), "kg", False),
            ("Cebula", Decimal("0.1"), "kg", False),
            ("Masło extra", Decimal("30"), "g", False),
            ("Ser żółty gouda", Decimal("50"), "g", False),
            ("Bulion warzywny", Decimal("1"), "szt", False),
        ],
    },
    {
        "name": "Overnight oats z chia i owocami",
        "description": "Owsianka przygotowana wieczorem — rano gotowa do jedzenia z owocami.",
        "cuisine": "polska",
        "meal_type": "śniadanie",
        "prep_time_min": 5,
        "cook_time_min": 0,
        "servings": 1,
        "difficulty": "łatwy",
        "tags": ["szybkie", "wegetariańskie", "zdrowe"],
        "ingredients": [
            ("Płatki owsiane", Decimal("80"), "g", False),
            ("Mleko 2%", Decimal("0.2"), "l", False),
            ("Nasiona chia", Decimal("20"), "g", False),
            ("Banan", Decimal("1"), "szt", False),
            ("Maliny", Decimal("50"), "g", False),
        ],
    },
]


# ══════════════════════════════════════════════════════════════════
# FUNKCJA SEED
# ══════════════════════════════════════════════════════════════════


async def seed_database(session: AsyncSession) -> None:
    """Wypełnia bazę danych danymi startowymi.

    Funkcja jest idempotentna dzięki determinystycznym UUID —
    duplikaty zostaną odrzucone przez merge.

    Args:
        session: Aktywna sesja async SQLAlchemy.
    """

    # ── 1. Sklepy ────────────────────────────────────────────────
    stores: dict[str, Store] = {}
    for store_name in STORE_NAMES:
        store = Store(
            id=_uid(f"store:{store_name}"),
            name=store_name,
            logo_url=None,
            department_order={
                dept: idx for idx, dept in enumerate(DEPARTMENT_NAMES)
            },
        )
        stores[store_name] = await session.merge(store)

    # ── 2. Działy sklepowe ───────────────────────────────────────
    # Klucz: (store_name, dept_name) -> StoreDepartment
    departments: dict[tuple[str, str], StoreDepartment] = {}
    for store_name, store in stores.items():
        for idx, dept_name in enumerate(DEPARTMENT_NAMES):
            dept = StoreDepartment(
                id=_uid(f"dept:{store_name}:{dept_name}"),
                store_id=store.id,
                name=dept_name,
                sort_order=idx,
            )
            departments[(store_name, dept_name)] = await session.merge(dept)

    # ── 3. Alergeny ──────────────────────────────────────────────
    allergens: dict[str, Allergen] = {}
    for allergen_name in ALLERGEN_NAMES:
        allergen = Allergen(
            id=_uid(f"allergen:{allergen_name}"),
            name=allergen_name,
        )
        allergens[allergen_name] = await session.merge(allergen)

    # ── 4. Produkty + StoreProducts + ProductAllergens ───────────
    products: dict[str, Product] = {}
    for (
        prod_name,
        unit,
        default_qty,
        dept_name,
        base_price,
        allergen_names,
    ) in PRODUCTS_DATA:
        product = Product(
            id=_uid(f"product:{prod_name}"),
            name=prod_name,
            brand=None,
            unit=unit,
            default_quantity=default_qty,
            barcode=None,
            nutrition_per_100=NUTRITION_DATA.get(prod_name),
            image_url=None,
        )
        products[prod_name] = await session.merge(product)

        # Powiązanie z alergenami
        for al_name in allergen_names:
            pa = ProductAllergen(
                product_id=product.id,
                allergen_id=allergens[al_name].id,
            )
            await session.merge(pa)

        # Powiązanie z każdym sklepem
        for store_name, store in stores.items():
            multiplier = PRICE_MULTIPLIERS[store_name]
            price = (base_price * multiplier).quantize(Decimal("0.01"))
            dept = departments[(store_name, dept_name)]

            sp = StoreProduct(
                id=_uid(f"sp:{store_name}:{prod_name}"),
                store_id=store.id,
                product_id=product.id,
                department_id=dept.id,
                price=price,
                is_available=True,
                last_verified=date.today(),
                withdrawn_at=None,
            )
            await session.merge(sp)

    # ── 5. Przepisy + Składniki + Tagi ───────────────────────────
    for recipe_data in RECIPES_DATA:
        total_nutrition = {"kcal": 0, "protein": 0, "fat": 0, "carbs": 0, "fiber": 0}
        for prod_name, qty, unit, is_optional in recipe_data["ingredients"]:
            prod_nutr = calculate_nutrition(prod_name, float(qty), unit)
            for k in total_nutrition:
                total_nutrition[k] += prod_nutr.get(k, 0)
        
        total_nutrition = {k: round(v, 1) for k, v in total_nutrition.items()}
        
        recipe = Recipe(
            id=_uid(f"recipe:{recipe_data['name']}"),
            name=recipe_data["name"],
            description=recipe_data["description"],
            cuisine=recipe_data["cuisine"],
            meal_type=recipe_data["meal_type"],
            prep_time_min=recipe_data["prep_time_min"],
            cook_time_min=recipe_data["cook_time_min"],
            servings=recipe_data["servings"],
            difficulty=recipe_data["difficulty"],
            nutrition_total=total_nutrition,
            image_url=None,
            is_active=True,
        )
        await session.merge(recipe)

        # Tagi
        for tag in recipe_data["tags"]:
            rt = RecipeTag(
                id=_uid(f"tag:{recipe_data['name']}:{tag}"),
                recipe_id=recipe.id,
                tag=tag,
            )
            await session.merge(rt)

        # Składniki
        for prod_name, qty, unit, is_optional in recipe_data["ingredients"]:
            if prod_name not in products:
                raise ValueError(
                    f"Produkt '{prod_name}' nie został zdefiniowany w PRODUCTS_DATA. "
                    f"Dodaj go przed użyciem w przepisie '{recipe_data['name']}'."
                )
            ri = RecipeIngredient(
                id=_uid(f"ri:{recipe_data['name']}:{prod_name}"),
                recipe_id=recipe.id,
                product_id=products[prod_name].id,
                quantity=qty,
                unit=unit,
                is_optional=is_optional,
            )
            await session.merge(ri)

    await session.flush()
