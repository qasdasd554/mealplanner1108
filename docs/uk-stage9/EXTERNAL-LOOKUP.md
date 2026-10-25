# Etap 9 — regionalne wyszukiwanie produktów

Praca lokalna, bez aktywacji UK, wydania, zapisu w produkcyjnej bazie ani
zmiany normalnego wyglądu aplikacji. Wersja pozostaje 1.0.66+267.

## Kontrakt rynku i szybkości

- Backend bierze kraj z uwierzytelnionego konta. Parametry klienta `cc`,
  `lc` lub `country_code` nie mogą zmienić kraju konta ani wyszukiwania.
- Wyszukiwanie OFF korzysta nadal ze światowej bazy. PL przekazuje pl/pl,
  GB przekazuje uk/en. Angielska nazwa ma pierwszeństwo tylko w GB;
  marka i nazwa z fizycznej etykiety nie są tłumaczone przez OCR.
- Cache wyszukiwania tekstowego rozdziela rynek i język. Wspólny cache GTIN
  nadal przechowuje tożsamość/makro produktu, więc może zachować jego
  oryginalną nazwę. Sam GTIN nie potwierdza dostępności w sklepie UK.
- Aplikacja przekazuje do usług funkcję odczytu kraju zalogowanego konta;
  pobiera go raz na początku danej operacji. Region telefonu, język UI,
  podróż lub wybór sklepu administratora nie zastępują kraju konta.
  Brak danych konta zachowuje kompatybilny fallback PL.
- Szybkie, kompletne trafienie lokalne nie uruchamia OFF. Nie dodano
  równoległych żądań, źródeł ani kolejnych wersji API. Zachowano timeouty
  i opóźniony start USDA. Fallback v3/v2 w aplikacji pozostaje sekwencyjny,
  a odpowiedzi 404/429/503 nie wywołują ponowienia przez inną wersję API.
- OCR pozostaje świadomą akcją użytkownika, a nie częścią każdego skanu.
  Timeouty OCR i liczba zdjęć pozostają bez zmian.

## Ceny i dane żywieniowe

- Historyczne widełki są szacunkami PLN. GB nie otrzymuje ich z katalogu,
  cache, wyszukiwania nazw ani OCR. Frontend dodatkowo ukrywa takie widełki
  od starszego serwera; nie dodaje symbolu GBP do polskiej liczby.
- Kanoniczne pola OFF `_100g` są podstawą makro. Surowe pola etykiety
  wolno czytać jako wartości na 100 tylko przy jawnej podstawie 100 g/ml.
  Nieznana podstawa lub wartości na porcję pozostają brakujące, bez
  automatycznego przypisywania ich do 100 g i bez fałszywych zer.
- Rozmiar całego opakowania i jego jednostka są przejmowane razem.
  Przykład regresji: lokalne domyślne g bez wielkości + zewnętrzne 500 ml
  nie może dać 500 g. Prawidłowe znane lokalne opakowanie jest zachowane.
- Obsługiwane są jawne jednostki metryczne i ich istniejące przeliczniki.
  `12 oz` nie staje się 12 g; jawne `12 fl oz (355 ml)` pozwala odczytać
  355 ml. Porcja z tabeli nie zastępuje wielkości całego opakowania.
- Nie dodano domyślnej gęstości ani przeliczania nieznanych jednostek.
  Nieprawidłowa jawna podstawa OCR usuwa niepewne liczby i wymaga korekty.
  Historyczny brak pola jednostki OCR zachowuje wcześniejszy kontrakt g;
  brak wiarygodnej gramatury nie daje opcji dodania całego opakowania.
- Gramatura musi być skończona, dodatnia i nie większa niż 100 000 g/ml,
  również po konwersji. Tekstowe `-10 g`, `−10 g`, dwa ujemne czynniki
  i fragment `309 g` wewnątrz `1e309 g` nie tworzą dodatniego opakowania.
  Gdy liczba z metadanych jest odrzucona, prawidłowy metryczny tekst może
  uzupełnić opakowanie, ale zawsze wraz z własną jednostką, nie poprzednią.
- W aplikacji OFF dokumentuje `product_quantity` jako znormalizowane g/ml.
  Przy brakującej jednostce wykorzystujemy tylko jawny metryczny wymiar,
  nie mnożymy już znormalizowanej liczby po raz drugi przez kg/l z etykiety.
  Backend może konserwatywnie pozostawić taki rozmiar nieznany.

## Testy i granice dowodów

Nowe testy znajdują się w:

- `backend/tests/test_external_lookup_market.py`
- `frontend/test/services/barcode_market_lookup_test.dart`
- `frontend/test/services/lookup_market_context_test.dart`

Obejmują kraj konta kontra region/język urządzenia, próby podmiany kraju
przez HTTP, cache PL/GB, kompletne trafienia bez zewnętrznych żądań,
liczbę i parametry fallbacków, priorytet nazw, ukrywanie PLN, podstawę makro,
jednostki/rozmiary opakowań oraz zachowanie ID/marki/makro podczas wzbogacania.
Dla odtworzonych błędów wykonano przebiegi czerwony → poprawka → zielony.
Nowe pliki zawierają 94 przypadki backendu i 40 przypadków Fluttera.

Nie testowano rzeczywistego OFF/AI, fizycznej kamery, czasu odpowiedzi sieci,
produkcyjnych rekordów, DDL Neon ani natywnego AAB/IPA. Nie zmieniano motywu,
billingu, projektów Android/iOS, SQL, flagi UK ani wersji. Nie jest to import
pełnego katalogu UK ani potwierdzenie asortymentu brytyjskich sklepów.
Końcowe wyniki wszystkich testów zapisujemy w `../UK-EXPANSION.md`.

## Źródła pierwotne

- [Schemat produktu OFF: rozmiar, jednostki i nazwy](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product/)
- [Parametry produktu API v3](https://openfoodfacts.github.io/documentation/docs/Product-Opener/v3/products/get-api-v3-product-code/)
- [Taksonomia krajów OFF, mapowanie GB → UK](https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/main/taxonomies/countries.txt)

Źródła opisują kontrakt zewnętrznej bazy; nie dowodzą kompletności lub
poprawności każdej etykiety. Dane testowe są syntetyczne.
