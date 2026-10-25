# Koszt brytyjskich opakowań — fundament etapu 3

Opis historyczny stanu po etapie 3. Podłączenie GB do planu/listy/porównania
wykonano następnie w etapie 4; aktualny zakres i ograniczenia opisuje
`../UK-EXPANSION.md` oraz katalog `../uk-stage4/`.

`regional_offer_pricing.py` jest czystą funkcją bez sieci i zapisów. Cel:
wycenić rzeczywistą lokalną paczkę, zamiast podmienić PLN na GBP przy
zachowaniu gramatury polskiego produktu.

- g/kg normalizują się dokładnie do g; ml/l do ml. Nie ma domyślnej
  gramatury, zamiany g na ml, ani przelicznika sztuki/szklanki z nazwy.
  Te miary wymagają wcześniej jawnego, właściwego dla produktu przeliczenia.
- Ilości wejściowe muszą być Decimal/ciągiem dziesiętnym lub int, nie float,
  bool, NaN czy Infinity. To zapobiega np. zakupowi trzeciej paczki przez
  błąd binarnego zaokrąglenia 1000.0000000000001.
- Wycena bierze konkretny produkt i sklep. Odtwarza pełną walidowaną
  propozycję z danych zapisanej oferty, sprawdza UUID, fingerprint, trzy
  źródła i datę przeglądu. Nie ufa samej obecności ID lub symbolu £.
- Oferta musi mieć stan available_online i zgodny wymiar g/ml. Wyczerpane,
  nieznane, zmienione lub przeterminowane dane nie tworzą wyceny. Polityka
  świeżości jest jawna, domyślnie 30 dni, a nie zapewnienie aktualnej ceny.
- Dla każdej rozważanej paczki liczone jest ceil(potrzebna ilość/gramatura).
  Iloraz liczony jest na dokładnych stosunkach liczb całkowitych, a zamiana
  kg/l przesuwa wykładnik Decimal bez zaokrąglenia. Dodatkowa kontrola wykryła
  i naprawiła przypadek, w którym precyzja dzielenia mogła zgubić maleńką
  resztę ponad pełną paczkę; trzy regresje najpierw odtworzyły błąd.
  Wybierana jest najniższa cena wystarczającej liczby całych paczek jednego
  SKU, z deterministycznym remisem. Nie jest to optymalizacja mieszanek
  rozmiarów, ofert lojalnościowych ani promocji wielosztukowych.
- Wynik zachowuje ID SKU, gramaturę, potrzebną i kupowaną ilość, liczbę
  paczek, cenę za paczkę, sumę GBP i źródło ceny. estimate nie staje się
  ceną potwierdzoną tylko dlatego, że źródło ma datę.
- Brak poprawnej oferty to None/brak wyceny, nigdy udawane £0. Fizyczna
  dostępność w każdej placówce nie jest wywodzona z karty online.

Przykłady w testach są syntetyczne. Pokrywają m.in. paczkę 1136 ml,
różne lokalne rozmiary, 500.001 g wymagające dwóch paczek po 500 g,
granice źródeł/daty, ilości o większej precyzji niż kontekst Decimal oraz
brak mutowania produktu kanonicznego. Sam moduł wyceny ma 64 testy. Integracja
importer→commit→ponowny odczyt ORM→wycena sprawdza również JSON/fingerprint
po rzeczywistym lokalnym zapisie do SQLite.

## Co nadal nie jest podłączone

Wycena nie zastępuje jeszcze kosztu planu/listy/porównania w API. Potrzebny
jest jeden spójny następny etap: wybrane SKU i snapshot użytego opakowania
na liście zakupów, regeneracja/scalanie/zmiana sklepu, koszt generatora
i filtr dostępności oparty na regionalnych ofertach. Nie wolno uruchomić
jednego odbiorcy GBP i zostawić drugiego na polskim default_quantity.

Nowa tabela została zarejestrowana w istniejącym metadata.create_all;
przy przyszłym wdrożeniu utworzy pustą tabelę, bez modyfikowania Product
i StoreProduct. Nie wykonano tego na Neon. Zgodnie ze skillem Neon/Postgres
przed wdrożeniem należy przetestować DDL na izolowanej gałęzi przez direct.
SQLite/kompilacja SQL nie potwierdzają wykonania na realnym PostgreSQL.

UK pozostaje wyłączone. Nie ma aktywnego asortymentu produkcyjnego,
automatycznego importu źródeł ani nowego endpointu przyjmującego dane cen.
