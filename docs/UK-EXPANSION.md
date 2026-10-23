# Wielka Brytania — prace lokalne, jeszcze nie wydanie

## Bieżący stan — 23.10.2026, po etapach 26–28

Przygotowano osobną paczkę naprawczą PL 1.0.67+268 na dokładnym eksporcie
3cf0c24 (nie publiczne wydanie UK). Zmiany etapów 25–28 są na razie lokalne,
nie w pierwotnej zamrożonej paczce. UK nadal wyłączone. Starsze checklisty poniżej
są historią, w szczególności pełny import OFF nie jest już wymaganiem.

Etapy 21–24 objęły istniejącą moderację produktów/przepisów/użytkowników,
lokalizację komunikatów serwera, zasoby iOS i pozostałe wspólne okna.
Poprawiono też odtworzone wyścigi żądań i operacje wykonywane podwójnie.
W eksporcie UK Deliveroo/Tesco są wyszarzone jako „Coming soon”, zgodnie
z decyzją właściciela; PL Jush/Glovo pozostają aktywne.
Etap 25: [komunikaty błędów providerów](uk-stage25-provider-errors.md).
Etap 26: [treści systemowe i wyszukiwanie](uk-stage26-system-content.md).
Etapy 27–28: [bezpieczeństwo sesji i język logowania](uk-stage27-28-auth-safety.md).

Do publicznego startu UK pozostają:

- Zweryfikowane mapowania składników ogólnych do prawdziwych produktów
  dostępnych w UK oraz jawne, uzasadnione ceny orientacyjne. Sam OFF nie
  potwierdza stanu półek konkretnego sklepu. Bez fikcyjnych GTIN/cen.
- Pozostałe lokalne komunikaty natywnych usług oraz przegląd dokumentów UK.
- Rzeczywisty build/test Android i iOS, aparatu, udostępniania i zakupów;
  konfiguracja produktów/ofert UK w sklepach należy do właściciela kont.

Mechanizm danych pozostaje na żądanie, jak w PL. Nie pobieramy pełnego OFF
ani nie włączamy eksperymentalnych funkcji. Aktualny styl jest zachowany.

## Priorytet 22.10.2026 — stabilność Androida

Rozbudowa UK została wstrzymana na czas diagnozy opinii o zamykaniu,
klatkowaniu i odświeżaniu aplikacji. [Raport i granice weryfikacji](audit/android-stability-20261022.md).
Nie utożsamiamy potwierdzonych błędów odświeżania i zasobów aparatu
z niepotwierdzoną przyczyną wszystkich zamknięć procesu.

## Aktualizacja 22.10.2026 — etap 20

[Zakres](uk-stage20/SCOPE.md): istniejące 30 porad w języku angielskim,
zatwierdzone korekty 12 polskich porad (temat otwierania słoika zachowany),
podtytuł startowy oraz e-maile weryfikacji/resetu hasła według kraju konta.
Bez nowych funkcji, zmiany wyglądu, wydania ani aktywacji UK.

## Aktualizacja 22.10.2026 — etap 19

[Etap 19](uk-stage19/SCOPE.md): wspólna partia tłumaczeń statystyk i ich
wniosków, rankingu autorów, komunikatów promocji i istniejącej wyłączonej
bramki reklamowej. Formuły, styl, jednostki, bramki Premium i identyfikatory
pozostają bez zmian. Test odtworzył i zabezpieczył spóźnioną odpowiedź
promocji po wylogowaniu. Nie dodano fikcyjnych ofert GBP ani źródła promocji UK.
[Weryfikacja i ograniczenia](uk-stage19/VALIDATION.md).

## Aktualizacja 22.10.2026 — etap 18

[Etap 18](uk-stage18/SCOPE-AND-VALIDATION.md): angielskie komunikaty istniejącej
spiżarni i dopasowywania przepisów, bez nowych funkcji ani redesignu. Testy
odtworzyły błędy wysokości kafelka, nakładających się nieudanych usunięć,
starych odpowiedzi wyszukiwania i zmiany zaznaczenia w trakcie oczekiwania.
Naprawy są wspólne dla PL/GB, z zachowaniem jednostek, ID i bramek Premium.
Końcowe wyniki: [raport weryfikacji](uk-stage18/VALIDATION.md).

## Aktualizacja 22.10.2026 — etapy 16–17

[Etap 16](uk-stage16/SCOPE-AND-PARITY.md): lokalizacja istniejących ekranów
znajomych, zaproszeń i powiadomień, bez nowych funkcji.
[Etap 17](uk-stage17/SCOPE-AND-VALIDATION.md): osobno zlecone poprawki list
zakupów i porównania cen PL/GB oraz zaakceptowane częstsze oferty Premium.
Raport jawnie opisuje ograniczenia weryfikacji nazw i starego modelu
tożsamości polskich wierszy bez oferty sklepowej. Bez wdrożenia, podbicia
wersji ani aktywacji UK. Wyniki dawnych etapów poniżej są historyczne.

## Korekta zakresu 21.10.2026

Aktualna decyzja właściciela: **te same funkcje i mechanizm OFF co w PL,
bez pełnego importu UK do Neon**. Eksperymentalny pełny katalog wycofano.
[Audyt zakresu i jawne różnice zachowania](uk-stage14/SCOPE-AUDIT.md).
Starsze notatki o potrzebie pełnego zasilenia OFF są historyczne i nie
stanowią już planu wdrożenia. UK nadal wyłączone, bez paczki/deploy.

