# UK: bezpieczne przygotowanie danych katalogu — etap 2

Stan: lokalny **dry-run**, nie import aktywnych produktów. Nie wykonano
zapytań do Neon, seedowania produktów ani zmiany flagi `UK_MARKET_ENABLED`.

## Co jest zaimplementowane

`backend/app/db/uk_product_catalog.py` waliduje całe partie propozycji:

- Jedna pozycja = jeden wskazany sklep UK + jego SKU + istniejący,
  zatwierdzony produkt kanoniczny. Nie ma automatycznego dopasowania po nazwie.
- Jawne angielskie określenie produktu, ilość opakowania i jednostka g/ml.
  Nie ma fallbacku „100 g”, założenia 1 g = 1 ml ani zmiany polskiej gramatury.
- Cena dotyczy **tego konkretnego brytyjskiego opakowania**, w GBP.
  `kind=estimate` wymaga uzasadnienia. Szacunek pozostaje szacunkiem;
  nie powstaje przez zmianę symbolu waluty polskiej ceny.
- Oddzielne źródło i data dla opakowania, ceny i obserwacji asortymentu.
  Adres HTTPS musi należeć do jawnie wybranego sklepu. Brak pobierania URL
  eliminuje sieciowe efekty uboczne i opóźnianie startu aplikacji.
- Stan oferty musi być podany: `available_online`, `out_of_stock` lub
  `unknown`. Sama obecność karty nie oznacza dostępności. Zakres to katalog
  online, **nie gwarancja stanu w każdej placówce w całej Wielkiej Brytanii**.
- Polityka przeglądu domyślnie wymaga dowodów z ostatnich 30 dni względem
  jawnego `as_of`; przyszłe daty są odrzucane. Jest to zasada importera,
  nie zapewnienie aktualności cen przez 30 dni.
- Stabilne UUID na sklep+SKU i SHA-256 pełnej propozycji zapewniają
  deterministyczny wynik. Identyczne duplikaty są scalane, sprzeczne
  przerywają całą partię. Powtórny przegląd daje `unchanged`, zmiana
  daje `revise_proposal`, nigdy ciche nadpisanie aktywnego produktu.
- Nieprawidłowe pola nie są ignorowane. Kwoty i ilości JSON mają być
  ciągami dziesiętnymi, nie liczbami zmiennoprzecinkowymi.

Walidacja adresu nie dowodzi prawdziwości danych — wymagany jest przegląd
źródła przez człowieka. Pole `publisher` nie zastępuje tego przeglądu.
Nie przepisujemy nazw ani wartości odżywczych globalnego produktu do PL.

## Dlaczego zapis jest celowo zablokowany

Obecny `StoreProduct` przechowuje cenę i dostępność, ale nie przechowuje
regionalnego SKU, lokalnej gramatury, źródła/zakresu obserwacji ani flagi
szacunku. Ma też unikalność sklep+produkt. Zapisanie kilku różnych paczek
tego samego składnika nadpisałoby jedną z nich albo zgubiło pochodzenie danych.

Dlatego `apply_uk_product_catalogue()` zawsze rzuca `UKCatalogueWriteBlocked`
**przed jakimkolwiek dostępem do sesji**, także dla pustej partii. Wynik planu
ma `can_write=False`. Nie podłączono go do startupu ani endpointów.
Nie należy obchodzić blokady przez ręczne budowanie `StoreProduct` z planu.

Do kolejnego etapu potrzebne są:

1. Warstwa lokalnych SKU i ich opakowań (g/ml), powiązana z kanonicznym
   składnikiem. Wiele opakowań w jednym sklepie nie może zmieniać globalnej
   polskiej gramatury ani odżywczości.
2. Trwałe dowody asortymentu/ceny (URL, data, zakres, autor przeglądu),
   typ ceny i uzasadnienie szacunku oraz oznaczenie szacunków w odpowiedziach API.
3. Decyzja, która zatwierdzona lokalna paczka jest wybierana do kosztu planu,
   z przeliczaniem ceny paczki na faktycznie potrzebną ilość, bez mieszania g/ml.
4. Osobne rozróżnienie listing/stan magazynowy. `out_of_stock` i `unknown`
   nie mogą automatycznie tworzyć aktywnego potwierdzenia składnika przepisu.
5. Migracja i idempotentny writer sprawdzone na izolowanej gałęzi Neon przez
   połączenie direct. Następnie test kosztu planu i filtrów dostępności.
6. Uzgodnione, dozwolone źródło danych/reuse dla pilotażu. Publiczna karta
   internetowa nie jest automatycznie darmową licencją na skopiowanie katalogu.

## Sprawdzone źródła i pułapki pilotażu

Sprawdzono 2026-10-15, wyłącznie oficjalne strony. Nie dodano tych pozycji
do bazy ani nie skopiowano całych tabel odżywczych/zdjęć.

- [Tesco Oats Porridge 1Kg](https://www.tesco.com/shop/en-GB/products/267449498):
  karta podaje paczkę 1 kg, ale w chwili sprawdzenia jest niedostępna.
  Pokazana tabela dotyczy przygotowanej owsianki; nie wolno traktować jej
  bez sprawdzenia jako odżywczości 100 g suchych płatków.
- [Sainsbury's British Semi Skimmed Milk](https://sainsburys.co.uk/groceries/product/sainsburys-british-semi-skimmed-milk-1-13l-2-pint):
  tytuł skraca objętość do 1.13 L, podczas gdy sekcja rozmiaru podaje
  1.136 L. Przeliczanie paczki wymaga właściwej szczegółowej informacji,
  nie samego parsowania nazwy.
- Obie karty zawierają zastrzeżenia użycia/reprodukcji. To sygnał do
  sprawdzenia zgody/warunków przed masowym importem, a nie gotowy feed UK.

Przypadki testowe są jawnie syntetyczne. Nie dowodzą prawdziwości SKU,
cen ani odżywczości w dowolnym sklepie. Dowodzą walidacji, idempotencji
planu i braku operacji zapisu. UK pozostaje wyłączone do pełnej weryfikacji.
