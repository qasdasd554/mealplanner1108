# UK — pełne nazwy katalogu i rzeczywiste powiązania OFF, 23.10.2026

Kontynuacja po [etapie 36](uk-stage36-shared-list-language.md).
Przed zmianami zapisano sześć kopii w `../backups/uk-stage37-20261023/`.
Bez zmiany wyglądu, nowych funkcji, aktywacji UK ani wdrożenia.

## Przyczyna luki

Generator etykiet wybierał tylko 150 składników użytych w 137 wbudowanych
przepisach. Tymczasem istniejący `PRODUCTS_DATA` zawiera 390 produktów.
Pozostałe 240 pozycji nie miało angielskiego aliasu ani wpisu dokładnej
tożsamości systemowej. Dotyczyło to m.in. ryżu basmati, koncentratu
pomidorowego i czerwonej fasoli konserwowej. Ponieważ ten sam indeks chroni
powiązania OFF przed przypadkowymi markowymi SKU, niepełny indeks utrudniał
także prawidłowe powiązanie tych produktów.

Nie jest to dodanie 240 nowych produktów do bazy — one już istniały.

## Zmiana

- Uzupełniono 240 brytyjskich nazw istniejących produktów, m.in. `Maize flour`
  dla mąki kukurydzianej (nie brytyjskiego `cornflour`, czyli skrobi),
  `Bicarbonate of soda`, `Icing sugar`, `Rocket`, `Beef mince`.
- Generator czyta literalne dane całego katalogu i dodatkowej setki przez AST.
  Nie wykonuje `seed_database`, nie importuje danych do Neon i nie łączy się
  z siecią. Wymaga pełnego pokrycia nazw, unikalnych tożsamości oraz obecności
  wszystkich składników systemowych przepisów w katalogu.
- Backend i Flutter korzystają z tego samego wygenerowanego indeksu 390 ID.
  Zachowano sprawdzanie dokładnego ID i pierwotnej nazwy; cudza nazwa podobna
  do systemowej ani zmodyfikowany produkt nie dostają automatycznie aliasu.
- Wszystkie poprzednie 150 aliasów oraz 137 nakładek treści przepisów są
  identyczne z backupem. Nie zmieniono ID, polskich nazw, jednostek,
  wartości odżywczych, opakowań ani cen.
- Nazwa angielska nie jest dowodem sprzedaży w UK. Filtr dostępności nadal
  wymaga osobnego potwierdzenia OFF lub sprawdzonej oferty sklepu.

Indeks backendu wzrósł z 60 732 do 89 170 bajtów, a generowany plik Dart
z 184 150 do 210 817 bajtów. Nie powstało dodatkowe żądanie HTTP ani odczyt
per produkt. Nie jest to pomiar wydajności na telefonie ani rozmiaru AAB.

## Mała partia rzeczywistych danych

Wyszukiwanie kategorii OFF zwracało podczas badania 503, natomiast odczyt
konkretnych kodów UK zwrócił 200. Nie dodawano pętli ponawiania do aplikacji.
Dokumentacja OFF opisuje ograniczenia i 503 przy globalnym przeciążeniu:
[oficjalne API](https://openfoodfacts.github.io/openfoodfacts-server/api/).

Sprawdzono nazwy, teksty składników i kategorie sześciu rekordów:

| Składnik systemowy | Rekord OFF | Zakres powiązania |
| --- | --- | --- |
| Ryż basmati | [20071974](https://world.openfoodfacts.org/product/20071974) | Suchy ryż basmati, nie gotowe danie ani inny rodzaj ryżu |
| Passata pomidorowa | [20522605](https://world.openfoodfacts.org/product/20522605) | Passata, deklarowane 100% pomidorów |
| Koncentrat pomidorowy | [20522612](https://world.openfoodfacts.org/product/20522612) | Brytyjskie tomato purée/paste, nie passata |
| Ciecierzyca konserwowa | [4056489903703](https://world.openfoodfacts.org/product/4056489903703) | Ciecierzyca w wodzie, nie sucha |
| Fasola czerwona konserwowa | [4056489903710](https://world.openfoodfacts.org/product/4056489903710) | Czerwona fasola konserwowa, nie biała ani sucha |
| Masło extra | [4056489895268](https://world.openfoodfacts.org/product/4056489895268) | Niesolone masło, deklarowany tłuszcz 82% |

Publiczne projekcje odpowiedzi z czasem pobrania, ODbL i propozycjami
powiązań zapisano w `backend/tests/fixtures/off_uk_staples_20261023.json`.
`automatic_import=false`; plik służy jako dowód/test i nie jest odczytywany
przez aplikację ani automatycznie importowany do Neon. Test używa dotychczasowego
chronionego importera w lokalnym SQLite, z transakcją i wycofaniem mapowań.
Późniejszy import wymaga bieżącego zgodnego cache OFF i aktualnego administratora;
zmiana fingerprintu nie jest po cichu akceptowana.

Powiązania dowodzą jedynie zgłoszonej sprzedaży danego rodzaju żywności w UK.
Nie przenoszą makro, marki, gramatury opakowania ani ceny z innego SKU na składnik.
Nie rozstrzygają masy po odsączeniu, nie tworzą produktów sklepowych ani ceny.
W obserwowanej projekcji ryżu brakowało makro — nie zastąpiono go zerami i nie
nadpisano wartości kanonicznego ryżu. Brak aktualnych danych nie jest £0.
Nie pobierano całego OFF i nie seedowano katalogu w produkcji.

## Dowody

- Test pokrycia przed poprawką odtworzył `150 != 390` (czerwony → zielony).
- Skupione testy katalogu, języka i powiązań: **157 passed**, 3 ostrzeżenia,
  exit 0 (`uk-stage37-targeted.log`).
- Partia Fluttera (etykiety, wybór z katalogu, kontrakt produktu UK):
  **144 passed**, exit 0 (`uk-stage37-flutter.log`).
- Pełny backend po zmianie danych/generatora: **2424 passed**, 43 ostrzeżenia
  zależności/deprecacji, 144,01 s, exit 0 (`uk-stage37-backend-final.log`).
- Pełny Flutter: **1079 passed**, exit 0, ok. 158 s
  (`uk-stage37-flutter-final.log`), concurrency 2, bez pobierania pakietów.
- Końcowa ponowna próba samych danych OFF po przeniesieniu pliku dowodowego
  do samowystarczalnego katalogu fixtures: **3 passed**, exit 0.
- Generator `--check`: 137 przepisów, 390 produktów, bez zmiany liczb w
  instrukcjach. Kontrola wszystkich wcześniejszych wpisów względem backupu:
  zgodne. Compileall i kontrola whitespace zmienionych plików: exit 0.
- `dart analyze` zmienionego rejestru i testu: **No issues found**, exit 0.
  UTF-8/LF i końcowe spacje sprawdzono też bezpośrednio, niezależnie od Git
  (część plików rozbudowy UK jest jeszcze nieśledzona).

Nie wykonywano nowych testów Neon ani natywnego AAB/IPA, aparatu lub płatności.
Pozostają dalsze rzeczywiste powiązania i źródła cen GBP, dokumenty i testy
na urządzeniach. Wersja 1.0.69+270 i `UK_MARKET_ENABLED=False` bez zmian;
zamrożony ZIP 270 nadal ma SHA-256
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
Późniejsze wydanie wymaga nowego snapshotu Codespace i aktualnych notatek
w powiadomieniu o aktualizacji; tego etapu nie dopisywano do starego ZIP-a.
