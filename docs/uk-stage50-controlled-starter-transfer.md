# UK — kontrolowane przekazanie zestawu startowego

24.10.2026. Wyłącznie prace lokalne i transakcja wycofana w udostępnionej
gałęzi testowej Neon. Bez wdrożenia, aktywacji UK, zmiany wersji 270 ani ZIP-a.
Backup wcześniejszego checkera i głównej checklisty: `../backups/uk-stage50-20261024/`.

## Zamknięta luka operacyjna

Przygotowane powiązania OFF istniały dotychczas w plikach testowych. Start
serwera dodaje sklepy, ale nie importuje tych powiązań. W dodatku obraz Docker
celowo nie zawiera testów. Samo wdrożenie kodu nie dawało więc zestawu
startowego UK i nie było jednego kontrolowanego polecenia jego przekazania.

Nowy `backend/scripts/import_uk_starter.py` używa tego samego importera,
który został sprawdzony na SQLite i w rzeczywistym PostgreSQL. Publiczny
pakiet źródłowy jest w `backend/app/data/uk_starter_20261024.json`, niezależnie
od kodu testów. Jest to 31 konkretnie przejrzanych pojęć składników, nie dump
OFF, katalog wszystkich sieci ani deklaracja dostępności wszystkich przepisów.

- Domyślnie pełna próba importu kończy się rollbackiem.
- Trwały zapis wymaga jednocześnie `--apply`, dokładnego odcisku pakietu,
  wskazanego pliku środowiska, zgodnego hosta bez poolera oraz UUID istniejącego
  administratora. Uprawnienia i blokada konta są odczytywane ponownie z bazy.
- Żadnego tworzenia sztucznego administratora, migracji, startu aplikacji,
  maili, AI, zewnętrznego wyszukiwania ani uruchamiania zadań cyklicznych.
- Cała partia jest atomowa. Błąd ostatniego składnika lub zapisu SQL wycofuje
  także wcześniej zapisane fakty OFF. Sesja z niezapisanymi cudzymi zmianami
  jest odrzucana przed niejawnym flush.
- Odciski obejmują treść JSON, a nie końce linii. CRLF/BOM i formatowanie
  pliku nie udają zmiany produktu; zmiana danych, daty lub notatki przeglądu
  wymaga nowego przejrzanego manifestu.
- Nie nadpisuje nazw, marek, makro, opakowań, jednostek ani autorów produktów
  PL. Zastana reprezentacja składnika systemowego jest zapisana w powiązaniu;
  np. `opak` z jawną jednostką bazową g nie staje się opakowaniem z OFF.
- OFF zachowuje pierwotny czas pobrania i źródło ODbL-1.0. Nowy przegląd nie
  odnawia starego odczytu. Przyszłe/przeterminowane dane i zmieniony odcisk
  już obecnego cache zatrzymują import zamiast automatycznej ponownej akceptacji.
- Nie tworzy ofert, cen, SKU ani mas sztuki. 6 jaj nie oznacza 6 g;
  zmienny rozmiar 300/350 g nie jest stałym opakowaniem 350 g.

## Procedura na osobny etap wydania — NIE została wykonana na produkcji

Najpierw backup/gałąź testowa, aktualny schemat UK i zwykłe istniejące
produkty systemowe. Narzędzie nie naprawia schematu ani nie dodaje brakujących
polskich produktów. Uruchamiać z katalogu `backend`, z jego zależnościami.

1. Obejrzeć publiczny pakiet i daty bez łączenia z bazą:

   ```bash
   PYTHONPATH=. python scripts/import_uk_starter.py --describe
   ```

   Dla tej rewizji: 31 produktów, 31 powiązań, odcisk
   `1e9c40382cfedc15600abfbc5cc62d0ba21f60e78487dc3f9e65ecd1141f822d`.
   Fakty pobrano 23–24.10.2026, nie w dniu późniejszego importu.

2. Wykonać próbę na osobnej gałęzi, podając jej dokładny bezpośredni host
   i istniejącego administratora (wartości zastępcze poniżej):

   ```bash
   PYTHONPATH=. python scripts/import_uk_starter.py \
     --env-file PRIVATE_ENV_FILE \
     --expected-host EXACT_DIRECT_HOST \
     --reviewer-id EXISTING_ADMIN_UUID
   ```

   Oczekiwany tryb to `rolled_back`, `available_count: 31`. Raport zawiera
   tylko liczniki i odcisk, bez DSN, haseł lub danych użytkowników.

3. Dopiero w uzgodnionym wydaniu, po sprawdzeniu docelowego hosta i danych,
   jawny zapis to to samo polecenie z `--apply --confirm-dataset ODCISK`.
   Nie dodawać tych flag do startu serwera ani instalatora w ciemno.
   Ten etap nie upoważnia do wykonania tego polecenia na produkcji.

Jeśli pakiet się przeterminuje (maksymalnie 30 dni), trzeba pobrać i przejrzeć
aktualne źródło. Nie zmieniać samych dat, odcisków czy wyłączać kontroli.
Ograniczony refresh już użytego kodu pozostaje osobną istniejącą ścieżką;
nowe/zmienione powiązanie pojęcia nie jest automatycznie zatwierdzane.

## Próba PostgreSQL

`check_uk_branch.py` użył nowej ścieżki dla wszystkich 31 rzeczywistych
produktów systemowych w udostępnionej kopii Neon, dwa razy w jednej
transakcji. Wynik: `controlled_starter_import_pg: true`,
`reviewed_staple_count_pg: 31`, `rollback_verified: true`.
Przed i po porównano hashe wierszy oraz zestaw tabel. Zachowane liczniki:
1265 użytkowników, 739 produktów, 2739 pozycji sklepowych, 293 przepisy,
1899 składników. Niczego trwale nie zapisano ani nie odczytywano danych
osobowych w raporcie.

## Wyniki testów

- Nowy importer i jego CLI: **49 passed**. Przed implementacją test nie
  przechodził z powodu braku nowej ścieżki. Obejmuje dwa ustawienia autoflush,
  rzeczywiste transakcje SQLite, rollback domyślny i osobno potwierdzony commit.
- Celowane testy importerów, cache, powiązań oraz ONS: **217 passed** przed
  dodaniem ostatnich dwóch regresji importera. Tych wyników nie sumujemy,
  ponieważ częściowo obejmują te same testy.
- Cały backend po partii: **3080 passed**, 43 istniejące ostrzeżenia,
  exit 0, 233,67 s (`uk-stage50-backend-final.log`).
- Compileall, zgodność wersji 1.0.69 i kontrola UTF-8/LF bez BOM/końcowych
  spacji siedmiu plików przeszły. Flutter nie był zmieniany w tej partii.
- Odcisk zamrożonej paczki nadal:
  `ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.

## Granice zakończenia

Zestaw startowy jest przekazywalny i przetestowany, ale nie aktywny na
produkcji. Nie jest warunkiem startu ręczne przejrzenie wszystkich SKU.
Nadal wymagane są aktualne źródła przed wydaniem, publikacja angielskich
dokumentów, konfiguracja sklepów oraz testy usług natywnych na urządzeniach.
Nie twierdzimy, że wykonano build AAB/IPA, płatność lub dostarczenie push.
