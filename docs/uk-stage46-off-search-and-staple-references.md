# UK — działające wyszukiwanie OFF i dwie partie składników, 24.10.2026

Prace lokalne po etapie 45. Backup sześciu istniejących plików:
`../backups/uk-stage46-20261024/`. Bez nowych funkcji użytkownika, redesignu,
wdrożenia, podbicia wersji, aktywacji UK ani zakupu usług.

## Przyczyna i zmiana istniejącego wyszukiwania

Starsze wyszukiwanie OFF `/cgi/search.pl` wielokrotnie zwracało 503.
Znaleziono działający, oficjalny interfejs tego samego OFF:
[Search-a-licious API](https://openfoodfacts.github.io/search-a-licious/users/ref-openapi/).
Jego produkcyjny adres jest wskazany w
[repozytorium OFF](https://github.com/openfoodfacts/search-a-licious).
Nie podłączono nieznanej bazy, nie pobrano pełnego dumpu ani danych obrazów.

Tylko istniejące wyszukiwanie nazw dla GB korzysta teraz z tego interfejsu.
PL zachowuje dotychczasowy transport i jego budżet. Kolejność lokalnego
katalogu/Neon, reguły tożsamości składnika i zapis użytego produktu pozostają.
Wyniki angielskie mają sprawdzony kod GTIN, jawne oznaczenie sprzedaży UK
i brak oznaczenia wycofania. Sama nazwa podobna do składnika nie jest
automatycznym wyborem produktu ani dowodem sprzedaży w danym sklepie.

Odtworzono również zachowanie serwera wyszukiwania: pełny tekst w nawiasach
lub jako niezwiązana z polem fraza zwracał zero wyników bez błędu HTTP.
Użyto dokumentowanej postaci `stałe_pole:"wartość" zwykły tekst`, ze
stałym filtrem UK. Składnia wpisana przez użytkownika jest usuwana,
a kraj każdego wyniku jest niezależnie sprawdzany także po odpowiedzi.

## Szybkość i poprawność danych

- Jedno wyszukiwanie, bez dodatkowej kolejki/ponawiania starego API:
  maksymalnie 2 s, 20 wyników, odpowiedź do 1 MB.
- Po dopasowaniu konkretnego brakującego składnika przepisu najwyżej jeden
  pełny odczyt jego GTIN, do 1,5 s. Całość mieści się w dotychczasowym
  czterosekundowym budżecie pojedynczego składnika. Przy awarii nadal działa
  wcześniejszy zapis składnika z oznaczeniem braków/oszacowania.
- Maksymalnie trzy żądania jednocześnie i sześć na minutę na proces dla
  każdego rodzaju odczytu. 429/503 powoduje przerwę co najmniej 300 s;
  dłuższe `Retry-After` jest respektowane w ograniczonym zakresie.
  To nie jest globalny limit wielu instancji Render ani całej ścieżki skanera.
- Cache wyszukiwania nadal ma limit 200 wpisów i 5 minut dla wyników;
  pusty wynik GB ma 30 s. Nie uruchamiano workera ani nowej usługi.
- Projekcja indeksu może być niepełna lub opóźniona. Jej znacznik
  `off_search_projection` nie pozwala przedstawić jej jako pełnego rekordu
  z dzisiejszym czasem pobrania. Do przepisu, makro i dowodu kraju trafia
  dopiero sprawdzony pełny rekord tego samego kodu i tej samej nazwy.
- Nie zmieniano cen na GBP przez zamianę symbolu waluty, nie dopisywano
  masy porcji jako masy opakowania i nie mieszano danych dwóch SKU.
  Następne użycie zapisanego składnika korzysta z Neon bez nowego HTTP.

Jedna rzeczywista próba marchewki: wyszukanie 0,52 s, osobny pełny odczyt
wybranego GTIN 0,45 s. To pojedyncze odczyty tego środowiska, nie benchmark
telefonu, gwarancja opóźnienia ani porównanie obciążonych usług.

## Dwie sprawdzone partie publicznych danych

Zachowano pełne odpowiedzi wybranych kodów, prawdziwe czasy pobrania,
fingerprinty, ODbL i jawny zakres powiązania. Pliki:

- `backend/tests/fixtures/off_uk_staples_20261024.json`: cebula, marchew,
  ziemniaki, mąka pszenna, płatki owsiane, jajka, cukier, pieprz i sól.
- `backend/tests/fixtures/off_uk_priority_staples_20261024.json`: oliwa,
  pomidory, czosnek, biały chleb pszenny, awokado, penne, cytryna,
  sałata lodowa i banan.

To 18 powiązań pojęć żywnościowych, nie 18 podmienionych polskich produktów.
Nie przenoszą marki, opakowania, makro ani ceny UK na wspólny produkt PL.
Przykładowo „6 jaj” nie staje się 6 g; nieznana masa cebuli pozostaje
nieznana. Informacja o soi na konkretnym chlebie nie jest twierdzeniem,
że każdy chleb generyczny ją zawiera lub jest od niej wolny. Powiązanie
kraju nie rekomenduje tego SKU osobie z alergią ani nie tworzy oferty sklepu.

Trzy pozostałe rekordy z próby wykluczono:

- kurczak ma sprzeczne kategorie surowy/gotowany;
- olej rzepakowy nie potwierdza zgodnego wymiaru objętości;
- gotowy płynny bulion nie jest automatycznie zamiennikiem wpisu
  ze starym przeliczeniem na sztuki/kostki.

Oba pliki mają `automatic_import=false` i nie są ładowane przy starcie.
Udane sprawdzenie importera nie oznacza, że użytkownicy produkcji już
otrzymali te dane. Import wymaga aktualnego uprawnionego administratora,
zgodnej tożsamości produktu i nadal aktualnych faktów OFF.

Łącznie z sześcioma wcześniejszymi powiązaniami pakiety obejmują 24 pojęcia.
Statyczne porównanie samych wymaganych składników obejmuje w całości 13
z 137 wbudowanych przepisów. To **nie jest** liczba aktywnych przepisów UK:
pakiety nie są jeszcze danymi produkcyjnymi, a ceny mają oddzielne wymagania.
Priorytet dalszych danych to m.in. właściwy bulion, surowa pierś kurczaka,
olej rzepakowy, gouda, miód, ogórek, papryka i parmezan. Nie wymagamy
pełnego feedu wszystkich sklepów ani pełnego OFF w Neon.

## Dowody

- Testy początkowo odtworzyły 5 błędów starej ścieżki; osobno dodano
  regresję zerowego wyniku dla nieobsługiwanej postaci frazy.
- Nowy moduł ma 33 przypadki transportu, weryfikacji, limitów, anulowania,
  kraju, zmiany etykiety i rzeczywistego zapisu przepisu w lokalnym SQLite.
  Sprawdza też, że drugie użycie nie tworzy duplikatu i nie wykonuje HTTP.
- Dwie partie źródeł: 6 przypadków lokalnego importu i integralności;
  obie postacie autoflush. Brak przenoszenia danych PL jest sprawdzany.
- Pełny backend: **2886 passed**, 43 istniejące ostrzeżenia
  zależności/deprecacji, exit 0, 222,27 s (`uk-stage46-backend-final.log`).
- Rzeczywista izolowana gałąź Neon: **passed**, 18 powiązań na istniejących
  produktach, powtórzenie importu, niezmienność PL i **rollback_verified**
  (`uk-stage46-neon.log`). Każdy rekord zachował oryginalny czas pobrania.
- Brak zmian Dart/Flutter, schematu bazy i bibliotek. Nie powtarzano
  niezmienionego zestawu Fluttera; ostatni pełny wynik jest w etapie 45.

Nie wykonano natywnego AAB/IPA, testu aparatu ani płatności. Wersja nadal
1.0.69+270, UK wyłączone, zamrożony ZIP niezmieniony. Do wydania pozostają
dalsze dane startowe i uzasadnione ceny GBP, dokumenty oraz konfiguracja
sklepów i rzeczywiste próby natywne. Tego etapu nie dopisywano do starego
powiadomienia wydania 270; kolejne wydanie potrzebuje nowych notatek.
