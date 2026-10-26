# 1.0.76+277 — stabilność planów, skanowania i list zakupów

- Naprawiono zamianę dań w planie i przeładowanie składników bez ukrytych operacji
  bazy, które powodowały błąd serwera. Lista zakupów jest przeliczana po zmianie.
- Zapis zeskanowanego produktu nie przerywa transakcji spiżarni. Zachowane są
  wartości odżywcze i znane gramatury opakowań, także przy powtórnym dodaniu.
- Zamienniki są filtrowane i ponownie weryfikowane dla wybranego sklepu w PL/UK.
  Sama orientacyjna cena krajowa nie dowodzi dostępności produktu w sklepie;
  bez odpowiedniej oferty aplikacja uczciwie pokaże brak zamienników.
- Zamiana zachowuje ilość w zgodnych jednostkach i przelicza koszt opakowań.
- Edytowany wpis Dziennika zachowuje nazwę przepisu. Błędy zamiany są tłumaczone
  i nie pokazują użytkownikowi surowych identyfikatorów.
- Odświeżono cztery najważniejsze punkty powiadomienia o aktualizacji w PL/EN.

Wymagane jest wdrożenie backendu i nowej aplikacji. Brak nowych zależności,
migracji i zmian kraju kont. Jeżeli APP_VERSION na Renderze jest ustawione
ręcznie, ustaw 1.0.76 po wdrożeniu. Nie wymagaj nowej wersji przed publikacją.
