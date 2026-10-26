# UK: ceny bazowe i zamienniki — 2026-10-26

## Przyczyna

Polska korzysta ze statycznych cen seed i mnożników sklepowych. UK wymagało
osobno zweryfikowanej oferty sklepowej także dla zamienników. To wykluczało
produkty systemowe, mimo że znajdowały się już w katalogu. Dotychczasowa
wycena referencyjna ONS obejmowała tylko część katalogu.

## Zmiana zgodna z decyzją użytkownika

- Statyczny model planowania GBP obejmuje 390 niezmienionych produktów
  systemowych, na zasadzie bazowych cen katalogowych używanej w PL.
- Stawki modelu to jawne założenia orientacyjne, NIE odczytane ceny wszystkich
  produktów w internecie, NIE przeliczenie PLN na GBP i NIE potwierdzenie
  asortymentu danego sklepu.
- Zweryfikowana oferta detaliczna ma pierwszeństwo; istniejąca poprawna
  referencja ONS również pozostaje preferowana przed statycznym fallbackiem.
- Mnożnik wszystkich sklepów UK wynosi 1.00, dopóki nie istnieją rzeczywiste
  dane różnicujące ceny. Model nie generuje fikcyjnego najtańszego sklepu ani
  oszczędności.
- Ceny liczone są dla potrzebnej ilości, nie rzekomego opakowania. Nie
  tworzymy gramatur opakowań ani dat bieżącej weryfikacji. Zapis źródła
  jednoznacznie identyfikuje model i jego datę 2026-10-26.
- Wyszukiwanie i zapis zamiennika dopuszczają kanoniczne produkty systemowe
  bez zweryfikowanego SKU sklepowego. Zapis ponownie wycenia listę w GBP.
- Automatyczne wycofanie SKU nie zamienia go samoczynnie na ogólną referencję.
- Pusty wynik ma czytelny komunikat; cena referencyjna ma jednostkę 100 g/ml
  lub sztukę w katalogu, zamiast fałszywej etykiety opakowania.
- Jawne g/ml mają pierwszeństwo przed heurystyką nazwy. Stare sprzeczne
  miary systemowych kostek bulionu i produktów ważonych naprawiane są przy
  odczycie; cudze lub zmienione tożsamości nie dziedziczą tego wyjątku.
- Zaktualizowano cztery najważniejsze punkty powiadomienia o aktualizacji.

## Weryfikacja

- Backend: 535 passed, 3039 deselected, 1 warning — zestaw regionalny,
  wyceny, zamienniki i miary. Log: `docs/audit/uk-substitute-static-backend-20261026.txt`.
- Flutter: 37 passed — katalog, lista zakupów, wybór/zapis zamiennika,
  opis źródła, porównania i powiadomienie. Log:
  `docs/audit/uk-substitute-static-flutter-20261026.txt`.
- Analiza zmienionych plików Dart: 0 errors, 0 warnings, 25 porad lint
  (m.in. istniejące deprecations). Log:
  `docs/audit/uk-substitute-static-analyze-final-20261026.txt`.
- Formatter Dart: 11 files, 0 changed.

Zmiany są lokalne. Nie wykonano wdrożenia, zapisu do produkcyjnej bazy ani
nowego natywnego buildu Android/iOS. Wcześniej wydany ZIP 275 nie zawiera
tej nowszej poprawki i nie został nadpisany.
