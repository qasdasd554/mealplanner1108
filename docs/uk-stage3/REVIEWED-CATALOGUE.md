# Etap 3: osobna warstwa zatwierdzonych ofert UK

Prace lokalne, nie wydanie ani aktywacja rynku. Brak połączenia z Neon.
Nie załadowano żadnego realnego ani syntetycznego asortymentu produkcyjnego.

## Model i kontrakt

`RegionalProductOffer` / `regional_product_offers` jest tabelą addytywną,
oddzieloną od `Product` i `StoreProduct`. Jedna pozycja reprezentuje konkretny
SKU jednego brytyjskiego sklepu, z lokalną gramaturą g/ml i ceną GBP za to
opakowanie. Identyfikator to deterministyczny `UKProductProposal.proposal_id`.
Unikalność obejmuje również `(store_id, retailer_sku)`.

Zapis zawiera trzy oddzielne źródła JSON (opakowanie/cena/asortyment): URL,
wydawcę i datę obserwacji. Zachowuje jawnie cenę `observed` albo `estimate`,
uzasadnienie szacunku, stan `available_online` / `out_of_stock` / `unknown`,
zakres `online_catalogue`, fingerprint, autora zatwierdzenia i czas UTC.
Karta online nie jest zapewnieniem dostępności w każdej placówce.

Zastosowano dokładne `Numeric(9,3)` dla g/ml, `Numeric(10,2)` dla GBP,
NOT NULL, FK, CHECK wartości/typów/zakresów i indeks produkt+sklep.
Usunięcie konta administratora ustawia autora na NULL, nie kasuje oferty
i nie blokuje istniejącej funkcji usuwania konta. Źródła i czas pozostają.

## Jedyny nowy entry point zapisu

`import_reviewed_uk_catalogue(session, rows, reviewer_user_id=..., reviewed_at=..., as_of=...)`

- Nie przyjmuje roli administratora jako argumentu i nie ufa obiektowi User
  z pamięci klienta. Pobiera rolę i blokadę konta z bazy dla wskazanego UUID.
  Brak konta, ban i rola inna niż admin odrzucają zapis.
- UUID musi pochodzić z uwierzytelnionej sesji. Czas UTC i `as_of` to jawne
  zaufane metadane przeglądu serwerowego, nie pola kontrolowane przez klienta.
  `as_of` musi być datą `reviewed_at` w UTC.
- Ponownie waliduje całą partię, oficjalne domeny odpowiedniego sklepu,
  świeżość dat i źródła. Wymaga istniejących sklepów GB/GBP oraz zatwierdzonych
  produktów kanonicznych ze spójnym, zapisanym wymiarem g/ml.
- Wymiar wynika z `Product.unit` (g/kg lub ml/l), a dla szt/opak z jednoznacznych
  `measure_options.base_unit`. Nie zgaduje gęstości ani rodzaju płynu z nazwy.
  Brak/sprzeczność wymiaru zatrzymuje partię. Nie ma fallbacku 100 g.
- Pobiera tylko istniejące oferty odpowiadające SKU/ID z tej partii, nie cały
  katalog danego sklepu. Blokady sklepów w stałej kolejności serializują
  równoległe importy w PostgreSQL. Unikalność bazy pozostaje drugą ochroną.
- Identyczny retry nie duplikuje SKU i nie przedłuża sztucznie daty przeglądu.
  Zmieniona, ponownie sprawdzona oferta aktualizuje ten sam ID. Stary przegląd
  nie może nadpisać nowszego. Różnica pól przy niezmienionym fingerprint jest
  naprawiana z ponownie zwalidowanej propozycji, nie traktowana jako no-op.
- Wszystkie własne zmiany obejmuje SAVEPOINT. Błąd walidacji/flush odtwarza
  stan partii, nie cofa wcześniej jawnie zapisanych do transakcji zmian wywołującego.
  Wymagany jest czysty unit-of-work bez oczekujących new/dirty/deleted, aby
  `begin_nested` nie wykonał automatycznie cudzych oczekujących zmian.
- Wykonuje flush, **nie wykonuje commit**. Wywołujący zarządza transakcją.
  Nie dodano automatycznego wywołania, endpointu, seedowania ani przełącznika UI.

Starsze `apply_uk_product_catalogue` nadal zawsze blokuje zapis do starego
modelu. Dry-run nie jest niejawnie zamieniony w writer.

## Ograniczenia i bramki przed wdrożeniem

- To nie jest gotowy asortyment UK, feed cen ani gwarancja prawa do reprodukcji
  danych. Źródła nadal wymagają rzeczywistego przeglądu i uzgodnionej licencji.
- Trzy źródła mają NOT NULL w bazie, ale dokładny schemat JSON i domeny są
  walidowane przez writer, nie przez przenośne CHECK JSON. Ręczne SQL omijające
  writer musi być ograniczone uprawnieniami. Odbiorca danych powinien nadal
  defensywnie walidować propozycję i fingerprint.
- FK autora pozwala usunąć konto. Istniejący rekord z NULL nie przestaje być
  historycznie zatwierdzony; każdy nowy zapis nadal wymaga obecnego admina.
- Przeliczenia planów/list/API wymagają jednego spójnego pionowego wdrożenia
  wraz z wyborem SKU i snapshotem użytego opakowania. Nie wolno podłączyć GBP
  do starej polskiej gramatury ani zmienić tylko jednego ekranu.
- Lokalny SQLite uruchamia realne transakcje/FK; testy sprawdzają również
  błąd po wykonanym INSERT i brak ukrytego commit. Adapter nie zastępuje
  rzeczywistego AsyncSession+asyncpg, konkurencji i migracji PostgreSQL.
- Kompilacja DDL PostgreSQL sprawdza SQL, nie wykonanie na Neon. Po przeglądzie
  model pozostał zarejestrowany w istniejącym metadata.create_all, które
  podczas przyszłego wdrożenia utworzy pustą addytywną tabelę. Nie wymaga to
  zmiany kolumn polskiego katalogu. Przed produkcją nadal konieczny jest
  test na odizolowanej gałęzi Neon przez połączenie direct.
