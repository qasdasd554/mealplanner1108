# 1.0.75+276 — ceny UK i zamienniki

- Naprawiono listę i zapis zamienników produktów na listach zakupów UK.
- 390 systemowych produktów ma bazowe orientacyjne ceny GBP, na zasadzie
  statycznego katalogu PL. Są to szacunki modelu, nie aktualne ceny wszystkich
  sklepów ani przeliczone ceny PLN. Prawdziwe dostępne oferty mają pierwszeństwo.
- Wycena uwzględnia potrzebną ilość; nie tworzy fikcyjnych opakowań.
- Poprawiono konflikt g/ml w starszych miarach produktów systemowych.
- Koszt przelicza się po zamianie produktu. Brak wyników ma czytelny komunikat.
- Powiadomienie aktualizacji przedstawia bieżące cztery najważniejsze zmiany.

Nie zmieniono kraju istniejących kont ani rozdzielenia społeczności PL/UK.
Nie ma nowych zależności ani migracji. Należy wdrożyć backend i aplikację.
Jeśli APP_VERSION jest ręcznie ustawione na Renderze: 1.0.75.
