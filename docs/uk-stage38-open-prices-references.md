# UK — sprawdzanie rzeczywistych obserwacji cen GBP, 23.10.2026

Kontynuacja po [etapie 37](uk-stage37-catalogue-coverage.md).
Ten etap przygotowuje dane referencyjne, nie podłącza ich jeszcze do cen
wyświetlanych w aplikacji. UK pozostaje wyłączone, wersja 1.0.69+270.
Backup zmienianego indeksu dokumentacji: `../backups/uk-stage38-20261023/`.
Pozostałe pliki tego etapu są nowe; nie nadpisują wcześniejszych modułów.

## Ustalona różnica źródeł

Open Prices publikuje obserwacje cen m.in. z paragonów i etykiet. To inny
zakres niż dotychczasowe `UKProductProposal` i `RegionalProductOffer`, które
opisują sprawdzone oferty internetowe detalisty. Nie należy podawać paragonu
jako aktualnej oferty online ani udawać potwierdzenia stanu półki.

Źródła pierwotne: [projekt/API](https://github.com/openfoodfacts/open-prices)
oraz [dane i warunki ODbL](https://github.com/openfoodfacts/open-prices/blob/main/docs/guides/data.md).
Nie kopiowano kodu serwera Open Prices ani nie zaciągano jego pełnego dumpa.
Pobrano tylko trzy konkretne publiczne obserwacje:

- [349142](https://prices.openfoodfacts.org/prices/349142): Basmati Rice,
  GTIN 20071974, 1 kg, 1,79 GBP, Lidl, 17.10.2026.
- [336462](https://prices.openfoodfacts.org/prices/336462): Tomato Passata,
  GTIN 20522605, 500 g, 0,45 GBP, Lidl, 27.09.2026.
- [334190](https://prices.openfoodfacts.org/prices/334190): Unsalted Welsh Butter,
  GTIN 4056489895268, 250 g, 1,85 GBP, Lidl, 23.09.2026.

To obserwacje z tych dni i miejsc, nie cennik całej sieci na dziś.
Snapshot z 23.10 zawiera tylko identyfikatory i potrzebne fakty produktów,
sklepu i dowodu. Nie zapisuje kont zgłaszających, komentarzy, dokładnych
adresów, współrzędnych ani zdjęć paragonów:
`backend/tests/fixtures/open_prices_uk_20261023.json`.
`automatic_import=false`; brak zapisu do Neon.

## Implementacja i granice

Nowy czysty moduł `open_prices_reference.py` przyjmuje pojedynczą obserwację,
aktualny rekord kanoniczny, cache OFF i jawnie sprawdzone powiązanie z etapu 37.
Nie wykonuje HTTP, SELECT/INSERT ani commit. Wynik `OpenPricesReference`:

- ma dokładny Decimal w GBP, źródłowy GTIN, lokalną masę/objętość opakowania,
  datę obserwacji i publiczny odnośnik do źródła;
- zachowuje ODbL i osobne źródło gramatury OFF;
- ma zawsze `price_is_estimated=true`,
  `availability_scope=community_observation`, `current_stock_confirmed=false`;
- nie ma fikcyjnego SKU detalisty ani przepisanych makro/marki/opakowania
  produktu kanonicznego. Przykładowe polskie masło 200 g nie staje się źródłem
  brytyjskiego opakowania 250 g.

Sprawdzane są dokładne kody i ID, nie podobieństwo nazwy: aktualność
powiązania i fingerprintu OFF, zatwierdzenie składnika systemowego, kraj GB,
łańcuch zgodnych ID produktu/lokalizacji/dowodu oraz jawna marka znanej sieci.
Sama nazwa miejsca, np. centrum handlowego, nie identyfikuje detalisty.

Cena musi dotyczyć pojedynczego, określonego opakowania, bez rabatu, ceny
lojalnościowej, niejednoznacznej wielosztuki lub ceny za kilogram. Wersja
źródłowego JSON jest dekodowana z `parse_float=Decimal`; nie zaokrągla się
1,799 do 1,80. Kilogramy/litry można przeliczyć na g/ml, nigdy masę na objętość.
Gramatura musi zgadzać się z tym samym, bieżącym kodem OFF.

Data dowodu, waluta i lokalizacja muszą zgadzać się z obserwacją; dowód nie
może być szkicem. Obserwacja i cache muszą mieścić się w 30 dniach bez dat
przyszłych. Ponowne pobranie starej ceny nie resetuje jej daty. Nie zgaduje
się masy po odsączeniu ani tego, ile opakowań pokryje przepis.

Wynik celowo nie przechodzi walidacji istniejącego `UKProductProposal`.
Nie zmieniono schematu bazy ani walidatorów obecnych ofert, wyceny list,
granic Premium czy UI. Zapobiega to przypadkowemu opisaniu ceny społecznościowej
jako bieżącej oferty internetowej sklepu.

## Dowody

- Przed implementacją nowy test nie mógł zaimportować brakującego modułu.
- Pierwsze 60 przypadków: **60 passed**, exit 0 (`uk-stage38-reference-tests.log`).
- Poszerzona partia: **348 passed**, exit 0, 11,97 s
  (`uk-stage38-targeted.log`), w tym 77 nowych przypadków referencji cenowych.
- Pełny backend po tej wersji modułu: **2501 passed**, 43 ostrzeżenia
  zależności/deprecacji, exit 0, 114,99 s (`uk-stage38-backend-final.log`).
- Następnie dwa dodatkowe przypadki błędnego JSON (lista zamiast tekstowego
  rodzaju dowodu lub OSM) odtworzyły niekontrolowany TypeError. Dodano jawne
  sprawdzenie typów: takie dane są odrzucane jako ValueError, nie awaria.
  Końcowa ponowna partia po tej poprawce: **350 passed**, w tym 79 przypadków
  referencji, exit 0, 12,23 s (`uk-stage38-targeted-final.log`).
- Compileall: exit 0; nowy moduł, test i dane bez końcowych spacji, UTF-8/LF.
- W `backend/app` nie ma wywołania nowego modułu z runtime aplikacji.
  Nie dodano zapytań do bazy ani ruchu sieciowego przy korzystaniu z aplikacji.

## Następny wymagany krok

Trzeba jawnie obsłużyć nowy rodzaj pochodzenia ceny w warstwie zapisu i odczytu,
wycenie oraz zamrożonej historii zakupów, zachowując jego oznaczenie. Dotychczasowy
kontrakt dopuszcza tylko `online_catalogue`; nie wolno go obchodzić. Przed
użyciem referencji do liczby opakowań pozostaje kontrola podstawy ilości
(np. masa całkowita kontra masa po odsączeniu), odświeżanie na żądanie i testy
na odizolowanej gałęzi Neon. Trzy obserwacje nie zapewniają pokrycia wszystkich
produktów i dziesięciu sieci.

Nie zmieniano Fluttera, nie wykonywano nowych AAB/IPA ani testów płatności,
nie uruchamiano importu na produkcji. Zamrożony ZIP 270 bez zmian, SHA-256:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
