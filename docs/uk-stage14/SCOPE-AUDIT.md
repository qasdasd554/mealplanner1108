# Zakres UK — audyt i korekta po uwagach właściciela, 21.10.2026

## Wiążący zakres

UK ma być adaptacją istniejącej aplikacji, nie nowym produktem.
Zachowujemy funkcje, strukturę, styl, kolorystykę, podział Standard/Premium
i model korzystania z zewnętrznych baz. Dopuszczone różnice: angielski UK,
sklepy, GBP, krajowe dane produktów i dostępność składników, lokalny kalendarz.
Kraj jest niezmienny, istniejące konta pozostają PL. Administrator ma wcześniej
zatwierdzony wybór rynku. Dopuszczone są jawne szacunki GBP i dostępność
krajowa zgłoszona w OFF, bez twierdzenia o stanie półki w konkretnej sieci.

**OFF działa na żądanie, tak jak w PL: Neon → źródło zewnętrzne → cache.
Nie wgrywać masowo całego katalogu UK ani świata.**

## Wycofany eksperyment

Wycofano nową ścieżkę pełnego katalogu OFF z zakładki Katalog, jej endpoint,
metodę serwisu i narzędzia masowego importu. Pliki ekranu produktów, serwisu
wyszukiwania i jego istniejących testów odtworzono z kopii sprzed tego
eksperymentu, zachowując ukończoną wcześniejszą lokalizację.
Nie było wdrożenia, zapisu pełnego zbioru do Neon ani aktywacji UK.

Analiza publicznego eksportu była wyłącznie lokalna:
4 825 952 rekordy źródłowe; 178 157 poprawnych rekordów UK,
178 155 różnych kodów. Dane przetestowano lokalnie, a 3000 publicznych
rekordów w gałęzi Neon uk-test w transakcji zakończonej rollbackiem.
Zweryfikowano zachowanie istniejących danych i tabel.
To nie stan produkcyjnej bazy i nie zobowiązanie do importu.

## Co rzeczywiście różni się względem polskiej podstawy

1. Kraj konta, filtr sklepów/produktów/przepisów, waluta i strefy czasu:
   są konieczną częścią zatwierdzonej adaptacji. Ceny PL nie są przepisywane
   jako GBP, a brak danych nie jest bezpłatnym produktem.
2. Etykiety, formularze, komunikaty i prompt AI otrzymują język konta.
   Identyfikatory diet, posiłków i jednostek API pozostają wspólne.
3. Dwa dodatkowe techniczne endpointy obsługują istniejące porównanie cen
   i zmianę sklepu listy w GBP. Nie dodano nowego przycisku. Przebieg PL
   nadal korzysta z dotychczasowej ścieżki planu. Różnica implementacji
   i jej zgodność semantyczna wymaga niezależnego przeglądu przed wydaniem.
4. Wspólne poprawki błędów zmieniają zachowanie także w PL:
   - komentarze nie omijają uprawnień prywatnego przepisu;
   - spóźniony wynik wyszukiwania/zmiany konta nie nadpisuje bieżącego;
   - blokada podwójnego zapisu/generowania i poprawne ponowienie po błędzie;
   - domyślna ilość opakowania w wariancie przepisu i walidacja zgodna z API;
   - kontroler dialogu nie jest usuwany przed końcem animacji;
   - parser gramatur odrzuca nieznane/niemetryczne jednostki zamiast
     zapisywać błędne gramy lub masę porcji jako całe opakowanie;
   - napis o trialu i oszczędności odpowiada rzeczywistej ofercie sklepu.
   Są to poprawki istniejących mechanizmów, nie nowe funkcje użytkowe.
   Nie należy przedstawiać ich właścicielowi jako samych tłumaczeń.
5. Zatwierdzone dopasowania przy małym ekranie/powiększonym tekście
   zachowują kolory i zwykły układ. Nie dodano nowego redesignu.

Nie zmieniono kodu weryfikacji płatności, statusu Premium, cennika produktów
IAP, limitów Standard/Premium, plików natywnych iOS/Android ani komunikatu
o nowym wydaniu. Numer pozostaje 1.0.66+267; UK_MARKET_ENABLED=False.

## Dowody i ograniczenia

- Inwentaryzacja AST wszystkich śledzonych routerów wykazała dwa nowe
  endpointy techniczne opisane powyżej, bez usuniętych dotychczasowych tras.
- Testy test_uk_scanner_parity.py: lokalne trafienie nie wywołuje OFF,
  brak trafienia wywołuje dotychczasowe źródło i zapis cache w tle;
  brak endpointu pełnego katalogu. Sprawdzono PL i GB.
- Pozostałe wyniki bieżącej weryfikacji zapisujemy w VALIDATION.md.

**To audyt głównego agenta, nie niezależny audyt subagenta.**
Istniejące subagenty zwracają limit użycia z komunikatem ponowienia o 17:15.
Nie ponawiano ich przed resetem i nie obchodzono limitu innym modelem.
Niezależny audyt, pełna zgodność funkcjonalna UK, pozostałe tłumaczenia,
dane sklepowe i testy natywne nadal nie są potwierdzonym wydaniem.

## Zasada dalszej pracy

Nie dodawać nowych funkcji, zakładek, trybów katalogu, kampanii ani innego
modelu przechowywania danych pod pretekstem UK. Przed odstępstwem potrzebna
jest decyzja właściciela. Narzędzia testowe i niezbędne wewnętrzne rozdzielenie
PL/GB nie mogą zmieniać dostępnych użytkownikowi funkcji ani zasad Premium.
