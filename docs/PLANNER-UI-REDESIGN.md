# Odświeżenie interfejsu, 12.10.2026

Backup przed pierwszą zmianą UI: `../backups/mealplanner-before-ui-20261012-102738.zip`.
575 plików, również wcześniejsze niezapisane w Git poprawki subskrypcji i miniaturek.
SHA-256 archiwum: `CEA881B087C0C21FDE9591A6F8E367847108BD5298AA3C880957343ACC46DEBF`.
Baza Git: `19b88fb5306644b5a894e0fa360f1879d3468338`.

## Decyzje

- Codzienny użytkownik: szybkie sprawdzenie planu, posiłków i bilansu; stabilna nawigacja.
- Flutter na Androidzie i iOS, istniejące trasy i reguły dostępu.
- Motyw graficzny: zielona zakładka planera, neutralne ikony, zdjęcia przepisów.
- Start: skróty w dwóch kolumnach, wspólna sekcja planu i posiłków, wskazówka Premium po planie.
- Przepisy: zdjęcie 4:3, czytelne metadane, filtry z pełnymi etykietami.
- Dziennik: kompaktowy bilans i posiłki w grupach, edycja ilości i potwierdzenie usunięcia.
- Plakietki Premium pozostają. Cena i odnowienie są blisko przycisku zakupu.
- Podgląd korzyści: Przepisy AI / Skanowanie / Planowanie. Przełączanie nie uruchamia zakupu.
- Trial dotyczy uprawnionych kont; rzeczywistą dostępność potwierdza sklep. Ceny pochodzą ze sklepu.
- Nie zwiększono częstotliwości automatycznych ofert, nie dodano nowych limitów ani nowych płatnych blokad.
- Większa czcionka może powiększać kafelki i przenosić filtry do kolejnego wiersza.
- Stan ładowania/błędu zachowuje istniejące mechanizmy odświeżania. Nie tworzy fałszywych danych.

## Powrót do wyglądu sprzed zmian

Rozpakować backup do osobnego katalogu. Przywrócić z niego poniższe pliki do repozytorium,
po sprawdzeniu, czy nie mają późniejszych zmian, które należy zachować:

- `frontend/lib/theme/app_theme.dart`
- `frontend/lib/widgets/premium_feature_tag.dart`
- `frontend/lib/screens/home/home_screen.dart`
- `frontend/lib/screens/recipes/recipes_screen.dart`
- `frontend/lib/screens/tracker/calorie_tracker_screen.dart`
- `frontend/lib/screens/profile/premium_screen.dart`
- `frontend/lib/services/update_service.dart`

Nowe `planner_components.dart` po przywróceniu ekranów nie wpływa na wygląd.
Przy pełnym cofnięciu należy też wycofać `planner_ui_test.dart` i `planner_screens_test.dart`,
ponieważ sprawdzają nowy interfejs, którego nie było w backupie.
Przywrócenie tylko wymienionych plików zachowa wcześniejsze poprawki backendu i zdjęć.
Jeżeli zmiany były już opublikowane, odtworzony wygląd wymaga kolejnego buildu sklepowego.

## Sprawdzenie

`flutter test --no-pub` obejmuje testy komponentów, rzeczywistego Startu i Dziennika,
anulowania usuwania, menu Dodaj, wybierania korzyści oraz blokowania zakupu podczas przetwarzania.
Układy są sprawdzane dla szerokości 320/390/768, dużego tekstu i obu motywów.

Test `planner_screens_test.dart` może zapisywać obrazy renderowanego Fluttera, gdy ustawiono
`UI_CAPTURE_DIR`. Opcjonalne `UI_FONT_PATH` i `UI_ICON_FONT_PATH` służą wyłącznie podglądowi testowemu.
Podglądy komponentów oferty i przepisów używają jawnych danych testowych; nie uruchamiają płatności.

Weryfikacja końcowa: 102 testy Fluttera przeszły. Analiza `lib` i `test` nie wykazała błędów
ani ostrzeżeń; pozostają istniejące informacje o stylu kodu i wycofywanych API.
Formatowanie zmienionych plików oraz `git diff --check` przeszły.
Sprawdzono rendery Startu, Dziennika, oferty Premium i kart przepisów w obu motywach.
Nie przeprowadzono zakupu w rzeczywistym sklepie ani testu na fizycznym urządzeniu w tym środowisku.

Wzrost sprzedaży należy ocenić po wdrożeniu, porównując rozpoczęte próby oraz zakupy subskrypcji
przed i po aktualizacji. Zmiana interfejsu sama w sobie nie potwierdza wzrostu konwersji.
