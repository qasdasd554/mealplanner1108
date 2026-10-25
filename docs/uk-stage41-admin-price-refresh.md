# Etap 41 — odświeżanie zatwierdzonych cen UK na żądanie

24.10.2026. Zmiany lokalne po zamrożeniu wydania 1.0.69+270.
Bez nowego ekranu, importu całego OFF, płatnego workera ani aktywacji UK.

## Zakres

Otwarcie istniejącego katalogu sklepu UK przez administratora może uruchomić
w tle odświeżenie jednej wcześniej zatwierdzonej obserwacji Open Prices.
Odpowiedź katalogu zawiera już zmaterializowane dane, a transakcja odczytu
jest zwalniana przed zewnętrznym HTTP. Nowa cena pojawia się przy następnym
odczycie. Zwykły użytkownik nie uruchamia importera z cudzymi uprawnieniami.

Zadanie ponownie sprawdza aktualnego administratora, jego blokadę oraz
uprawnienia przy zapisie. Nie korzysta z zapisanej tożsamości dawnego
recenzenta jako zastępstwa za uprawnienia aktualnej osoby.

## Ograniczenia źródła i tożsamości

- Tylko istniejąca, zatwierdzona oferta `store_observation` z Open Prices.
- Ten sam dokładny GTIN, kanoniczny składnik, sklep, wielkość i jednostka
  opakowania, aktualne mapowanie OFF oraz jego fingerprint.
- Tylko GBP, obserwacje nie starsze niż 30 dni, bez dat przyszłych,
  promocji i podmiany ceny za kilogram na cenę opakowania.
  `price_per=UNIT` oznacza cenę dokładnego opakowania i jest dopuszczone.
- Wybierana jest najnowsza poprawna obserwacja (data, potem ID), a nie
  najtańsza lokalizacja. Starsze ID z tego samego dnia nie cofnie dowodu.
- Zachowana data obserwacji, informacja o orientacyjnej cenie i zakresie
  dowodu; data pobrania nie udaje daty sprawdzenia ceny na półce.
- Dane właściciela dowodu, komentarze i adresy nie są kopiowane do oferty.
- Brak poprawnej obserwacji lub awaria źródła nie tworzą ceny 0.

Dotychczasowe reguły przypisania składnika i potwierdzenia podstawy
`as_sold` pozostają wymagane. Ten proces nie zatwierdza nowych produktów,
mapowań, SKU ani sklepów i nie uzupełnia automatycznie całego katalogu.
Zmiana tożsamości lub opakowania wymaga ponownego sprawdzenia danych.

## Wydajność i równoległe zmiany

Jedno zadanie pobiera najwyżej jedną stronę dziesięciu obserwacji dla
jednego kodu. Limity procesu: dwa aktywne zadania, sześć zapytań cenowych
na minutę, pięć minut przerwy na sklep i sześć godzin na ofertę.
Brak kolejki i nieskończonego ponawiania. HTTP ma limit czasu 4 s,
całe zadanie 14 s, odpowiedź 1 MB; przekierowania są wyłączone.
HTTP 429/503 wstrzymuje kolejne próby na pięć minut.
Przy wielu procesach limity są lokalne dla każdego procesu, nie globalne.

Importer pod blokadą wierszy porównuje fingerprint sprzed pobrania danych.
Równoległa poprawka administratora nie jest nadpisywana, a usunięta oferta
nie zostaje odtworzona. Zmiana mapowania lub utrata roli także blokuje zapis.
Nie zmieniają się składniki, makro, opakowania kanoniczne ani wcześniejsze
migawki kupionych pozycji list zakupów.

## Weryfikacja

- Testy skupione: 293 passed, 3 ostrzeżenia zależności/deprecacji, exit 0.
- Pełny backend: **2683 passed**, 43 istniejące ostrzeżenia zależności
  i deprecacji, exit 0, 130,25 s (`uk-stage41-backend-final.log`).
- Sprawdzono regresje kolejności obserwacji, poprawne `UNIT`, awarie HTTP,
  limity, wyścigi zapisu, aktualnego administratora i niezmienność historii.
- Test HTTP katalogu wykonuje zadanie po zwolnieniu transakcji odczytu;
  zewnętrzny klient jest zastąpiony kontrolowanym testowym odpowiednikiem.
- Odizolowana gałąź Neon: `passed=true`, konflikt fingerprintu odrzucony,
  migracje idempotentne, `rollback_verified=true`. Bez produkcyjnych zapisów.
- Nie zmieniano Fluttera ani interfejsu. Nie budowano AAB/IPA i nie wykonano
  nowych testów natywnych ani zakupów w sklepach w tym etapie.
- Compileall i kontrola zgodności wersji: exit 0. Dziewięć plików etapu
  sprawdzono bezpośrednio pod kątem LF, BOM i końcowych spacji; kontrola
  zmian Git dla śledzonych plików tego etapu również przeszła. Cały
  wcześniejszy worktree nadal zawiera niezwiązane różnice końców linii;
  nie normalizowano ani nie nadpisywano ich przy tej poprawce.

Powyższe nie dowodzi pełnego pokrycia rynku: sześć sprawdzonych powiązań
OFF i trzy referencyjne obserwacje cen pozostają małą próbką, nie feedem
dziesięciu sieci. UK pozostaje wyłączone. Wersja 270 i przekazany ZIP są
niezmienione; przed kolejną paczką potrzebna będzie świeża kopia Codespace.

Źródła kontraktu API:
[lista cen](https://openfoodfacts.github.io/documentation/docs/Open-prices/prices/prices_list/),
[oficjalne API](https://github.com/openfoodfacts/open-prices/blob/main/API.md),
[przewodnik danych](https://github.com/openfoodfacts/open-prices/blob/main/docs/guides/data.md).
Dotychczasowe obowiązki przypisania źródła i licencji pozostają w mocy.
