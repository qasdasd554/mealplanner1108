# UK — odświeżanie użytych danych OFF, 24.10.2026

Kontynuacja [etapu 39](uk-stage39-community-pricing-integration.md).
Backup: `../backups/uk-stage40-20261024/`, bez nadpisywania kopii.
Wersja 1.0.69+270 i wyłączone UK pozostają bez zmian. Brak push/deploy,
nowych zasobów płatnych, zmian wyglądu i nowej paczki.

## Odtworzone luki

1. Kompletne trafienie lokalne skanera kończyło odpowiedź bez odnawiania
   osobnego potwierdzenia sprzedaży produktu w UK.
2. Równoległy starszy zapis OFF mógł cofnąć czas pobrania nowszego cache.
3. Wyszukiwanie cache nie wykluczało rekordów z przyszłą datą pobrania.
4. Zapis wyniku z pamięci mógł nadawać mu czas wykonania zadania zamiast
   oryginalnego pobrania HTTP.
5. Request-scoped sesja FastAPI pozostawała otwarta do końca zadań tła,
   również podczas ich HTTP. Samo użycie osobnej sesji w zadaniu nie
   wystarczało do zwolnienia pierwotnego połączenia żądania.
6. Zmieniony fingerprint OFF unieważniał powiązanie dostępności, ale zapisana
   wcześniej cena społecznościowa mogła nadal przechodzić jako żywa oferta.

## Implementacja

Istniejący skaner kont GB dopina małe zadanie tła po trafieniu w lokalny
katalog/cache. Telefon otrzymuje dotychczasowy wynik bez czekania na OFF.
Po materializacji odpowiedzi zwalniana jest tylko odczytowa transakcja
tych ścieżek. Zapis aktywności uwierzytelnienia jest wcześniej zatwierdzony.
Test HTTP z rzeczywistą kolejnością zależności sprawdza brak transakcji
podczas zadania tła. Żadnych zmian w zachowaniu polskiego skanera.

`off_on_demand.py`:

- dotyczy tylko jednego, właśnie użytego prawidłowego GTIN;
- świeży cache (do 7 dni, bez dat przyszłych) daje zero zapytań do OFF;
- do dwóch aktywnych odświeżeń i sześciu HTTP na minutę na proces,
  bez kolejki i nieograniczonych retry;
- ten sam kod i jego aliasy UPC/EAN/GTIN mają wspólną blokadę i 5 minut
  przerwy między próbami; pamięć prób ograniczona do 256 kluczy;
- 429/503 uruchamia 5 minut przerwy dla tego odświeżacza;
- limit 6 sekund całości, 4 sekund HTTP i 1 MB odpowiedzi strumieniowej;
  stały host OFF, User-Agent, ograniczona projekcja, bez przekierowań;
- własna sesja zapisu, bez trzymania połączenia DB podczas HTTP;
- zły kod, brak UK, rekord obsolete, błędny JSON i błąd sieci nie
  odnawiają starego potwierdzenia ani nie psują już zwróconego skanu.

Są to limity odświeżacza na proces, nie gwarancja wspólnego limitu całego
ruchu foreground i wielu instancji. Wymagania OFF sprawdzono w
[oficjalnej dokumentacji API](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/index.md).
Nie dodano HTTP do filtrów przepisów, ich paginacji, generowania list
ani pętli składników. Nie pobieramy pełnej bazy OFF.

Upsert wymaga nie starszego czasu pobrania oraz nowszej rewizji albo
tej samej rewizji/fingerprint. Nie „odmładza” innej wersji etykiety.
Wyszukiwanie dopuszcza dokładnie okno od teraz minus 30 dni do teraz.
`BarcodeLookupResult.off_retrieved_at` zachowuje oryginalny UTC ISO8601
razem z raw OFF przez cache pamięci i merge; kolejka zapisu nie resetuje
daty. Żadne nowe pole nie trafia do publicznej odpowiedzi skanera.

Nie aktualizuje się automatycznie zatwierdzeń administratora, makro
produktu kanonicznego, cenników ani cen Open Prices. Podobna nazwa nie
jest dowodem, że dany produkt odpowiada składnikowi przepisu.

Dodatkowy lokalny filtr SQL dla cen społecznościowych ponownie sprawdza
dokładny GTIN/fingerprint, zatwierdzone powiązanie, tożsamość produktu,
nazwę źródłową, wymiar, opakowanie i daty. Zmiana etykiety nie może więc
utrzymać publicznego przepisu przez starą ofertę ani dać nowej wyceny
na niewłaściwe opakowanie. Ceny internetowe mają dotychczasowe warunki,
a zamrożony zapis już kupionego produktu pozostaje historią.

## Weryfikacja

- Potwierdzono czerwonymi testami cofanie czasu i przyszłe daty cache,
  gubienie pierwotnego czasu pobrania oraz zachowanie starej ceny po
  zmianie potwierdzenia OFF. Następnie testy przeszły po poprawkach.
- Testy HTTP sprawdzają zachowanie wyników skanu i zwolnienie transakcji
  przed zadaniem tła w czterech trybach SQLite/autoflush/RETURNING.
- Testy kontrolują m.in. brak HTTP dla świeżego cache, deduplikację kodów
  i aliasów, limit ruchu, timeout, 429/503/404, za dużą odpowiedź,
  inny GTIN, brak UK, obsolete, przyszłe daty oraz brak automatycznego review.
- Końcowy pełny backend: **2619 passed**, 43 istniejące ostrzeżenia
  zależności/deprecacji, exit 0, 124,23 s (`uk-stage40-backend-final.log`).
  To 92 przypadki więcej niż pełny zestaw po etapie 39.
- Odizolowana gałąź Neon/asyncpg: **passed=true**, w tym monotoniczny
  zapis czasu OFF, ukrywanie przyszłego cache, unieważnienie żywej ceny
  po zmianie fingerprintu oraz zgodność istniejących polskich danych.
  Cała próba ma potwierdzony rollback (`uk-stage40-neon-final.log`).
- Compileall i bezpośrednia kontrola 18 plików UTF-8/LF bez BOM oraz
  końcowych spacji: exit 0. Kontrola zgodności wersji: 1.0.69, exit 0.
- Nie zmieniano Fluttera w tym etapie; nie wykonywano natywnego buildu,
  testów aparatu/zakupów na telefonie ani wdrożenia produkcyjnego.

## Granice etapu

To odświeżanie kraju pochodzenia już użytych danych, nie pełny katalog
dziesięciu sieci ani automatyczne zatwierdzanie składników. Wciąż potrzebne
są szersze, sprawdzone mapowania oraz osobna ścieżka odświeżania uzasadnionych
cen GBP. Nie wolno zastępować w niej administratora kontem użytkownika
ani resetować daty rzeczywistej obserwacji ceny.

Do publicznego UK nadal pozostają: pokrycie danych, dokumenty/atrybucja,
natywne testy Android/iOS i zakupów/triala, konfiguracja sklepów i nowa
paczka dopasowana do aktualnego Codespace. UK nie jest włączane.

Zamrożona paczka 270 pozostaje bez zmian, SHA-256:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
