# UK — wpięcie obserwacji cen do zakupów, 23.10.2026

Kontynuacja [etapu 38](uk-stage38-open-prices-references.md).
Wersja lokalna nadal **1.0.69+270**, UK wyłączone. Bez push/deploy,
nowego ZIP-a ani importu danych na produkcji. Backup plików przed zmianami:
`../backups/uk-stage39-20261023/`.

## Co rzeczywiście zmienia ten etap

Dotychczas walidator Open Prices przygotowywał tylko oddzielną referencję.
Teraz jawnie sprawdzona referencja może przejść przez istniejący importer,
regionalny katalog, wycenę planu/listy, porównanie i zmianę sklepu oraz
zamrożoną historię zakupu. Nie dodano nowego ekranu ani funkcji użytkownika.
Nie zmieniono polskiej gałęzi wyceny ani wyglądu aplikacji.

- Nowy typ pochodzenia `OpenPricesEvidence` zachowuje ID obserwacji/dowodu,
  publiczny link, GTIN, fingerprint OFF, datę obserwacji i licencję ODbL.
- Obserwacja ma zakres `store_observation`, status `reported_available`
  oraz zawsze cenę **orientacyjną**. Nie jest ofertą internetową sklepu,
  potwierdzeniem bieżącej ceny ani gwarancją stanu półki całej sieci.
- Przejście wymaga osobnej kontroli podstawy ilości `as_sold`, z uzasadnieniem.
  Nie zgaduje się masy po odsączeniu, gęstości ani przeliczenia g na ml.
- Importer ponownie sprawdza w bazie aktualne, zatwierdzone powiązanie
  składnika z dokładnym rekordem OFF, jego fingerprint, tożsamość, kraj,
  wymiar i gramaturę. Sam podobny napis lub przekazane ID nie wystarcza.
  Błędny lub zmieniony rekord odrzuca całą partię przed zapisem.
- Źródłowy klucz `off-<GTIN>` jest jawnie kluczem zewnętrznym, nie
  wymyślonym SKU detalisty. Marka, makro i domyślne polskie opakowanie
  produktu kanonicznego nie są nadpisywane danymi brytyjskiego SKU.
- Ponowne sprawdzenie nie odmładza ceny. Nieaktualne obserwacje nie
  wyceniają nowych zakupów. Brak danych daje cenę nieznaną, nie 0 GBP.
- Kupione opakowania zachowują pierwotny sklep, ilość, cenę i źródło
  po zmianie sklepu, usunięciu oferty i zakończeniu listy. Ponowne
  zakończenie listy nie dodaje drugi raz produktów do spiżarni.
- Model Fluttera rozpoznaje takie opakowanie tylko jako oznaczoną
  orientacyjną cenę GBP. Nieznany zakres, PLN lub brak oznaczenia
  orientacyjnego nie przechodzą jako brytyjskie opakowanie.

## Schemat bazy i próba Neon

Nie dodano tabel ani kolumn; rozszerzono dwie istniejące reguły CHECK
i dodano regułę spójności rodzaju dowodu. Idempotentny krok schematu
jest częścią istniejącej transakcji startowej backendu. Nie przepisuje
cen, produktów ani kont. Stary format źródeł ofert pozostaje obsługiwany.

`backend/scripts/check_uk_branch.py` odtwarza stare ograniczenia wewnątrz
transakcji na wskazanej, odizolowanej gałęzi Neon, uruchamia zmianę dwukrotnie
i testuje rzeczywisty zapis/odczyt przez asyncpg. Przypadek referencyjny:
600 g passaty wymaga 2 opakowań po 500 g, czyli 1000 g i 0,90 GBP,
na podstawie obserwacji z 27.09.2026. To utrwalona próbka testowa,
nie obietnica aktualnej ceny w sklepie.

Próba 23.10.2026: **passed=true**, upgrade starszego schematu i idempotencja,
zapis ceny społecznościowej, niezmienność istniejących polskich rekordów
oraz pełny rollback potwierdzone. Nie uruchamiano lifespan aplikacji,
workerów, AI, poczty ani migracji na produkcji. Raport nie wypisuje DSN,
haseł ani danych użytkowników.

## Weryfikacja kodu

- Nowa partia integracyjna: **24 passed**, w tym oba tryby autoflush,
  odrzucenie brakującego/zmienionego OFF i cała ścieżka listy/sklepu/spiżarni.
- Pełny backend: **2527 passed**, 43 ostrzeżenia zależności/deprecacji,
  exit 0, 175,88 s (`uk-stage39-backend-final.log`).
- Pełny Flutter: **1081 passed**, exit 0, 2:02
  (`uk-stage39-flutter-final.log`). Nowe testy modelu: 2 passed.
- Analiza zmienionego modelu i nowego testu Dart: **No issues found**, exit 0.
- Pełne `flutter analyze --no-pub --no-fatal-infos`: exit 0,
  **0 błędów, 0 ostrzeżeń**, 388 informacji/lintów
  (`uk-stage39-analyze.log`). Compileall zmienionej ścieżki: exit 0.
- Bezpośrednia kontrola 17 plików: UTF-8/LF bez BOM i końcowych spacji;
  kontrola zgodności wersji backend/frontend: 1.0.69, exit 0.
- To nie jest dowód natywnego buildu lub działania aparatu/zakupów na telefonie.

## Co jeszcze pozostaje do publicznego startu UK

1. Podłączyć pobieranie/odświeżanie tych małych danych na żądanie do gotowej
   ścieżki, z ograniczeniami czasu, cache i bez pełnego dumpa OFF.
   Szersze mapowania muszą zachować różnice składników; sześć przykładów
   OFF i trzy obserwacje cen nie pokrywają katalogu i dziesięciu sieci.
2. Uzupełnić rzeczywiste pokrycie dostępności składników UK i cen
   orientacyjnych. Brak ceny nie może być maskowany sztuczną wartością;
   brak potwierdzonego składnika nadal wyklucza publiczny przepis UK.
3. Domknąć przegląd dokumentów, pozostałych komunikatów usług natywnych
   i wymaganej atrybucji/licencji danych w wydaniu.
4. Wykonać natywne buildy i testy na Androidzie/iOS: nowe konto GB i stare
   konto PL, aparat, udostępnianie, powrót z tła oraz zakupy/trial
   w środowiskach testowych sklepów. Nie ma tu SDK/emulatora ani Xcode.
5. Skonfigurować dostępność i produkty/oferty UK w Google Play i App Store,
   a potem przygotować wydanie z aktualnej kopii Codespace. UK włączyć
   dopiero po przejściu bramki danych i testów; nie jest teraz włączane.

Zamrożony ZIP 270 pozostaje bez zmian, SHA-256:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
