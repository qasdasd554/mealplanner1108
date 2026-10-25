# Etap 15 — kontynuacja UK bez nowych funkcji, 21.10.2026

## Kontrola zakresu

Obowiązuje [audyt etapu 14](../uk-stage14/SCOPE-AUDIT.md). UK nie jest
osobnym produktem: pozostają te same zadania, funkcje, uprawnienia Premium,
metody dodawania produktów i przepisów oraz dotychczasowa nawigacja.
Wygląd zwykłych ekranów i kolorystyka nie są przeprojektowywane.

Główny agent sprawdził techniczne ścieżki brytyjskiego porównania cen i
zmiany sklepu listy. Testy obejmują bieżące ilości zamiast regenerowania
przepisów, ręczne i połączone listy, już kupione opakowania, spiżarnię,
uprawnienia zaakceptowanego udostępnienia, atomowe odrzucenie niepełnego
koszyka, odczyt bez modyfikacji i ograniczoną liczbę zapytań. Nie powstały
nowe przyciski ani funkcje. Dwa endpointy techniczne pozostają adaptacją
istniejących działań do odrębnej waluty i danych sklepów, nie nową ofertą.

Niezależny przegląd subagenta pozostaje niewykonany z powodu wcześniej
zgłoszonego limitu. Nie obchodzono limitu innym modelem. Wynik głównego
agenta nie jest przedstawiany jako niezależny audyt ani gotowe wydanie UK.

## OFF wyłącznie na żądanie

W PL/GB zachowana kolejność: lokalny Product -> BarcodeProductCache ->
dotychczasowe źródło zewnętrzne i zapis cache w tle. Trafienie kompletne
nie wykonuje zapytania zewnętrznego ani odczytu całego katalogu OFF.

Naprawiona luka adaptacji UK: skan pobierał makro i nazwę, lecz gubił
już zwróconą przez OFF informację o sprzedaży w UK. W tym samym żądaniu
GB projekcja zawiera teraz countries_tags i metadane źródła. Zapis jednego
żądanego kodu następuje po odpowiedzi, w istniejącym cache faktów OFF.
Nie ma nowego żądania HTTP, pełnego importu, nowej tabeli ani workera.

Kraj konta/parametr cc nie jest dowodem dostępności. Dotychczasowy walidator
cache wymaga jawnego en:united-kingdom, prawidłowego GTIN i metadanych;
zapis nie tworzy produktu użytkownika, StoreProduct, ceny czy potwierdzenia
stanu półki w sklepie. Niezgodny GTIN nie otrzymuje cudzych danych kraju.
Źródłowe NaN/Infinity nie mogą wrócić przez dodatkowe metadane po oczyszczeniu
makro/gramatury. Brak możliwości zapisu faktów kraju nie cofa zapisanego
dotychczasowym sposobem cache makro i nie opóźnia odpowiedzi telefonu.

Nie twierdzimy, że wszystkie istniejące składniki systemowe mają już
potwierdzoną dostępność GB. Dokładne mapowanie i pokrycie danych UK nadal
wymagają sprawdzenia; podobna nazwa nie jest automatycznym odpowiednikiem.

## Kontynuacja tłumaczenia istniejących ekranów

- Preferencje składników: tytuły, wybór grupy, wyszukiwanie, puste/błędne
  stany, komunikaty zapisu/wyjścia, przycisk dotychczasowego Premium.
  Bez zmiany limitu 50, filtrowania approved, przenoszenia między grupami,
  payloadów identyfikatorów ani blokady Standard/wygasłego Premium.
- Zablokowani użytkownicy: tytuł, pusty stan, odblokowanie, komunikat
  z nazwą użytkownika i timeout. Bez zmiany ID, uprawnień i przebiegu.
- Kalkulator kalorii: formularz, aktywność, wynik, wybór celu, makro,
  walidacja i zapis. Jednostki kg/cm, identyfikatory female/male i aktywności,
  formuła serwera, proporcje makro, slider i zapis profilu bez zmian.
- Wszystkie 64 nowe teksty występują w pl, en i en_GB. Teksty polskie
  zachowane; błędy serwera preferencji wybierają język z kraju konta.

## Zmiany dopasowania — wyłącznie za osobną zgodą właściciela

Stark skierował naprawę na zachowanie czytelności i dotychczasowej hierarchii,
bez nowej grafiki, fontów produkcyjnych, animacji ani układu zwykłego ekranu.

- Wiersz makro zawija elementy, jeśli brakuje szerokości, bez zmniejszania
  tekstu lub zmiany wartości, kolorów i odstępów w pojedynczym wierszu.
- Trzy istniejące cele układają się pionowo przy wąskim kontenerze i
  powiększonym tekście. Standardowe trzy kolumny pozostają bez zmian.
- Nie zmieniono wyboru płci. Pierwsza hipoteza overflow była błędna;
  szczegółowy log wskazał sekcję makro, co ujawniono właścicielowi i
  wycofano niepotrzebny eksperyment. Zgody na rzeczywiste naprawy są osobne.

## Granice tego etapu

Wyniki i ograniczenia testów: [VALIDATION.md](VALIDATION.md).

Brak zmiany numeru 1.0.66+267, limitów Standard/Premium, zakupów IAP,
komunikatu wydania, konfiguracji natywnej, produkcyjnej bazy i wdrożenia.
UK_MARKET_ENABLED=False. Nie utworzono ZIP-a/AAB/IPA.

Pozostają pozostałe nieprzetłumaczone ekrany, treści systemowe, dane sklepowe
z prawdziwą proweniencją i oznaczonymi szacunkami GBP, testy natywne oraz
niezależny przegląd. Nie dodawać przy ich realizacji nowych funkcji.
