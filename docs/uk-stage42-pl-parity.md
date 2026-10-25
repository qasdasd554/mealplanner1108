# Etap 42 — porównanie rzeczywistej ścieżki PL i UK

24.10.2026. Przegląd kodu lokalnego, nie zdalnego stanu produkcji.
Backup przed zmianami: `../backups/uk-stage42-20261024/`.

## Ustalenie dotyczące zakresu

Nie wszystkie mechanizmy UK są takie same jak PL. Skaner i rozwiązywanie
brakujących składników korzystają ze wspólnego kodu, natomiast wycena UK
została rozbudowana o osobny model dowodów/ofert i rygorystyczny importer.
Pełny, stale aktualny feed wszystkich SKU dziesięciu sieci nie jest
warunkiem odtworzenia polskiego modelu cen orientacyjnych i nie powinien
być traktowany jako dodatkowy wymóg właściciela aplikacji.

| Obszar | PL w aktualnym kodzie | UK w aktualnym kodzie |
| --- | --- | --- |
| Skan kodu | Własny `Product`, następnie wspólny `BarcodeProductCache`, potem OFF/USDA | Ta sama funkcja i kolejność; angielskie etykiety oraz osobne fakty o rynku UK |
| Zapis pobranego produktu | Dopiero przy użyciu; wspólny cache, bez pełnego dumpu OFF | Tak samo na żądanie, dodatkowo cache zgłoszonej sprzedaży w UK |
| Brakujący składnik AI | Katalog lokalny, ograniczone szukanie zewnętrzne, oznaczony szacunek/brak makro | Ten sam resolver, z angielskimi aliasami istniejących składników |
| Ceny startowe | `base_price * PRICE_MULTIPLIERS`, opcjonalne `STORE_PRICE_OVERRIDES`; `last_verified=None` | Osobne oferty GBP z podstawą ceny, jednostką i źródłem; nie z polskiego seeda |
| Widełki ze skanera | Stałe szerokie widełki kategorii w PLN, nie feed cen OFF | Widełki PLN ukryte; nie wolno po prostu podmienić symbolu waluty |
| Widoczność przepisów | Publiczny katalog nie ma dodatkowego filtra kraju; generator sprawdza polskie powiązania sklepowe | Każdy wymagany składnik potrzebuje dowodu UK, zgodnie z wcześniejszą decyzją właściciela; dowód krajowy OFF wystarcza bez ceny/sklepowego SKU |

Podstawa: `app/api/v1/products.py`, `app/services/barcode_lookup.py`,
`app/services/recipe_ingredient_catalogue.py`, `app/db/seed.py`,
`app/services/market_catalog.py`, `app/services/meal_plan_generator.py`
oraz obie ścieżki wyceny w `shopping_list_builder.py`.

Sześć ręcznie sprawdzonych powiązań i trzy referencyjne obserwacje to
dotychczasowy zestaw dowodowy/testowy, nie rozmiar światowej bazy OFF ani
limit skanera. Dokładny kod produktu pobrany na żądanie nie wymaga
ręcznego mapowania do innego produktu. Mapowanie jest potrzebne wtedy,
gdy chcemy powiązać ogólny składnik przepisu z innym, konkretnym SKU.

## Potwierdzona luka i poprawka

Przy odkrywaniu brakującego składnika przepisu zapis `Product` zachowywał
nazwę, GTIN i makro, lecz gubił już pobrane fakty OFF o rynku UK. Ścieżka
skanera zapisywała je, a ścieżka tworzenia przepisu nie. W efekcie taki
składnik był zapisany, ale publiczny przepis nadal mógł nie przejść filtra
kraju, mimo że źródło zawierało zgłoszoną sprzedaż w UK.

Resolver przenosi teraz wyłącznie dowód dokładnie użytego produktu OFF
do zapisu całego przepisu. Utrwalanie używa istniejącego cache/upsertu:

- Bez kolejnego HTTP, AI, pełnego importu ani zapytań podczas przewijania.
- Oryginalny czas pobrania podróżuje z danymi; czas zapisu nie odmładza cache.
- GTIN, nazwa, jednostka, kraj i poprawność źródła muszą pasować.
- Nie tworzy to ceny ani dostępności w konkretnym sklepie, nie tworzy
  mapowania innego składnika i nie zatwierdza jego tożsamości przez podobieństwo.
- Niepełny, sprzeczny lub przyszły dowód zostaje pominięty; nie odrzuca
  kompletnego przepisu ani nie zastępuje jego danych fikcyjnymi zerami.
- Zapis jest częścią transakcji przepisu/punktów, bez własnego commita;
  nieudane tworzenie przepisu wycofuje także cache użytego składnika.
- Ponowne użycie zapisanego składnika jest lokalne. Zachowanie PL bez zmian.

## Weryfikacja i dalszy zakres

Test przed poprawką: 8 failed, 28 passed — odtworzono utratę dowodu UK.
Po poprawce skupiona partia: **177 passed**, exit 0, 12,80 s.
Pełny backend: **2719 passed**, 43 istniejące ostrzeżenia zależności/deprecacji,
exit 0, 132,74 s (`uk-stage42-backend-final.log`). Compileall, zgodność wersji
oraz kontrola UTF-8/LF bez BOM/końcowych spacji czterech plików: exit 0.
Testy wykonują prawdziwy zapis/rollback SQLite w czterech wariantach
autoflush/RETURNING oraz sprawdzają PL i UK, idempotencję użycia, brak nowych
ofert cenowych/mapowań, błędny GTIN/kraj/nazwę, przyszłe daty i obsolete.

Nie wymagamy kompletnego feedu cen wszystkich sieci ani pełnej kopii OFF.
Do startu nadal potrzebne są uzasadnione dane GBP dla używanego katalogu
i wystarczające pokrycie brytyjskich składników w przepisach. Nie oznacza
to ręcznej weryfikacji każdego produktu, który ktokolwiek może zeskanować.
Nie zamieniono PLN na GBP i nie usunięto zatwierdzonego filtra dostępności
składników w kraju. Testy natywne/płatności oraz przegląd dokumentów UK
pozostają oddzielnymi wymaganiami.

Bez zmian wyglądu, bez nowej funkcji dla użytkownika i bez produkcyjnego
wdrożenia. UK pozostaje wyłączone, wersja 1.0.69+270 oraz zamrożona paczka
270 nie są zmieniane. Nie budowano AAB/IPA w tym etapie.
