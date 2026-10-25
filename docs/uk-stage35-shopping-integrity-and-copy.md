# UK — tożsamość zakupów, historia opakowań i komunikaty, 23.10.2026

Etap lokalny po [etapie 34](uk-stage34-product-presentation.md), bez wydania,
aktywacji UK, przebudowy interfejsu ani nowej funkcji. Przed zmianami zapisano
kopie w `../backups/uk-stage35-20261023/`. Nie zmieniano schematu ani danych Neon.

## Odtworzone problemy

1. Przy braku poprawnej oferty `apply_regional_item_quote` nadal brało nazwę
   z pierwszego pasującego wiersza sklepu. Mógł to być nieważny/zmieniony SKU,
   a nie wybrana oferta. Bez ofert pojawiała się polska nazwa systemowa.
   Także część „In pantry” bywała podpisana nazwą sklepowego opakowania.
2. Porównanie planu miało polskie nazwy systemowe w grupie spiżarni oraz
   na liście produktów bez ceny, mimo że właściwe wycenione SKU były angielskie.
3. Zakończenie zakupów kontrolowało mnożenie opakowań, ale nie używało pełnej
   kontroli historii już stosowanej przy porównaniu i zmianie sklepu. Mogło
   przyjąć sprzeczną jednostkę, wymaganie lub metadane zapisanej wyceny.
4. Wspólne endpointy zakupów miały jeszcze polskie komunikaty w odpowiedziach
   kont GB: m.in. brak listy/sklepu, łączenie, zaproszenia, własne pozycje,
   zakończenie oraz odmowa dopisania kolejnego przepisu na koncie Standard.

Nowe testy odtworzyły błędne zachowania przed poprawkami. Próby dotyczą
mechanizmów, nie wyjątków dla jednego przepisu ani pojedynczego produktu.

## Naprawa

- Nazwa SKU jest używana tylko po wybraniu poprawnej wyceny. W pozostałych
  przypadkach pozostaje tożsamość składnika; znane systemowe etykiety mają
  angielskie odpowiedniki z istniejącego indeksu. Nazw autorskich nie zgadujemy.
- Spiżarnia pokazuje składnik, nie niepotwierdzone sklepowe opakowanie.
  Brak ceny to nadal `null`, a rzeczywiste pokrycie spiżarni to 0 GBP.
- Wymagane gramy/ml i liczba całych lokalnych opakowań pozostają bez zmian.
  Test kontroluje m.in. składnik o polskim przykładowym opakowaniu 500 g
  i prawidłowe kupienie jednego lokalnego opakowania 750 g dla wymogu 600 g.
- Zakończenie korzysta z `regional_snapshot_requirement` oraz tej samej
  `frozen_regional_purchase_quote`, co porównanie i zmiana sklepu. Cała partia
  jest sprawdzana przed modyfikacją spiżarni. Niespójność daje 409 i komunikat
  z możliwością poprawy pozycji lub zakończenia bez przenoszenia do spiżarni.
- Poprawna historia zakupu nie znika po usunięciu oferty. Nie wycenia się
  kupionego opakowania według innego sklepu lub dzisiejszej ceny.
- Zakup bez znanej ceny, ale ze znaną ilością w g/ml, nadal można przenieść:
  np. dokładnie 600 g, bez domyślnego „polskiego opakowania”. Ponowienie
  zakończenia nie dodaje tej ilości drugi raz.
- Teksty wspólnych endpointów wybierane są z zapisanego kraju konta. Bez
  zmian statusów HTTP, limitów, uprawnień, powiadomień lub operacji na danych.
  Angielski prefiks limitu jest zgodny z dotychczasowym klientem Premium.
  Wyłącznie polskie gałęzie obsługi rynku PL zachowują swoje dotychczasowe kopie.

## Dowody i granice weryfikacji

- Pełny backend po zmianach produkcyjnych: **2345 passed**, 43 ostrzeżenia
  zależności/deprecacji, 103,48 s, exit 0 (`uk-stage35-backend-final.log`).
- Skupiona partia zakupów, porównania, historii, spiżarni i jednostek:
  **220 passed**, exit 0 (`uk-stage35-targeted-final.log`).
- Nowe kontrole i komunikaty dla PL/GB: **62 passed**, exit 0
  (`uk-stage35-messages-green.log`).
- Flutter: cztery pliki testów jednostek, kontraktu produktu i widgetów limitu:
  **35 passed**, exit 0 (`uk-stage35-dart-verified.log`). Nowe dwa scenariusze
  odtwarzają odmowę dopisania przepisu na koncie Standard i powrót do listy,
  bez utraty wyboru. Sprawdzono także stare przypadki zmiany sesji i błędu
  prezentacji. Nie zmieniano produkcyjnego kodu Fluttera.
- Kontrola AST endpointów zakupów po zastąpieniu wywołań `account_text`
  ich polskim argumentem: identyczne drzewo jak przed zmianą tego pliku.
  Potwierdza zachowanie polskiej treści, zapytań, warunków i modyfikacji danych.
- Compileall zmienionych modułów/testów: exit 0. Kontrola whitespace: bez błędów.

To nie jest test aparatu, StoreKit/Google Billing ani AAB/IPA na telefonie.
Nie uruchamiano testów na produkcyjnym Neon/Renderze. Nie dodano cen ani
asortymentu. Pozostają sprawdzone rzeczywiste dane UK, dokumenty i testy
natywne przed publicznym startem. UK nadal wyłączone, wersja 1.0.69+270.
Zamrożona paczka 270 nie jest rozszerzana o późniejsze prace lokalne.
