# Końcowa weryfikacja etapu 17 — 22.10.2026

Stan lokalny, wersja 1.0.66+267, UK wyłączone. Nie utworzono AAB/IPA/ZIP,
nie wysłano zmian do GitHuba/Rendera/sklepów.

## Świeże wyniki

- `ENVIRONMENT=test python -m pytest tests -q` z `backend/`: **1396 passed**,
  41 istniejących ostrzeżeń deprecacji bibliotek, exit 0, 78.41 s.
  Log `uk-stage17-backend-final.log`.
- `flutter test --no-pub --reporter expanded`: **597 passed**, exit 0,
  1 min 21 s. Log `uk-stage17-flutter-final.log`.
- `flutter analyze --no-pub --no-fatal-infos`: **0 błędów, 0 ostrzeżeń**,
  370 wskazówek typu info, exit 0. Log `uk-stage17-analyze-final.log`.
- `python -m compileall -q backend/app backend/tests`: exit 0.
- `git -c core.autocrlf=false diff --check`: exit 0.
- Pliki zmieniane w tych etapach znormalizowano do UTF-8/LF, bez BOM.
  Wybrane pliki Dart sformatowano, bez globalnego formatowania projektu.

## Regresje i niezależne sprawdzenie

- PL listowy endpoint przed poprawką: 6 failing / 2 passing w ośmiu
  przypadkach, z rzeczywistymi wierszami SQLite. Po poprawce wspólny
  przebieg PL/GB porównania: 38 passing.
- Ogólny guard: odtworzono brak wykrycia innych rodzin gotowych dań
  oraz błędne odrzucenie pasty/przyprawy curry, następnie poprawiono
  regułę i dodano pozytywne oraz negatywne przykłady obu języków.
- Test z czterema składnikami i tańszym gotowym posiłkiem w katalogu
  przechodzi dla obu rynków, z autoflush i bez autoflush.
- Pełna nazwa przepisu zgłoszona przez właściciela występuje tylko jako
  regresja, nie jako specjalna reguła naprawy w kodzie.
- Niezależny subagent wskazał nieudowodnioną konwersję jednostek PLN;
  zaimplementował poprawkę i 50 nowych przypadków regresji w osobnym
  pliku, następnie root przeczytał kod i wykonał pełne testy projektu.
- Subagent odtworzył także brak tożsamości dawnych wierszy PL bez oferty
  źródłowej. Pozostają jawnie niewycenione; nie naprawiano ich przez
  niebezpieczne dopasowanie nazwy. Ograniczenie opisuje raport zakresu.
- W odizolowanych testach potwierdzono uprawnienia zaakceptowanego
  współdzielenia między rynkami, zachowanie zakupionej pozycji i rollback
  przy awarii flush. To przegląd tych zmian, nie pełny niezależny audyt UK.
- Premium: granica 24 godzin ma test backendu. Testy klienta sprawdzają
  jedno pokazanie w sesji PL/GB, blokadę podczas pisania, aktywne Premium
  i odrzucenie odpowiedzi przy zmianie sesji.
- Komunikat aktualizacji: 3 bieżące punkty w obu językach, test przy
  szerokości 320 px i skali tekstu 150%, bez RenderFlex overflow.

Testy nie kontaktują się z płatnym AI, nie wysyłają push i nie sprawdzają
rzeczywistego asortymentu ani cen sklepów. Nie potwierdzają natywnego
buildu ani zachowania fizycznego telefonu. Jednorazowe odczytowe zapytanie
do kopii Neon służyło wyłącznie porównaniu zapisanych składników;
nie zmieniło danych ani schematu. Dane połączenia nie są w repozytorium.
