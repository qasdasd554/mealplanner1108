# OFF dla Wielkiej Brytanii — 21.10.2026

## Fakty a oferta sklepu

Światowa baza Open Food Facts obejmuje UK. Bezpośrednie zapytanie API
z filtrem `countries_tags_en=united-kingdom` zwróciło 197 118 rekordów.
To liczba rekordów oznaczonych krajem, nie liczba kompletnych etykiet,
produktów w każdym sklepie ani potwierdzonych aktualnych cen.

Jedno zapytanie próbki 30 rekordów zwróciło HTTP 503. Późniejsza mniejsza
próbka 3 rekordów przeszła parser: wszystkie trzy miały poprawny GTIN,
makro na 100 g/ml, gramaturę i zgłoszoną nazwę sklepu. Nie jest to pomiar
jakości całej bazy. Skrypt: `backend/scripts/check_off_catalogue.py`.

## Wprowadzone lokalnie

- Osobna tabela `off_catalogue_products`: wyłącznie publiczne dane OFF,
  źródłowy URL, licencja ODbL-1.0, rewizja, data pobrania i fingerprint.
  Brak użytkowników, cen, walut i relacji do sklepowych ofert aplikacji.
- Import w paczkach do 500 rekordów. Powtórzenie jest idempotentne;
  starsza rewizja lub sprzeczna zawartość tej samej rewizji nie zastępuje
  nowszej informacji. Wywołujący kontroluje transakcję.
- Import odrzuca błędne kody, kraj bez UK, wycofane produkty i nieprawidłowe
  metadane. Nie dopisuje zastępczego 100 g ani zera zamiast brakującego makro.
  Używa istniejącego parsera makro/gramatury, bez przeliczania porcji na
  opakowanie i bez kopiowania `nutriments_estimated`.
- Wyszukiwanie po nazwie dla konta GB najpierw sprawdza również ten cache.
  Rekord starszy niż 30 dni nie blokuje odświeżenia. Znaki `%` i `_` są
  traktowane dosłownie. Zachowano limit wyników i jedno żądanie do OFF;
  nie dodano AI ani kolejnych równoległych dostawców.
- Żywe wyszukiwanie po nazwie ma dodatkowy filtr kraju UK. Kod kreskowy
  nadal korzysta ze światowej bazy, aby rozpoznawać także importowane produkty.
- Zapis odpowiedzi OFF następuje w zadaniu po odpowiedzi HTTP. Nie
  nadpisuje produktów użytkowników ani polskiego katalogu.
- Wynik zewnętrzny nie otrzymuje fałszywego `existing_product_id`.
  Dotychczasowa ścieżka świadomego wyboru tworzy potrzebny składnik prywatnego
  przepisu; cache sam tego nie robi i nie przyznaje punktów.

## Czego NIE wykonano

Nie skopiowano wszystkich 197 tys. produktów do Neon i nie twierdzimy,
że są już widoczne na głównej liście katalogu aplikacji. Wprowadzony jest
mechanizm wyszukiwania i cache, nie pełne zasilenie katalogu przeglądanego
bez wpisania nazwy. Przed masowym importem potrzebny jest eksport kraju,
kontrola pojemności/kosztu, wydajności wyszukiwania oraz ścieżek wyboru
produktu bez identyfikatora z tabeli `products`.

`reported_stores` to tekst społeczności OFF. Nie tworzy `StoreProduct`,
`RegionalProductOffer`, krajowej dostępności, ceny ani mapowania składnika
przepisu do lokalnego SKU. Filtr publicznych przepisów UK nie został
poluzowany: brak sprawdzonego mapowania nadal ukrywa danie.

Nie włączono UK, nie wdrożono kodu i nie zmieniono wersji 1.0.66+267.
Na odizolowanej gałęzi Neon wykonano test i wycofano całą transakcję,
włącznie z nową tabelą. Żadnych produkcyjnych zapisów.

## Źródła i licencja

- [API i ograniczenia](https://openfoodfacts.github.io/openfoodfacts-server/api/)
- [Cache OFF](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/creating-a-local-cache-of-open-food-facts-data/)
- [Licencje danych i obrazów](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/)
- [Osobny projekt cen](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/product-prices/)
- [Eksport kraju](https://support.openfoodfacts.org/help/fr-fr/12-donnees-api/89-je-souhaite-un-export-csv-pour-un-pays-une-marque-en-particulier)

Dane pochodzą od Open Food Facts contributors. ODbL wymaga atrybucji
i spełnienia zasad udostępniania odpowiedniej bazy pochodnej. Samo
oddzielenie tabel nie jest automatycznym dowodem zgodności licencyjnej;
przed publikacją trzeba sprawdzić atrybucję, eksport i warunki połączenia
z pozostałymi źródłami. Nowy cache nie zawiera e-maili, prywatnych przepisów
ani innych danych kont i nie zapisuje w OFF zmian bez decyzji użytkownika.
