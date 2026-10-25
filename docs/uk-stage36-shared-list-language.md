# UK — język list współdzielonych i porównania cen, 23.10.2026

Kontynuacja po [etapie 35](uk-stage35-shopping-integrity-and-copy.md).
Kopie obu modułów przed zmianą: `../backups/uk-stage36-20261023/`.
Bez nowych funkcji, redesignu, wdrożenia, operacji na Neon ani aktywacji UK.

## Odtworzenie i zmiana

Współużytkownik UK polskiej listy otrzymywał polski komunikat niepoprawnego
sklepu i odpowiedzi dodawania produktu. Polski współużytkownik brytyjskiej
listy otrzymywał angielskie komunikaty zakończonej listy lub niespójnej historii.
Starsze porównanie planu także zwracało polskie błędy kontom GB.

Te teksty wybiera teraz `account_text` na podstawie zapisanego kraju osoby
wykonującej żądanie. Rynek listy, waluta, sklep, własność i zaakceptowane
udostępnienie pozostają osobną kwestią: konto GB operujące na polskiej liście
nie przelicza jej na GBP, a polskie konto na brytyjskiej nie zmienia jej na PLN.

Uzupełniono istniejące teksty przy porównaniu, zmianie sklepu oraz dodaniu
produktu: zakończona lista, niewłaściwy rynek/sklep, niepoprawna ilość ze
spiżarni, niespójna historia opakowania, niemożliwa wycena, brak produktu i
potwierdzenia dodania/zwiększenia ilości. Nie zmieniano statusów HTTP ani
warunków walidacji. Polskie komunikaty w dawnych polskich gałęziach zachowano;
surowe angielskie komunikaty wspólnych ścieżek mają teraz również polski wariant.

## Weryfikacja

- Przed zmianą produkcyjną nowe testy HTTP odtworzyły problem: 24 nieprzechodzące
  przypadki, 20 przechodzących. Przyczyną były stałe napisy, nie utrata sesji.
- Końcowa partia zakupów i porównań: **256 passed**, exit 0, 32,73 s,
  `uk-stage36-targeted.log`.
- Nowy plik zawiera 76 przypadków: konta PL/GB, listy współdzielone,
  odrzucenie zmiany sklepu bez modyfikacji koszyka, historia zakupu/spiżarni,
  niewłaściwy rynek oraz brak planu. Cztery konfiguracje SQLite obejmują
  autoflush włączony/wyłączony i wariant bez INSERT RETURNING.
- Pozytywny scenariusz konta GB na liście PL sprawdza dodanie 600 g,
  dopisanie 100 g do tej samej pozycji, porównanie i zmianę sklepu w PLN.
  Adapter SQLite używa wspólnej sesji, więc pomiędzy żądaniami jawnie
  odświeża relację pozycji, którą w produkcji odczytuje nowa sesja żądania.
- Pełny backend: **2421 passed**, 43 ostrzeżenia zależności/deprecacji,
  114,86 s, exit 0 (`uk-stage36-backend-final.log`).
- Porównanie AST obu modułów z backupem, po usunięciu wyboru języka/importu
  i pominięciu wartości tekstowych: identyczne warunki, zapytania, arytmetyka,
  statusy, kolejność operacji i modyfikacje danych.
- Compileall i kontrola whitespace zmienionych modułów: exit 0.

Nie zmieniano Fluttera, dokumentów prawnych, danych UK ani cen. Ten etap nie
jest testem natywnego aparatu, płatności, AAB/IPA ani pełnego asortymentu.
Przed startem pozostają rzeczywiste sprawdzone mapowania/ceny i testy natywne.
Wersja pozostaje **1.0.69+270**, `UK_MARKET_ENABLED=False`.
Zamrożony ZIP 270 bez zmian, SHA-256:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