Kontynuacja bez nowych funkcji: [etap 15 — zgodność i zakres](uk-stage15/SCOPE-AND-PARITY.md).
Obejmuje cache pojedynczych skanów UK, tłumaczenie istniejących ekranów
profilu/kalkulatora i osobno zatwierdzone dopasowanie przy dużym tekście.

Punkt wyjścia: GitHub main `3cf0c24d2ecfffa0b37a7e10d8f9b49c7d41d2f1`,
wersja opublikowana `1.0.66+267`. Gałąź lokalna:
`feature/uk-expansion-20261015`. Nie wykonano push ani deploy.

## Aktualizacja 21.10.2026 — etap 13

[Aktualny raport etapu 13](uk-stage13/VALIDATION.md): archiwum planów
i automatyczny tydzień w PL/en_GB, lokalne daty i komunikaty błędów,
naprawa retry, blokada podwójnego zapisu/generowania oraz odświeżanie
archiwum po zmianie konta. Po zgodzie właściciela pole dnia mieści tekst
przy 320 px / 150%, bez zmiany zwykłego stylu.

Pełne testy: 550 Flutter i 1261 backend, bez niepowodzeń.
To nadal prace lokalne, nie gotowe wydanie UK. Wersja 1.0.66+267,
rynek UK wyłączony; nie wykonano push/deploy ani AAB/IPA.
Wyniki wcześniejszych etapów poniżej są historycznym punktem odniesienia.

## Aktualizacja 21.10.2026 — etapy 11–12

Aktualny raport: [weryfikacja etapów 11–12](uk-stage11/VALIDATION.md)
i [OFF dla UK](uk-stage12/OFF-CATALOGUE.md). Starsze checklisty poniżej
opisują stan po kolejnych wcześniejszych etapach, nie cofają tych poprawek.

Doszły: odczyt sprawdzonych regionalnych ofert sklepu, kalendarz London/Warsaw,
lokalizacja profilu/komentarzy/Premium, ochrona prywatnych komentarzy oraz
osobny cache prawdziwych danych OFF dla wyszukiwania GB. Przeszedł test
PostgreSQL/asyncpg na odizolowanej gałęzi Neon z pełnym rollbackiem.

Backend: 1251 passed. Flutter: 518 passed, bez niepowodzeń. Właściciel
zatwierdził ograniczoną poprawkę Premium: nagłówek rośnie, gdy tekst tego
wymaga, a plakietka przechodzi pod tytuł tylko przy braku miejsca.
Zwykła wysokość 250 px, kolory, teksty i akcje są zachowane.
[Zakres i dowody responsywności](uk-stage12/PREMIUM-RESPONSIVE.md).
Analiza: 0 błędów i ostrzeżeń, 359 informacji/lintów.
To nie jest jeszcze gotowa bramka wydania.

OFF udostępnia ok. 197 tys. rekordów z oznaczeniem UK, ale nie skopiowano
całego tego zbioru do aplikacji. Działa przygotowana ścieżka wyszukiwania
i cache, a nie kompletny katalog wszystkich sklepów ani ich cen. Nie
poluzowano warunków dostępności składników publicznych przepisów UK.

Do zamknięcia pozostają m.in. pełne zasilenie i przeglądanie katalogu OFF,
mapowania składników do rzeczywistych SKU/cen, pozostałe teksty ekranów,
treść systemowych przepisów/porad, pozostałe komunikaty i dokumenty, zakres
kampanii krajowych oraz testy natywne i konfiguracja sklepów. UK pozostaje
wyłączone, wersja 1.0.66+267 bez zmian. Nie przygotowano paczki wdrożeniowej.

## Ustalenia zaakceptowane przez właściciela

- Wygląd, kolorystyka i funkcje użytkownika pozostają takie same.
- Dodajemy język angielski UK i lokalne sklepy oraz katalog produktów.
- Region urządzenia służy tylko przy zakładaniu konta. Nie jest dowodem
  miejsca pobytu. Nie odczytujemy GPS, nie dodajemy usług geolokalizacji IP.
- Dotychczasowe konta są przypisane do PL. Kraj konta nie jest edytowalny.
- Dopuszczone są wyraźnie oznaczone orientacyjne ceny w GBP. Nie wolno
  przedstawiać przeliczenia polskiej ceny jako potwierdzonej ceny brytyjskiej.
- Katalog UK pomija przepisy bez dostępnych lokalnie wymaganych składników.
  Brak opcjonalnego składnika nie wyklucza przepisu.
- Własne przepisy autora pozostają dostępne do edycji. Administrator
  zachowuje dostęp moderacyjny do prywatnych przepisów.
- Zatwierdzony wyjątek UI: wybór rynku tylko dla administratora.

## Kopia bezpieczeństwa

Przed edycją utworzono ZIP źródeł i pełny bundle Git w:
`../backups/uk-expansion-20261015-3cf0c24/`.
Plik `PRZYWROCENIE.md` zawiera sumy SHA-256 i instrukcję odzyskania do nowego
katalogu. Backup nie obejmuje Neon ani sekretów.

## Zaimplementowana podstawa

- Email, Google, ciche Google i Apple przesyłają region przy rejestracji.
  Serwer nadaje `country_code` tylko nowym kontom, nigdy przy kolejnym
  logowaniu/linkowaniu konta. Brak/nieobsługiwany region pozostawia PL.
