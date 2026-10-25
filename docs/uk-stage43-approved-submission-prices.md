# Etap 43 — zgłoszone ceny UK w istniejących funkcjach zakupów

24.10.2026. Prace lokalne, po backupie `../backups/uk-stage43-20261024/`.
Bez nowego ekranu, zmiany stylu, płatnej usługi ani aktywacji UK.

## Przyczyna braku zgodności z PL

Istniejąca akceptacja produktu tworzyła `StoreProduct` również dla GB.
Brytyjski katalog, lista i porównanie odczytują natomiast
`RegionalProductOffer`, aby zachować poprawną masę opakowania i walutę.
W efekcie zgłoszona i zaakceptowana cena GBP była zapisana, ale ignorowana.

## Poprawka istniejącej ścieżki

- PL zachowuje dotychczasowy zapis i działanie `StoreProduct`.
- UK używa tego samego formularza i decyzji administratora, zapisując
  zgłoszoną cenę do istniejącego modelu regionalnego.
- Zakres `user_submission` wyraźnie odróżnia zgłoszenie użytkownika od
  oficjalnego katalogu detalisty i obserwacji Open Prices. Cena jest zawsze
  orientacyjna, a dostępność pozostaje zgłoszeniem, nie stanem półek.
- Wymagane są GBP, właściwy sklep UK, zaakceptowany produkt i rzeczywista
  zgłoszona gramatura opakowania. Samo `default_quantity=100` nie wystarcza.
- Brak wiarygodnej masy, ceny lub aktualnego zgłoszenia nie cofa decyzji
  o produkcie, ale nie tworzy fikcyjnej oferty. Nie wpisujemy ceny 0.
- Dowód zachowuje datę zgłoszenia; ponowna akceptacja nie odmładza ceny.
  Nie zapisuje adresu e-mail, tokenu ani danych osobowych zgłaszającego.
- Wewnętrzny klucz `submission-<UUID>` nie jest przedstawiany jako SKU
  sprzedawcy. URL wskazuje aplikację, a `submission_id` wewnętrzny rekord,
  nie nieistniejącą publiczną stronę produktu.
- Importer ponownie sprawdza w bazie administratora, bieżący produkt,
  proponowany sklep, gramaturę i cenę. Zmiana nazwy, jednostki, marki, kodu,
  gramatury, kraju, ceny lub statusu produktu unieważnia żywą wycenę.
- Kupione wcześniej pozycje zachowują niezmienny zapis ceny i opakowań.
  Zakończenie listy przenosi faktycznie kupioną masę do spiżarni tylko raz.

Przykład testowy: potrzebne 500 g, opakowanie 450 g, cena £1.20.
Lista wylicza dwa opakowania i £2.40, a nie pięć porcji po 100 g.

To nie jest pełny feed supermarketów. Odblokowuje istniejącą funkcję
zgłaszania produktu i ceny dla UK zgodnie z polskim sposobem działania.
Nadal nie kopiujemy PLN do GBP ani produktu do wszystkich sklepów.

## Schemat i bezpieczeństwo wdrożenia

Nie dodano tabel ani kolumn. Zmieniono dopuszczalne wartości istniejących
ograniczeń oferty regionalnej. Migracja PostgreSQL jest wersjonowana
osobnym znacznikiem i idempotentna także po starszej wersji ograniczeń.
Nie przepisuje produktów, kont, polskich cen ani istniejących zamówień.

Próba na uprzednio wskazanej odizolowanej gałęzi Neon obejmuje migrację
dwukrotnie, zapis/odczyt zgłoszenia, właściwą wycenę opakowań oraz ukrycie
oferty po zmianie masy. Wynik: `approved_submission_price_pg=true`,
`rollback_verified=true`. Nie wykonano produkcyjnej migracji.

## Dowody testowe

- Regresja starej ścieżki po czasowym cofnięciu podłączenia: 4 failed
  w czterech wariantach autoflush/RETURNING. Po przywróceniu przechodzi.
- Skupiona partia katalogu i zakupów: 199 passed, exit 0.
- Rozszerzona partia zgłoszeń i izolacji krajów: 95 passed, exit 0;
  obejmuje porównanie dwóch sklepów, przełączenie, kupioną historię
  po zmianie ceny oraz idempotentne przeniesienie dwóch opakowań do spiżarni.
- Flutter: test zaakceptowanego opakowania odtworzył `false` zamiast `true`.
  Po dodaniu obsługi jawnego zakresu zgłoszenia 15 testów modelu i istniejącego
  ekranu katalogu przechodzi. Błędna waluta, nieoznaczony szacunek, brak masy
  i nieznany typ dowodu nadal nie włączają opakowania.
- Neon: test zakończył się exit 0, `passed=true`; brak trwałych zapisów
  i potwierdzona niezmienność wcześniejszych polskich danych.
- Pełny backend: **2787 passed**, 43 istniejące ostrzeżenia zależności/deprecacji,
  exit 0, 184,19 s (`uk-stage43-backend-final.log`).
- Pełny Flutter: **1086 passed**, exit 0, około 164 s,
  concurrency 2, bez pobierania zależności (`uk-stage43-flutter-final.log`).
- Analiza dwóch zmienionych plików Dart: `No issues found`, exit 0.
  Compileall, zgodność wersji oraz bezpośrednia kontrola 16 plików
  UTF-8/LF bez BOM i końcowych spacji: exit 0.
- Pełne `flutter analyze --no-pub --no-fatal-infos`: exit 0;
  0 błędów, 0 ostrzeżeń, 388 informacji/lintów w całym istniejącym projekcie
  (`uk-stage43-flutter-analyze.log`). Nie przedstawiamy tego jako braku
  jakichkolwiek uwag do całego kodu.

## Granice gotowości całego UK

Ta poprawka domyka istniejącą ścieżkę zgłoszenia i akceptacji ceny, a nie
gotowy brytyjski katalog startowy. Zawartość sześciu sprawdzonych powiązań
OFF i trzech referencji Open Prices nadal jest zestawem testowym — aplikacja
nie importuje go automatycznie przy uruchomieniu. Nie wolno utożsamiać
2787/1086 przechodzących testów z gotowością wszystkich danych do publikacji.

Pozostają: uzasadniona baza GBP i dostateczne początkowe powiązania
składników UK, przegląd dokumentów dla rynku oraz rzeczywiste testy natywne,
logowania i płatności/triala. W tej lokalizacji nie ma Android SDK; Windows
nie pozwala wykonać natywnego buildu iOS/Xcode. Nie uruchamiamy UK ani
zakupów na produkcji, nie tworzymy płatnych usług i nie przesyłamy kodu
na GitHub/Codespace w ramach tych prac lokalnych.

Nie testowano natywnego AAB/IPA ani rzeczywistych płatności/aparatu.
Wersja 1.0.69+270, flaga wyłączonego UK i wcześniejszy ZIP pozostają
niezmienione. Kolejna paczka wymaga aktualnego snapshotu Codespace.
