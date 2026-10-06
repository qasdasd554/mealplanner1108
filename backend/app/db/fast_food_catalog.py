"""Popularne gotowe produkty sieciowe z porcją i makro na 100 g.

Dane pochodzą z publicznych tabel żywieniowych właścicieli marek. Nazwy i
wartości są oddzielone od głównego seeda, żeby można je było aktualizować bez
ryzyka naruszenia katalogu składników używanych w przepisach.
"""

from __future__ import annotations


FAST_FOOD_PRODUCTS = [
    # McDonald's Polska — klasyczne pozycje z tabeli wartości odżywczych.
    ("Hamburger", "McDonald's", 107, 242, 13.0, 8.2, 29.0, 1.0),
    ("Cheeseburger", "McDonald's", 119, 254, 16.0, 10.0, 26.0, 1.0),
    ("Big Mac", "McDonald's", 217, 242, 12.0, 12.0, 20.0, 1.4),
    ("McRoyal", "McDonald's", 213, 259, 14.0, 14.0, 18.0, 1.2),
    ("WieśMac", "McDonald's", 225, 248, 12.0, 12.0, 19.0, 1.3),
    ("McChicken", "McDonald's", 188, 227, 11.0, 11.0, 24.0, 1.2),
    # KFC Polska, tabela z 27.08.2026.
    ("Zinger Burger", "KFC", 170, 262, 15.0, 13.0, 21.0, 0.0),
    ("Zinger Max", "KFC", 240, 246, 17.0, 12.0, 17.0, 0.0),
    ("Grander Burger", "KFC", 300, 252, 12.0, 13.0, 20.0, 0.0),
    ("Longer", "KFC", 127, 244, 12.0, 6.4, 34.0, 0.0),
    ("Twister", "KFC", 226, 256, 10.0, 13.0, 25.0, 0.0),
    ("Hot & Spicy Strips 3 szt.", "KFC", 96, 288, 21.0, 19.0, 9.9, 0.0),
    ("Hot Wings 5 szt.", "KFC", 180, 320, 20.0, 21.0, 14.0, 0.0),
    ("Frytki", "KFC", 80, 252, 3.6, 10.0, 37.0, 0.0),
    # MAX Premium Burgers Polska — aktualna tabela online.
    ("Cheddar Melt Beef 'n' Bacon", "MAX Premium Burgers", 329, 281, 11.0, 20.0, 15.0, 0.6),
    ("Raclette Melt Beef 'n' Bacon", "MAX Premium Burgers", 316, 273, 11.0, 19.0, 14.0, 0.6),
    ("Chicken Nuggets 4 szt.", "MAX Premium Burgers", 80, 200, 11.0, 10.0, 16.0, 0.9),
    ("Cheesy Toast", "MAX Premium Burgers", 77, 341.35, 9.83, 18.31, 33.62, 0.86),
    ("Choco Churros 3 szt.", "MAX Premium Burgers", 54, 374, 4.7, 22.0, 37.0, 3.5),
    ("Cheese Fries Large", "MAX Premium Burgers", 285, 269.98, 2.62, 14.85, 29.75, 2.31),
    # Żabka Café — tabela z 15.04.2025.
    ("Zapiekanka salami i ser", "Żabka Café", 212, 254, 10.0, 12.0, 30.0, 0.0),
    ("Zapiekanka kurczak i ser", "Żabka Café", 220, 246, 13.0, 10.0, 32.0, 0.0),
    ("Pizza Italiana Margherita", "Żabka Café", 220, 219, 10.0, 10.0, 22.0, 0.0),
    ("Serki w panierce nachos", "Żabka Café", 148, 292, 13.0, 17.0, 25.0, 0.0),
    ("Strips Classic", "Żabka Café", 120, 201, 18.0, 10.0, 22.0, 0.0),
    ("Łódeczki ziemniaczane", "Żabka Café", 150, 157, 2.0, 6.0, 23.0, 0.0),
    # Burger King — oficjalna tabela marki; skład lokalny może nieznacznie
    # różnić się między rynkami, dlatego rekordy zachowują konkretną porcję.
    ("Whopper", "Burger King", 270, 244.4, 10.4, 14.8, 18.1, 0.7),
    ("Cheeseburger", "Burger King", 111, 252.3, 13.5, 11.7, 24.3, 0.9),
    ("Double Cheeseburger", "Burger King", 148, 263.5, 15.5, 14.2, 18.2, 0.7),
    ("Chicken Nuggets 6 szt.", "Burger King", 88, 295.5, 13.6, 18.2, 18.2, 1.1),
    ("Original Chicken", "Burger King", 219, 301.4, 12.8, 18.3, 21.9, 0.9),
    # North Fish — oficjalna polska tabela wartości odżywczych. Dodajemy
    # całe porcje, a nie sztuczne odpowiedniki produktów supermarketowych.
    ("Łosoś norweski grillowany", "North Fish", 150, 176, 19.0, 11.0, 0.5, 0.0),
    ("Nuggetsy z mintaja 6 szt.", "North Fish", 120, 217, 9.3, 5.1, 17.8, 0.0),
    ("Mintaj panierowany", "North Fish", 120, 183, 9.6, 10.2, 12.8, 0.0),
    ("Fishburger Classic", "North Fish", 175, 216, 8.5, 8.9, 24.7, 0.0),
    ("Tortilla z łososiem", "North Fish", 200, 264, 13.0, 11.0, 27.0, 0.0),
    ("Krewetki z grilla na sałacie", "North Fish", 170, 103, 8.2, 3.8, 2.1, 0.0),
]