- Blokada zmiany kraju: walidacja API, model ORM oraz trigger bazy.
- Sklepy mają `country_code` i `currency_code`; unikalność to kraj+nazwa.
  Lidl PL i Lidl GB mają inne ID, stany i ceny.
- Przygotowano 10 sieci: Tesco, Sainsbury's, Asda, Aldi, Morrisons, Lidl,
  Co-op, Waitrose, Iceland, Ocado. Angielskie działy są kategoriami
  nawigacyjnymi, a nie potwierdzonym planem alejek każdej placówki.
- Źródło potwierdzające nazwy sieci:
  https://www.gov.uk/government/statistics/food-statistics-pocketbook/food-statistics-in-your-pocket
  Nie jest to źródło cen, asortymentu ani dostępności w każdej placówce.
- Seed UK jest create-only. Nie zmienia ręcznych korekt, nie dodaje
  fikcyjnych produktów, cen ani dostępności.
- Izolacja sklepów działa w katalogu/API, profilu, generatorze i zmianie
  sklepu planu, tworzeniu/wznawianiu/scalaniu list i planów.
- Filtr przepisów UK pracuje w SQL przed paginacją: wymagane są jawne,
  aktywne, niewycofane powiązania składników ze sklepami UK. Obejmuje katalog,
  wyszukiwanie, znajomych, wybór/zamianę dań i generator.
- Pusta lista składników nie dowodzi dostępności przepisu w UK.
- Porównanie cen nie zestawia PLN z GBP, zachowuje trzy główne zapytania.
- Proponowane sklepy i cena zgłoszonego produktu mają rynek pochodzenia;
  moderacja nie może skopiować tej ceny do sklepu innej waluty.
- Polskie źródła promocji, odwracanie cen po wygaśnięciu i scraper mają
  jawny kontekst PL/PLN, również gdy w bazie istnieje drugi Lidl z UK.
- StoreProvider ignoruje odpowiedzi z poprzedniej sesji lub starego żądania.
- Administrator ma opisany wybór rynku katalogu; filtruje kolejki produktów
  i przepisów oraz listę przepisów użytkowników bez zmiany kraju konta.
- Wprowadzono standardowe Flutter gen-l10n/ARB, podstawowe teksty nawigacji,
  głównych skrótów i menu Dodaj w PL i en_GB oraz lokalizacje systemowych
  kontrolek. Polskie brzmienie przeniesionych tekstów zachowano.
- Język zalogowanego konta wynika z zapisanego kraju, a nie późniejszej
  zmiany regionu telefonu. Przełączenie lokalizacji nie zmienia klucza
  nawigatora ani tras, więc samo nie wylogowuje użytkownika.
- Dla flutter_localizations z obecnego SDK konieczne jest intl ^0.20.2;
  lock z lokalnego SDK rozwiązał intl 0.20.3 oraz jego zależności SDK.

## Drugi etap — 2026-10-16

- Na koniec drugiego etapu ARB zawierały 268 komunikatów w PL, en i en_GB, ze zgodnym
  pokryciem kluczy. To nie jest pełne tłumaczenie aplikacji.
- Zlokalizowano teksty czterech ekranów logowania/rejestracji/weryfikacji/
  odzyskiwania hasła oraz dwóch ekranów onboardingu/bonusu. Polski tekst,
  koszt punktowy i wartości wysyłane do API pozostają bez zmian.
- Uzupełniono etykiety głównego pulpitu, stany pobierania/pustego planu,
  podsumowanie dnia i istniejące kontekstowe podpowiedzi Premium.
  Treści samych porad kulinarnych pozostają do osobnego tłumaczenia.
- Lista przepisów, wyszukiwanie, filtry, sortowanie, menu dodawania i etykiety
  miniatur mają en_GB. Tytuły/treść samych przepisów nie są nadpisywane.
  Dieta, typ posiłku i trudność zachowują polskie identyfikatory protokołu;
  tłumaczone są wyłącznie widoczne etykiety.
- Dodano ścisłe formatowanie PLN/GBP i zastosowano je w porównaniu cen.
  Odpowiedź bez waluty pozostaje legacy PLN; mieszane/obce waluty są odrzucane,
  nie przeliczane. Brak potwierdzenia ceny nadal oznacza widoczny szacunek.
  Inne ekrany cen wymagają dalszych prac. Billing/IAP bez zmian.
- Przygotowano deterministyczny walidator propozycji katalogu UK: konkretne
  SKU, opakowanie g/ml, źródła, daty, cena GBP, jawny szacunek i stan oferty.
  Legacy StoreProduct nie zachowuje tej proweniencji i lokalnych opakowań,
  więc writer do niego jest celowo zablokowany. Nie dodano fikcyjnego asortymentu
  ani aktywnych produktów/cen UK. Szczegóły: `uk-stage2/catalog.md`.
- Po dodatkowej zgodzie właściciela poprawiono dopasowanie opcji dodawania
  przepisu: przy małej efektywnej szerokości plakietka Premium przechodzi pod
  nazwę, zamiast ściskać ją do zera. Standardowy układ, kolory i złote
  oznaczenia pozostają. Dotyczy też wspólnego menu Dodaj. Bez nowej animacji
  i bez pomniejszania dostępnościowej czcionki. Decyzja i dowody:
  `uk-stage2/ADAPTIVE-ACTIONS.md`.
