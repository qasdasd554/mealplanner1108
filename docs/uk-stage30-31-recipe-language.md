# UK — etapy 30–31, 23.10.2026

Zmiany lokalne po przekazaniu paczki PL 1.0.68+269. Nie wdrożono ich na
GitHub/Render, nie podbito wersji, nie aktywowano UK. Brak zmian wyglądu,
nowych funkcji, migracji i masowego importu OFF.

## Etap 30 — komunikaty istniejących operacji przepisu

Przyczyna: część wyjątków w `recipes.py` nadal zawierała wyłącznie polski
tekst, a globalny handler zwraca ich treść bez tłumaczenia. Konta GB
otrzymywały polskie błędy pomimo angielskiego interfejsu.

Komunikaty korzystają teraz z zapisanego kraju konta. Obejmuje to brak
przepisu/sklepu, zgłoszenie publikacji, usuwanie, sprawdzanie składników
przepisu ręcznego i wariantu, dopasowanie ze spiżarni oraz zgłoszenie
i moderację zdjęcia. Kontrole 400/403/404/409/422/429 i kolejność zapisu
pozostają bez zmian. Ogranicznik zgłoszeń zachowuje `Retry-After`; zmiana
języka nie zeruje licznika i nie wykonuje dodatkowego zapytania do bazy.

Polskie treści i reguły pozostały niezmienione. Testy obejmują też brak
możliwości usunięcia oficjalnego/cudzego przepisu, ponownego publikowania
przepisu w moderacji i zgłaszania zdjęcia do niewidocznego przepisu.

## Etap 31 — angielska etykieta nie oznacza nowego składnika

Odtworzono zbędne wyszukiwanie zewnętrzne i tworzenie prywatnego produktu:
angielskie `Potatoes`, `Onion`, `Breadcrumbs` nie rozpoznawały odpowiednich
istniejących produktów systemowych o polskich nazwach. Prompt UK także
podawał AI nazwy systemowe wyłącznie po polsku.

Istniejący, zatwierdzony indeks 150 tłumaczeń składników jest teraz używany
również w promptach importu/edycji i w dopasowaniu produktu. Wymagana jest
zgodność ID produktu, jego niezmienionej oryginalnej nazwy i brak autora.
Nazwy dopisane przez użytkowników, podobne nazwy i zmienione rekordy nie
uzyskują tłumaczenia na podstawie samego podobieństwa. Dokładna istniejąca
angielska nazwa katalogowa ma pierwszeństwo przed aliasem tłumaczenia.

Nie zmieniamy oryginalnych rekordów ani jednostek, ilości, makro, GTIN,
gramatur opakowań czy cen. Alias nie stanowi dowodu dostępności w UK i nie
tworzy ofert sklepowych ani wpisów OFF. Nie dodaje żądania sieciowego.
PL nadal korzysta z dotychczasowych nazw. Jeżeli AI nie wprowadzi zmiany,
samo użycie angielskiej nazwy nie pobiera punktu za edycję.

## Weryfikacja

- Przed poprawką etapu 30 testy odtworzyły błędy języka na kontach GB;
  błąd pomocniczej fikstury zdjęcia poprawiono osobno (brak display_name).
- 60 testów cyklu przepisu PL/GB przechodzi; sprawdzają też brak zapisu
  przy odrzuceniu i niezmienione kody HTTP.
- Pełny backend po etapie 30: **2037 passed, 43 warnings** (71,40 s).
- Przed poprawką etapu 31 odtworzono nierozpoznane angielskie składniki
  oraz polskie etykiety w promptach; fikstura PL tworzy osobne konto,
  nie obchodzi niezmienności kraju istniejącego konta.
- 45 testów etapu 31: trzy źródła importu (tekst/zdjęcie/link), PL/GB,
  autoflush włączony/wyłączony oraz SQLite bez RETURNING; brak nowych
  produktów i wywołań OFF dla rozpoznanego składnika. Sprawdzono wszystkie
  150 etykiet oraz brak opłaty za edycję bez faktycznej zmiany.
- Wspólna partia testów przepisów, języka, importu i katalogu: **208 passed**
  (10,76 s). Kontrola generatora: 137 przepisów, 150 składników, ilości
  niezmienione. Kontrola whitespace różnic względem kopii: bez błędów.
- Końcowy pełny backend po etapie 31: **2082 passed, 43 warnings** (72,94 s),
  kod zakończenia 0. Nie wykonywano zmian kodu po tej weryfikacji.

Testy używają lokalnych baz SQLite i syntetycznych odpowiedzi providerów.
Nie wykonano prawdziwych wywołań Gemini/OFF, zapisu produkcyjnej bazy,
pushy, płatności, buildów Android/iOS ani testów telefonu. Ostrzeżenia
zależności nie są dowodem awarii ani ich przyczyną ustaloną w tym etapie.

## Kopie i paczka w testach

Kopie przed zmianami są poza repozytorium w katalogach
`../backups/uk-stage30-20261023/` i `../backups/uk-stage31-20261023/`.
Zawierają tylko pliki danego etapu; nie obejmują sekretów ani bazy.
Nie należy cofać całego brudnego drzewa do HEAD, bo skasowałoby to
wcześniejsze prace UK i poprawki PL.

ZIP przekazany użytkownikowi jest niezmienny:
`mealplanner-update-1.0.68-269-49576a6-verified.zip`, SHA256
`892d05267aab58acf671efeb656a509212046db53d019d712270c99cd7012879`.
Te etapy nie są w tym ZIP-ie. Do kolejnej paczki potrzebny będzie nowy,
potwierdzony stan Codespace po jego instalacji. Treść kolejnego komunikatu
aktualizacji należy zaktualizować przy tworzeniu kolejnego wydania.

## Pozostałe granice startu UK

Tłumaczenie produktu nie wypełnia braku zweryfikowanych mapowań
składnik → produkt faktycznie sprzedawany w UK i źródłowo uzasadnionych
cen orientacyjnych GBP. To oddzielna kontrola danych, nadal wymagana.
Nadal potrzebne są końcowy przegląd dokumentów UK oraz rzeczywiste testy
aparatu, udostępniania, odnośników i zakupów na Androidzie/iOS.
UK_MARKET_ENABLED pozostaje False. Nie należy ogłaszać startu UK na
podstawie samych testów automatycznych.
