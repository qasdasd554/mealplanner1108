# Etap 47 — składniki UK, istniejący GTIN i zmienna gramatura

Prace lokalne z 24.10.2026, bez wdrożenia i bez aktywacji UK. Backup plików
sprzed tego etapu: `../backups/uk-stage47-20261024/`. Numer pozostaje
1.0.69+270, a przekazany wcześniej ZIP nie jest zmieniany.

## Ponowne użycie zaakceptowanego produktu

Test odtworzył blokadę zapisu składnika UK, gdy dokładny GTIN był już
w katalogu pod inną nazwą językową lub jako zaakceptowane zgłoszenie.
INSERT poprawnie wykrywał unikalny kod, lecz późniejsza kontrola wymagała
identycznej nazwy i autora jak dla nowego produktu systemowego.

Po poprawce wolno ponownie użyć publicznego, zaakceptowanego produktu,
jeśli nowa propozycja ma ten sam dokładny GTIN, świeży pełny odczyt OFF
z UK oraz zgodną fizyczną jednostkę. Nie wystarcza wynik indeksu, sama
nazwa ani podobny produkt. Odczyt starszy niż 7 dni nie rozszerza tej zgody.

- Nazwa, autor, marka, kraj zgłoszenia, opakowanie i poprawne makro
  istniejącego produktu pozostają niezmienione.
- Nie są promowane produkty oczekujące ani odrzucone, nie są akceptowane
  gotowe dania czy niezgodne jednostki g/ml.
- Świeże fakty kraju są zapisywane w tej samej transakcji co przepis.
  Rollback usuwa nowe fakty, a pozostawia istniejący produkt.
- Regresja obejmuje również cały zapis przepisu AI i obliczenie makro
  z istniejącego zaakceptowanego produktu, bez dodatkowego HTTP.
- Ścieżka PL nie otrzymała nowego wymogu dowodów kraju ani tłumaczenia nazw.

## Zakres masy nie jest opakowaniem o stałej masie

Rzeczywisty odczyt OFF ogórka `5000128271165` ma tekst `300/350g` i pole
numeryczne 350. Wcześniej parser oferował stałe opakowanie 350 g. Nowa
kontrola odrzuca takie zakresy również wtedy, gdy pole numeryczne zawiera
górną granicę. Makro na 100 g pozostaje dostępne; użytkownik podaje faktyczną
ilość. Nie zgadujemy masy sztuki ani gęstości. Dotyczy PL i UK.

Przetestowano zakresy ze slashem, myślnikiem, półpauzą i angielskim „to”,
także z kg. Potwierdzone `350 g`, `2 x 150 g` i `1,5 l` nadal działają.

## Siedem kolejnych powiązań składników

`backend/tests/fixtures/off_uk_cooking_staples_20261024.json` zawiera
sprawdzone fakty OFF z oryginalnymi czasami pobrania, odciskami i notatką
przeglądu. Wybrany rekord odczytano z pełnego API produktu, a nie tylko
z indeksu wyszukiwarki. To materiał kontrolowanego importu, nie dane
automatycznie ładowane przy starcie.

| Składnik kanoniczny | Sprawdzony kod OFF | Istotna kontrola |
| --- | --- | --- |
| Pierś z kurczaka | 29304707 | surowa, bez skóry, składnik chicken; nie preparat 90% mięsa |
| Olej rzepakowy | 5000232852908 | 100% oleju, jawne 1 L; bez przeliczenia masy na objętość |
| Ser żółty gouda | 01222685 | zwykła gouda, nie mieszanka z chorizo |
| Miód | 20802233 | zwykły miód, nie mieszanka z mleczkiem pszczelim |
| Ogórek | 5000128271165 | świeży, nie konserwowy; brak stałej masy opakowania |
| Papryka czerwona | 5010251868095 | świeża, nie hummus; 3 sztuki nie oznaczają 3 g |
| Parmezan | 5052449004014 | Parmigiano Reggiano, nie gotowe danie/sos |

Nie powiązano kostki bulionu 6 g z ogólnym „Bulionem warzywnym”: obecne
przepisy zawierają również ilości płynnego bulionu. Bez rozstrzygnięcia
postaci i stężenia nie wolno udawać ich równoważności. Nie skopiowano
wartości odżywczych kostki do produktu kanonicznego.

Źródło i atrybucja: Open Food Facts, ODbL-1.0. Adresy źródłowe znajdują się
w pakiecie. Same zgłoszenia sprzedaży w UK nie potwierdzają półek sklepu,
cen GBP ani zgodności alergenów wszystkich produktów danego rodzaju.

Łącznie cztery przygotowane partie obejmują 31 pojęć składników; statyczne
porównanie wymaganych składników pokrywa 19 z 137 wbudowanych przepisów.
To nie jest liczba przepisów widocznych obecnie na produkcji ani dowód
kompletności danych startowych. Nowe siedem powiązań sprawdzono lokalnie
w SQLite, bez kolejnego połączenia z Neon.

## Testy i granice

Przed poprawkami odtworzono 8 błędów konfliktu GTIN oraz 10 przypadków
błędnej stałej gramatury. Po poprawkach testy celowane obejmują cztery
tryby SQLite, w tym symulację braku RETURNING z Codespace 3.34.
Końcowy wynik pełnego backendu: **2946 passed**, 43 istniejące ostrzeżenia,
exit 0, 229,41 s (`uk-stage47-backend-final.log`). Osobny zestaw nowych
regresji, danych i parsera: **94 passed**, exit 0. Wersje są zgodne,
compileall i kontrola LF/BOM ośmiu plików przeszły; SHA-256 zamrożonego ZIP-a
pozostaje `ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.

Bez zmian Fluttera, wyglądu, bibliotek i schematu. Nie budowano AAB/IPA,
nie wykonano testu aparatu, zakupów ani dostarczenia push na telefon.
Nie zmieniono tekstu opublikowanej wersji 270: nowe notatki aktualizacji
muszą wejść razem z kolejną, osobno zleconą paczką wydania.

Dalsze prace: pozostałe często używane składniki, uczciwe oszacowania cen
GBP i ich pochodzenie, angielskie dokumenty oraz testy natywne i sklepowe.