- Nowe testy obejmują rzeczywiste interakcje filtrów, pełny onboarding GB
  ze zgodnymi identyfikatorami API, waluty/proweniencję, renderowanie akcji
  w obu motywach, 320/390 px i tekst 100/200%. Nie dodano nowego skilla,
  użyto istniejących skilli testowych, diagnostycznego i Starka.

## Trzeci etap — 2026-10-16

- Oddzielny model `RegionalProductOffer` przechowuje brytyjskie SKU,
  opakowanie g/ml, GBP, jawne szacunki, stan oferty i źródła wraz z datami.
  Nie nadpisuje polskiego Product ani StoreProduct. Model jest zarejestrowany
  w metadata; istniejący startup utworzy pustą, addytywną tabelę po przyszłym
  wdrożeniu. Nie uruchamiano tej zmiany na Neon.
- Dodano osobny importer zatwierdzonego katalogu. Ponownie sprawdza rolę
  i blokadę administratora w bazie, weryfikuje całą partię, mapowania oraz
  jednostki. Zapis jest idempotentny i objęty SAVEPOINT, ale bez commit:
  transakcją zarządza wywołujący. Nie ma nowego publicznego endpointu ani
  automatycznego importu; stary writer do StoreProduct pozostaje zablokowany.
- Kalkulator regionalnych ofert używa Decimal i pełnych opakowań lokalnego
  SKU, bez przyjmowania 100 g i bez utożsamiania g z ml. Weryfikuje źródła,
  fingerprint i aktualność danych; pomija nieaktualne/niedostępne oferty.
  Brak wiarygodnej oferty to brak wyceny, nie darmowe zakupy za £0.
  Wybiera najtańszą sumę pełnych paczek jednego SKU, nie miesza rozmiarów.
- Na koniec etapu 3 była to podstawa danych, jeszcze bez pełnego podłączenia.
  Ówczesny generator, listy i porównanie cen nadal miały legacy ścieżki
  StoreProduct. Trzeba jednocześnie podłączyć wybór SKU, utrwalanie
  opakowania/ceny, dostępność przepisów oraz ponowne przeliczanie i scalanie
  list. Nie wolno włączyć UK, zmieniając tylko jeden z tych konsumentów.
- Formularze ręcznego i AI dodawania przepisu oraz konfiguracja i widok
  planu mają angielskie etykiety, walidację, wyszukiwanie i stany dialogów.
  Wszystkie trzy ARB zawierają 397 zgodnych kluczy. Wartości API, koszty
  punktowe i polskie treści przepisów pozostają bez zmian. Samo tłumaczenie
  formularza nie sprawia jeszcze, że backend AI generuje przepisy po angielsku.
- Budżet w konfiguracji planu wynika z kraju konta i zweryfikowanego sklepu,
  nie z aktualnego regionu telefonu. Zachowano limit 8 osób, cel z kalkulatora
  albo 2000 kcal oraz przełącznik spiżarni; bez przeliczania walut.
- Naprawiono trzy odtworzone regresjami błędy planu: zbyt wczesne usuwanie
  kontrolera wyszukiwania podczas zamykania zamiany dania, użycie kontekstu
  zamkniętego dialogu po powolnym nieudanym DELETE oraz przepełnienie wiersza
  makro przy 320 px i tekście 150%. Układ i kolorystyka są zachowane.
- Szczegóły: `uk-stage3/REVIEWED-CATALOGUE.md`, `uk-stage3/PRICING.md`
  i `uk-stage3/PLANS.md`. Dane katalogowe w testach są syntetyczne;
  nie są gotowym, potwierdzonym asortymentem sklepów brytyjskich.

## Czwarty etap — rozpoczęty 2026-10-16, kontynuacja 2026-10-19

- GB używa sprawdzonych RegionalProductOffer w generatorze, wycenie oraz
  listach, bez polskiego default_quantity i bez zamiany g na ml. Wspólny
  agregator uwzględnia końcowy mnożnik przepisu dokładnie raz; brak przelicznika
  pozostaje jawnie nieznaną ilością, a nie fikcyjnym 100 g.
- Addytywna tabela snapshotu pozycji przechowuje kanoniczny produkt, lokalne
  SKU, gramaturę, potrzebną i kupowaną ilość, liczbę paczek, GBP oraz datę
  i źródło wyceny. Nie dodaje kolumn do starych pozycji ani nie przerabia
  polskich opakowań. Usunięcie oferty nie kasuje historycznej gramatury.
- Podłączono ponowne przeliczanie, zmianę sklepu, scalanie, ręczne dodawanie,
  zamienniki, synchronizację spiżarni i zakończenie zakupów. Ręczny dodatek
  ma osobny licznik: nie znika przy regeneracji i nie jest liczony dwa razy.
- Lista i porównanie koszyka składników planu odejmują tę samą potwierdzoną ilość spiżarni. Nieznany
  stan nie dowodzi pokrycia. Niepełny koszyk GB ma sumę null i nie może
  wygrać porównania; £0 jest prawdziwe wyłącznie przy pokryciu ze spiżarni.
- Na koniec etapu 4 porównanie odczytywało składniki planu, a nie aktualne, ręcznie zmienione
  pozycje listy. Odtworzono różnicę £3.75 na liście wobec £2.50 w porównaniu
  po ręcznym dodatku; techniczne plany po scaleniu/ręcznej liście mogą dać 404.
  Był to blokujący punkt następnego etapu; etap 5 dodaje osobną ścieżkę listy.
  Historyczne odtworzenie jest w PRICING-AVAILABILITY.md.
