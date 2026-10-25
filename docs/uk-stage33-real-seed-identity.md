# UK — rzeczywiste tożsamości składników, 23.10.2026

Późniejszą korektę prezentacji przykładowych marek/opakowań opisuje
[etap 34](uk-stage34-product-presentation.md). Poniżej historyczny stan etapu 33.

Prace lokalne po paczce 1.0.69+270. Nie wykonano wdrożenia, zmiany wersji,
zakupu usług ani aktywacji UK. Nie zmieniano ekranów, funkcji ani zasad Premium.

## Odtworzona przyczyna

Etap 32 testował głównie niebrandowane produkty syntetyczne. Rzeczywisty
systemowy katalog ma przykładowe polskie marki również przy składnikach
ogólnych: „Płatki owsiane” mają markę Sante. Zakaz każdej marki blokował
zatwierdzenie dostępności takiego składnika w UK. Nowy test z rzeczywistym
ID składnika i publicznym rekordem OFF nie przeszedł w obu trybach autoflush.

Naprawa dopuszcza wyjątek wyłącznie dla znanej, niezmienionej tożsamości
składnika systemowego (ID oraz oryginalna nazwa z istniejącego indeksu).
Nadal wymagane są zatwierdzenie, brak autora i brak przypisanego GTIN.
Dowolny markowy produkt o podobnej nazwie nie korzysta z tego wyjątku.

Przegląd zapisuje także markę składnika. Zmiana marki po zatwierdzeniu
unieważnia powiązanie tak samo jak zmiana nazwy lub jednostki. Odpowiednie
porównanie działa zarówno dla NULL, jak i niepustej marki na SQLite/PostgreSQL.
Tabela mapowań z etapu 32 nie była wdrażana; nowa kolumna jest częścią
niewydanej, addytywnej tabeli, a nie operacją zmieniającą produkty PL.

## Publiczny przykład

Test korzysta z [rekordu OFF Organic Jumbo Oats](https://world.openfoodfacts.org/product/5099801003339)
sprawdzonego 23.10.2026: Flahavan's, 1 kg, zgłoszona sprzedaż w UK.
Wybrane publiczne fakty, źródło i atrybucja ODbL-1.0 są w
`backend/tests/fixtures/off_uk_oats_20261023.json`.
To próbka do odtwarzalnego testu offline, nie automatyczny seed produkcyjny.

Po powiązaniu produkt kanoniczny zachowuje polską markę, własną gramaturę
i wartości odżywcze. Przykładowe 1000 g / 370 kcal z OFF nie nadpisuje jego
500 g / 389 kcal. Powiązanie dotyczy wyłącznie zgłoszonej sprzedaży rodzaju
składnika w kraju — nie sprzedaży polskiej marki, konkretnego SKU ani ceny.

## Weryfikacja

- Partia testów tożsamości, powiązań, filtrowania, etykiet i danych AI:
  **183 passed**, dwa ostrzeżenia deprecacji zależności.
- Wszystkie 150 znanych tożsamości składników przechodzi rozpoznanie bez
  zgadywania po nazwie. Losowy ID, zmieniona nazwa, autor, kod, niezatwierdzony
  status lub niezgodna marka przeglądu są odrzucane.
- Zmiana marki po przeglądzie ukrywa składnik w obu zapytaniach UK, nie w PL.
- Test na udostępnionej, odizolowanej gałęzi Neon potwierdził import i ponowienie
  powiązania z rzeczywistym istniejącym składnikiem oraz publicznym rekordem
  OFF: `real_seed_public_off_mapping_pg: true`. Nie uruchamia aplikacji,
  poczty ani AI. Końcowy rollback potwierdza brak pozostawionych tabel/danych.
- Pierwsze zbyt szerokie wywołanie `pytest -q` zebrało dodatkowo dwa stare
  ręczne skrypty z katalogu backendu (`test_generate.py`, `test_seed.py`).
  Nie wykonały ich funkcji async i zakończyło się to dwoma błędami uruchamiania,
  przy 2256 przechodzących testach właściwej aplikacji. Skrypty korzystają
  z prawdziwej konfiguracji bazy, a jeden wykonuje commit seedowania — nie są
  bezpiecznymi automatycznymi testami. `pytest.ini` wskazuje teraz `tests`,
  bez zmiany tych skryptów, pomijania testów aplikacji ani operacji na bazie.

Końcowa weryfikacja całego `backend/tests`: **2256 passed, 43 ostrzeżenia,
146,04 s, exit 0**, log `uk-stage33-backend-final.log`.
Domyślna kolekcja po zmianie konfiguracji: **2256 tests collected**, exit 0,
bez ręcznych skryptów seedowania/generowania (`uk-stage33-collection.log`).
Końcowy test Neon po ostatniej zmianie skryptu: `passed: true`,
`real_seed_public_off_mapping_pg: true`, `existing_pl_rows_unchanged: true`,
`rollback_verified: true`, exit 0 (`uk-stage33-neon-final.log`).
Compileall zmienionych modułów: exit 0. Kontrola whitespace: bez błędów.
Nie wykonywano buildu AAB/IPA ani testów na rzeczywistych telefonach.

Paczka 270 pozostała niezmieniona, ponownie potwierdzony SHA-256:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
Ten etap nie znajduje się w przekazanej wcześniej paczce.

## Co nadal ogranicza uruchomienie UK

Nie dodano fikcyjnych produktów, cen ani kodów. OFF działa globalnie, ale
jego wskazanie kraju nie jest cennikiem ani pełnym asortymentem dziesięciu
sieci. Przejrzane aktualne obserwacje Open Prices nie zapewniają takiego
pokrycia; sam filtr GBP może zawierać również produkty niespożywcze.
Nie należy przedstawiać obserwacji społecznościowej jako bieżącej oferty
internetowej sklepu ani omijać walidacji pochodzenia danych.

Przed publicznym uruchomieniem pozostały rzeczywiste sprawdzone powiązania,
źródła orientacyjnych cen GBP i kontrola prezentacji polskich przykładowych
marek przy ogólnych składnikach UK (bez usuwania ich z polskich rekordów).
Pozostają też dokumenty i testy natywne aparatu, udostępniania oraz zakupów.
Ten etap nie potwierdza kompletności katalogu ani gotowości publikacji UK.

Kopie plików zmienianych w tym etapie: `../backups/uk-stage33-20261023/`.
Nie cofać całego drzewa do HEAD: zawiera wcześniejsze prace i poprawki PL.