- Katalog SQL przed paginacją wymaga regionalnych ofert i podstawowych
  warunków świeżości. Szczegóły, generator i wycena dodatkowo sprawdzają
  pełne źródła, fingerprint i mapowanie SKU. SQL nie udaje weryfikacji hash.
- Lista zakupów i skrócony widok listy dania mają EN/GBP, jawny brak ceny
  i ilość lokalnej paczki. Odczyt współdzielonych list zachowuje ich walutę;
  różne waluty w osobnych zaakceptowanych listach nie są sumowane ani mieszane.
  Zapis nowej własnej listy nadal sprawdza rynek konta.
- Testy odtworzyły i zabezpieczają m.in. późną odpowiedź po zamknięciu okna
  zamienników, fałszywy sukces po nieudanej zamianie, utratę ręcznego dodatku,
  mieszanie stanów kupione/niekupione i podwajanie zapotrzebowania po spiżarni.
- Za osobną zgodą właściciela poprawiono wyłącznie kontrast tekstu/obramowania
  akcji na zielonej karcie najtańszego sklepu. Układ, tło i globalny motyw
  pozostają. Nowe etykiety dostosowują się do małej szerokości/dużego tekstu,
  bez pomniejszania ustawionej czcionki i bez redesignu.
- Szczegóły: `uk-stage4/SHOPPING.md`, `uk-stage4/PRICING-AVAILABILITY.md`
  oraz `uk-stage4/UI-DECISIONS.md`. To integracja kodu na danych testowych,
  nie zaimportowany rzeczywisty asortyment UK ani gotowe wydanie.

## Piąty etap — 2026-10-19

- Oddzielny endpoint porównuje aktualne pozycje listy GB: ręczne dodatki,
  listy techniczne i scalone, bez odczytywania starych składników planu.
  Dotychczasowy endpoint porównania planu, w tym PL, pozostał osobny.
  Publiczny identyfikator listy nadal oznacza `meal_plan_id`; nie wprowadzono
  drugiej, niezgodnej konwencji ID.
- Lista GB korzysta z nowej ścieżki GET oraz listowego PUT zmiany sklepu.
  PUT nie regeneruje dań, nie kasuje pozycji ani stanów kupione/spiżarnia.
  Metadane sklepu powiązanego planu są aktualizowane dla spójności, ale jego
  przepisy nie są przebudowywane. Po potwierdzonym sukcesie wraca odświeżona lista.
- Kupione pozycje zachowują zapisany koszt, sklep i fizyczne opakowanie we
  wszystkich porównaniach. Nowy sklep wycenia tylko pozostałe zakupy.
  Utrwalenie opakowania przeżywa zmianę sklepu, niezmienione przeliczenie,
  scalenie i usunięcie bieżącej oferty. Zmienione wymaganie już kupionej
  wygenerowanej pozycji wymaga korekty stanu zakupów zamiast zgadywania historii.
- Jawna część ze spiżarni nie jest odejmowana ponownie. Ręczne nieznane pozycje
  dają niepełną wycenę bez odznaki najtańszego sklepu. PUT odrzuca niepełny
  koszyk docelowy i chroni SAVEPOINT-em także błąd po pierwszym przeliczeniu.
- Zachowano właściciela/zaakceptowane udostępnienie. Polski odbiorca wspólnej
  listy GBP nie zmienia kraju konta ani waluty listy. Sprawdzenia waluty, ID
  odpowiedzi i sesji chronią przed fałszywym sukcesem po opóźnionym żądaniu.
- Testy obejmują prawdziwe żądania HTTP na SQLite i interakcje Fluttera,
  brak modyfikacji przy GET oraz ograniczoną liczbę zapytań dla 24 produktów.
  Obecny wygląd i motyw zachowane; zmieniono tylko kontekstowe etykiety akcji.
  Szczegóły i ograniczenia: `uk-stage5/CURRENT-LIST-COMPARISON.md`.

## Szósty etap — 2026-10-19

- Angielskie etykiety głównego ekranu produktów (Sklep/Katalog/Moje),
  wyszukiwania, statusów zgłoszeń, nagrody punktowej i informacji o cenach.
  Własne nazwy produktów i marek pozostają w oryginale.
- Angielski główny Dziennik, nagłówek daty, aktywność, nawodnienie i edycja
  ilości. Zmiana dnia nadal dotyczy obu providerów. Dotychczasowe polskie
  identyfikatory posiłków i miar w API/bazie nie są tłumaczone.
- Wspólny wybór ilości ma etykiety EN oraz tę samą fizyczną gramaturę/ml.
  Nie przeliczamy szklanki na brytyjski cup ani gramów na ml bez danych.
  Testy odtworzyły i zabezpieczają niezgodny wymiar porcji, podwójną
  szklankę i wartości NaN/Infinity. Nieznane makro ma kreskę, a nie pozorne 0.
- Poprawiono błąd zbyt wczesnego zwalniania kontrolerów okna aktywności;
  tę samą ochronę ma okno wody i edycji ilości. Komunikaty produktów
  przewijają się przy niedoborze miejsca, bez zmiany normalnego układu.
- Cena zgłoszenia zachowuje kraj źródła. Legacy StoreProduct jawnie
  pozostaje PLN i nie może być pokazany jako cena GBP w brytyjskim sklepie.
  To zabezpieczenie, nie integracja legacy endpointu ze zweryfikowanymi SKU UK:
  ten katalog i rzeczywiste dane nadal wymagają uzupełnienia.
- Szczegóły, testy i ograniczenia: `uk-stage6/LOCALISATION.md`.

## Siódmy etap — 2026-10-19

- Angielskie etykiety dodawania wpisu do Dziennika: zakładki, wyszukiwanie
  przepisów, podsumowanie ilości i wspólny wybór z katalogu. Nazwy autora
  pozostają w oryginale, a API zachowuje polskie identyfikatory posiłków/miar.
- Lokalizacja sterowania skanerem pojedynczym/seryjnym, stanów wyników,
  podglądu Premium i wyboru wielu miejsc zapisu. Wspólne potwierdzenie całej
  serii nadal obejmuje spiżarnię, Dziennik i katalog, bez zmiany uprawnień.
- Naprawiono nadpisywanie nowszego wyszukiwania starszą odpowiedzią,
  zbyt wczesne zwalnianie kontrolera oraz utratę nieprawidłowo wpisanego GTIN.
  Ręczny kod można poprawić w tym samym oknie. Brakujące/błędne makro nie
  udaje zera i nie powoduje awarii renderowania wyniku seryjnego.
- Testy chronią skończoną i dodatnią gramaturę opakowania oraz poprawne
  przekazanie makro i jednostek. Zachowany starszy ręczny formularz dostał
  walidację liczb i obsługę przecinka; nie dodano nowego wejścia do niego.
- Plakietka podglądu Premium mieści się przy 320 px i większym tekście,
  w obecnym stylu. Sprawdzono rendery PL/EN i jasny/ciemny motyw.
- Szczegóły i ograniczenia: `uk-stage7/DIARY-BARCODE.md`.

## Ósmy etap — 2026-10-20

- Lokalizacja formularza dodania/edycji produktów oraz odczytu etykiet
  i potwierdzenia danych ze zdjęć. GBP wynika z rynku, a podpowiedzi PLN
  nie są przemianowywane na ceny brytyjskie.
- Naprawy jednostek g/ml i starego opakowania bez metadanych, danych
  pozostających po poprzedniej podpowiedzi/skanie i spóźnionych wyników.
  Nieznana gramatura oraz makro pozostają nieznane, a źródłowe ułamki nie
  są zaokrąglane do fałszywego zera przed zapisem.
- Walidacja pól, odczyt zdjęć z odzyskaniem po błędzie, zachowanie wyboru
  sklepów i dopasowanie kontrolek do małej szerokości/większego tekstu.
- Szczegóły zakresu i dowodów: `uk-stage8/PRODUCT-FORMS.md`.

Kod pozostaje lokalny. Wersja nadal `1.0.66+267`, UK wyłączone. Tekstu
powiadomienia o aktualizacji nie zmieniono tak, aby obecnemu wydaniu
przypisywał niegotowy rynek. Przy paczce wydania należy podnieść wersję
i dopisać faktycznie wydawane zmiany, po weryfikacji świeżego Codespace.

## Dziewiąty etap — 2026-10-20

- Wyszukiwanie OFF po kodzie i nazwie oraz odczyt etykiety otrzymują kontekst
  zapisanego kraju konta. Dla GB używane są uk/en i angielskie nazwy,
  bez zmiany kraju podczas podróży lub przez parametry zapytania klienta.
  Usługi w aplikacji obejmują skan pojedynczy/seryjny i formularze produktów
  oraz składników. Tekstowy cache OFF rozdziela PL i GB.
- Widełki historycznych cen PLN są ukrywane w odpowiedziach GB z każdego
  źródła, także od starszego backendu. Nie udają szacunków GBP ani dostępności
  w sklepie UK. Wspólny GTIN/cache może zachować oryginalną nazwę produktu.
- Naprawiono odtworzone błędy: surowe makro na porcję odczytywane jako na 100,
  przejmowanie wielkości opakowania bez jego jednostki oraz czytanie nieznanej
  jednostki jako gramów. Jawny metryczny odpowiednik etykiety pozostaje
  użyteczny; brak danych nie staje się 100 g ani fikcyjnymi zerami.
- Parser odrzuca także ujemne/zerowe, niefinitywne i zbyt duże opakowania
  oraz fragmenty notacji naukowej. Kontrola działa po przeliczeniu jednostek.
  Nie dodaje konwersji g/ml przez zgadywaną gęstość.
- Nie zwiększono liczby żądań ani timeoutów skanera. Kompletne trafienia
  lokalne nadal omijają źródła zewnętrzne; fallbacki pozostają ograniczone.
  Nie dodano AI do zwykłego skanowania ani nie zmieniono wyglądu.
- Szczegóły kontraktu, źródeł i ograniczeń: `uk-stage9/EXTERNAL-LOOKUP.md`.
  To nie gotowy brytyjski asortyment ani uruchomienie UK. Bez paczki, zmiany
  wersji, DDL produkcyjnego, nowych zależności czy wdrożenia.

## Dziesiąty etap — 2026-10-20

- Generowanie/import i edycja AI przyjmują kontekst kraju z konta; GB używa
  brytyjskiego angielskiego w nowej treści. Kanoniczne identyfikatory API,
  nazwy produktów, marki i ID nie są przemianowywane. Worker ponownie czyta
  kraj użytkownika; payload nie może go zastąpić. Powiadomienia gotowości
  i błędy importu/edycji mają EN, bez zmiany kosztów i uprawnień.
- Szybki import prawidłowego schema.org pozostaje bez dodatkowego AI oraz
  z oryginalną autorską treścią strony. Nieobsługiwana miara, np. oz, nie
  może być zapisana jako liczba sztuk po przybliżonym dopasowaniu produktu.
  Taki przypadek korzysta z istniejącego fallbacku AI, a nie zgadywanej masy.
- Zlokalizowano ramę szczegółów przepisu, warianty składników i edycję AI
  oraz zwykłe akcje właściciela/ulubionych/listy/zdjęć. Nie tłumaczymy
  automatycznie zapisanej nazwy, opisu, instrukcji lub składników autora.
  ARB mają po 814 zgodnych kluczy. Komentarze, moderacja i inne obszary nadal
  wymagają lokalizacji; nie oznacza to ukończenia całego języka angielskiego.
- Odtworzono i naprawiono usuwanie kontrolera przed końcem animacji dialogu,
  domyślne 100 opakowań w edytorze wariantu, nieprawidłowe ilości i spóźnione
  wyniki wyszukiwania. Walidacja zachowuje wpis i odpowiada istniejącym
  limitom API; Escape/Tab/Enter mają testy regresyjne.
- Po dwóch osobnych zgodach właściciela kafelki makro dostają większą
  wysokość tylko przy braku miejsca na tekst, a napis przycisku listy zakupów
  może się wtedy zawinąć. Zachowano dwie kolumny, styl, kolory i zwykły układ.
  150% to test powiększonej czcionki, nie zmiana domyślnego tekstu.
- Kontrola Stark UX obejmuje utrzymanie danych przy błędzie, czytelne koszty,
  focus/klawiaturę i render małego ekranu. Cztery rendery PL/EN jasny/ciemny
  320x740/150% przeszły po naprawie. Nie zastępują fizycznego iPhone/Androida.
- Szczegóły i ograniczenia: `uk-stage10/RECIPE-LOCALIZATION.md`.
  Bez wdrożenia, SQL, nowej biblioteki, aktywacji UK i zmiany numeru wydania.

## Nie włączać UK przed ukończeniem

`UK_MARKET_ENABLED` domyślnie jest `False`. Nie ustawiać tej flagi na
Renderze podczas tych prac. Nowe konta GB nie są przepisywane po cichu na
PL; rejestracja GB otrzyma 503 do czasu aktywacji rynku. Istniejące konta
mogą nadal logować się z telefonu ustawionego na dowolny region.

Do wykonania przed testem brytyjskim:

1. Uzupełnić angielskie teksty pozostałych ekranów, formularzy i komunikatów
   backendu/providerów. Lokalizacja obejmuje już auth, onboarding, główny
   pulpit, listę/filtry, formularze tworzenia przepisów, konfigurację/widok
   planu, główną listę zakupów i porównanie cen, główne produkty/Dziennik
   oraz wspólny wybór ilości, dodawanie wpisu i podstawowe ścieżki skanowania,
   oraz formularze zgłaszania produktów/OCR, ale nie całą aplikację.
   Szczegóły przepisu i generowanie AI są podłączone w etapie 10, ale
   komentarze, moderacja, profil, Premium, archiwum i automatyzacja planów
   oraz pozostałe dynamiczne błędy serwera wymagają dalszej pracy.
2. Uzupełnić model regionalny rzeczywistymi, sprawdzonymi SKU, gramaturami,
   nazwami składników, mapowaniami produkt→sklep i szacunkami cen GBP.
   Importer i integracja kalkulatora są przygotowane, ale nie ma jeszcze
   gotowego zweryfikowanego zbioru ani panelu zarządzania cenami/SKU UK.
   Katalog sklepu w ekranie produktów nadal korzysta z legacy endpointu PLN;
   niezgodna waluta jest blokowana, a nie przemianowywana na GBP.
   Potrzebne jest także mapowanie lokalnych działów produktów — same działy
   nawigacyjne nie dowodzą, do której alejki należy konkretna oferta.
   Sama obecność produktu w OFF nie dowodzi dostępności w konkretnej sieci.
   Przed aktywacją trzeba również podłączyć automatyczne reakcje na wycofanie
   regionalnej oferty. Porównanie aktualnej listy jest podłączone w etapie 5.
   Obecny generator
   nie gwarantuje twardego limitu budżetu — jest to istniejące ograniczenie PL/GB.
3. Przetłumaczyć systemowe przepisy i porady z zachowaniem oryginałów;
   nie nadpisywać oryginalnych treści autora przepisu użytkownika.
4. Dokończyć prezentację GBP we wszystkich widokach: plan, zakupy, produkty,
   promocje, zgłoszenia, porównanie cen. Nie wystarczy zamienić symbolu zł na £.
5. Przygotować brytyjskie źródła promocji i trwale oznaczyć kraj ofert/zadań.
   Obecny polski skaner nie tworzy promocji GBP. W kontekście UK administrator
   widzi informację o braku skonfigurowanych źródeł zamiast polskich przycisków.
6. Parametry OFF i kontekst OCR są podłączone w etapie 9. USDA pozostaje
   źródłem identyfikacji dokładnego GTIN, nie dowodem lokalnej dostępności.
   Pozostają pozostałe miary/etykiety, format dat oraz strefy czasowe Dziennika,
   limitów i automatyzacji; brak danych fizycznych nie pozwala zgadywać g/ml.
7. Uzupełnić języki/teksty uprawnień natywnych iOS/Android, tłumaczenia e-maili,
   push, pomocy i dokumentów; sprawdzić opis przechowywanego regionu w polityce
   prywatności. Nie wdrażać niezatwierdzonych zmian praktyk danych.
8. Przetestować migrację na odizolowanej gałęzi Neon przez połączenie direct.
   Testy SQLite i kontrola emitowanego SQL nie zastępują wykonania DDL PostgreSQL.
9. Pełne testy na fizycznym iPhone/Androidzie, test rzeczywistych lokalnych
   etykiet, kalendarza, wznowienia sesji, zakupów/triala i lokalnych płatności.
10. Przygotować lokalizacje stron sklepów i cen IAP; zweryfikować wydanie
    na aktualnym ZIP-ie Codespace. Podnieść wersję dopiero przy paczce wydania,
    a wtedy zaktualizować również powiadomienie o aktualizacji.

## Rollback

Nie było produkcyjnej migracji ani wdrożenia. Samo przywrócenie kodu nie
odtwarza danych. Po przyszłej aktywacji UK cofnięcie do starego kodu,
który nie rozdziela krajów, wymaga osobnego planu danych/backupów: samo
wyłączenie flagi nie usuwa istniejących sklepów i kont GB. Nie kasować
ich automatycznie i nie przepisywać użytkowników do PL.

## Zakres dowodów testowych

Weryfikacja bazowa 2026-10-20, po integracji dziesiątego etapu
(przed zmianami i wynikami etapów 11–12 opisanymi na początku dokumentu):

- `python -m pytest tests -q` z katalogu backend: **1124 passed**,
  37 ostrzeżeń zależności/deprecacji, exit 0 (41.46 s).
- `flutter test --no-pub`: **481 passed**, exit 0 (60 s).
- Etap 9 dodaje 94 przypadki backendu i 40 Fluttera; osobny zestaw skanera,
  kontekstu konta i danych Dziennika: 59 passed. Parser, podstawę makro
  i parowanie wielkości/jednostki sprawdzono cyklami czerwony → zielony.
- Etap 10 dodaje 49 przypadków backendu i 29 Fluttera: 23 widgetowe i 6
  dodatkowych granic ilości. Cztery rendery PL/EN, jasny/ciemny, 320 px/150%
  przeszły; Tab/Enter/Escape i walidacja ilości mają interakcyjne regresje.
- `flutter analyze --no-pub --no-fatal-infos`: exit 0,
  **0 błędów, 0 ostrzeżeń**; pozostało 326 informacji/lintów.
- `flutter gen-l10n` w etapie 10: exit 0.
  Bieżący test pokrycia kluczy PL/en/en_GB oraz testy tłumaczeń
  i niezmienności języka konta przeszły. ARB zawierają
  po 814 zgodnych kluczy, ale nie jest to jeszcze pełne tłumaczenie aplikacji.
- `git -c core.autocrlf=false diff --check`: exit 0.
- Formatowanie 14 plików Dart etapu 10: 0 zmian; compileall backendu: exit 0.
- Logi bieżącej integracji: `uk-stage10-backend-tests.log`,
  `uk-stage10-flutter-tests.log`, `uk-stage10-flutter-analyze.log`.
- Pliki motywu, Android/iOS i weryfikacji zakupów nie były zmieniane.
- Weryfikacja SHA-256 ZIP/bundle backupu ponowiona, sumy zgodne.
- Nie budowano natywnego AAB/IPA, nie testowano realnego PostgreSQL/Neon.
- Dodatkowy render komponentu po załadowaniu fontu MaterialIcons: 8/8 testów,
  PNG jasny/ciemny 320 px/200% sprawdzone wizualnie. Jest to render testowy
  z lokalną czcionką, nie dowód działania VoiceOver/TalkBack czy telefonu.
- Render etapu 4: sprawdzono jasną/ciemną kartę porównania opakowań oraz
  listę z ceną i bez ceny przy 320 px/150%. Tekst nie jest ucinany, a przycisk
  zmiany sklepu mieści się i ma kontrast testowany >=4.5:1. To PNG z testu,
  nie natywne zrzuty. Ogólna kolorystyka kart i motyw pozostały bez redesignu.

Artefakty lokalne `uk-*.log` i obrazy z testów w `docs/audit/evidence`
oraz `docs/uk-stage*/evidence`
nie są częścią planowanej paczki aktualizacji. Część zmienionych plików
znormalizowano do UTF-8/LF bez BOM; różnice samych końców linii nie są
zmianą logiki. Przy przyszłym pakowaniu wymagana jest świeża, dokładna
kopia Codespace, nie wyłącznie SHA z GitHuba.

Testy backendu używają lokalnego SQLite/moków. Nie wykonują zapytań do Neon.
Badanie DDL PostgreSQL sprawdza treść emitowanych poleceń, nie wykonanie
na realnym serwerze. Testy Fluttera nie potwierdzają natywnego buildu AAB/IPA.
Nowy selektor ma testy uprawnień, przełączania, stanu zajętego i szerokości
320 px z tekstem 200% w obu motywach. Bez redesignu ekranu użytkownika.
