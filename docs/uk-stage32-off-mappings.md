# UK — etap 32: dostępność składników ogólnych, 23.10.2026

Prace lokalne po zamrożeniu wydania PL 1.0.69+270. UK pozostaje wyłączone.
Późniejszy test rzeczywistych danych i korektę ograniczenia marek opisuje
[etap 33](uk-stage33-real-seed-identity.md); poniżej zachowano historyczny zakres etapu 32.
Bez nowego ekranu, opcji użytkownika, zmiany wyglądu, płatnej usługi ani
pełnego importu OFF. Skanner nadal korzysta z dotychczasowego mechanizmu
Neon → źródło zewnętrzne → cache. Nie wykonano wdrożenia ani podbicia wersji.

## Przyczyna luki

Istniejący filtr UK rozpoznawał potwierdzenie kraju z OFF tylko przez dokładny
GTIN. Składniki ogólne z systemowych przepisów nie mają GTIN: samo tłumaczenie
nazwy ani podobny produkt nie mogły więc udostępnić tych przepisów w UK.
Nowy test wykazał, że nawet jawnie sprawdzone powiązanie nie było używane
przez filtr. Następnie ten sam przypadek przeszedł po jego podłączeniu.

## Zakres

- Mała addytywna tabela `off_ingredient_mappings`: ID składnika, kod istniejącej
  pozycji cache OFF, oryginalna nazwa/jednostka, skrót sprawdzonej wersji OFF,
  uzasadnienie i metadane przeglądu. Bez cen, makro, zdjęć i danych kontaktowych.
- Powiązanie nie dopisuje kodu do składnika, nie zastępuje go markowym SKU,
  nie kopiuje jego opakowania, miar ani wartości odżywczych.
- Wewnętrzna funkcja importu przyjmuje wyłącznie jawnie sprawdzone powiązania;
  nie wybiera ich przez podobieństwo nazwy, tłumaczenie czy odpowiedź AI.
  Semantyczną zgodność konkretnego produktu trzeba rzeczywiście sprawdzić.
  Nie ma nowego endpointu ani przycisku dla użytkownika.
- Aktualna rola i blokada administratora są odczytywane z bazy. Zatwierdzenie
  obejmuje maksymalnie 500 powiązań, wymaga czystej sesji, blokuje rekordy
  w ustalonej kolejności i waliduje cały zestaw przed zapisem. Savepoint chroni
  całą partię; commit pozostaje po stronie wywołującego.
- Dozwolone są wyłącznie zatwierdzone ogólne produkty systemowe bez autora,
  marki i kodu. Kodowane produkty nadal korzystają z dopasowania dokładnego GTIN.
- Zmieniona nazwa/jednostka/tożsamość składnika, odrzucony produkt lub inna
  wersja OFF unieważniają stare powiązanie. Nadal wymagane są aktualne dane
  OFF z oznaczeniem UK, prawidłowym adresem źródła i licencją ODbL.
- Sama niezmieniona tożsamość nie wymaga ręcznego przeglądu co miesiąc:
  odświeżenie tych samych faktów OFF zachowuje powiązanie. Dotychczasowy limit
  świeżości cache OFF (30 dni) pozostaje, bez wydłużania timeoutów i nowych zadań.
- Reguła działa przed paginacją katalogu oraz w zbiorczej kontroli produktów
  używanej przez szczegóły/generator. Jedno lokalne zapytanie dla wielu ID,
  brak dodatkowej sieci i N+1. Opcjonalny składnik nie wyklucza przepisu.
- Nie twierdzimy, że produkt jest na półce każdego sklepu. OFF potwierdza
  zgłoszenie sprzedaży w kraju, nie sklepowe ceny ani bieżący stan magazynu.
  Polskie filtrowanie i dotychczasowe dane nie zmieniają się.

## Weryfikacja i ograniczenia

Partia testów mapowań, dostępności OFF i etykiet składników AI: **153 passed**.
Obejmuje autoflush włączony/wyłączony, gramaturę, sztuki z zapisaną konwersją,
brak domyślnego 1 g, wiele źródeł dla jednego składnika, zmianę etykiety,
nieznaną tożsamość, świeżość, uprawnienia, paginację, rollback i liczbę zapytań.

Skrypt `backend/scripts/check_uk_branch.py` rozszerzono o rzeczywisty
PostgreSQL/asyncpg: utworzenie tabeli, powtórzenie importu, użycie powiązania
w filtrze i kontroli zbiorczej oraz unieważnienie po zmianie wersji OFF.
Test na udostępnionej odizolowanej gałęzi Neon przeszedł i potwierdził rollback
DDL/danych oraz niezmienność istniejących polskich rekordów. Nie dotyka produkcji.
Nie uruchamia aplikacji, poczty, AI ani procesów w tle. Dane próbne są syntetyczne,
nie są przygotowanym asortymentem UK ani cenami do publikacji.

Końcowy pełny backend po wszystkich zmianach kodu: **2241 passed,
43 ostrzeżenia zależności/deprecacji, exit 0** (120,85 s). Log:
`uk-stage32-backend-final.log`. Ponowiony końcowy test Neon: `passed: true`,
`generic_off_mapping_pg: true`, `existing_pl_rows_unchanged: true`,
`rollback_verified: true`, exit 0 (`uk-stage32-neon-final.log`).
Compileall zmienionych modułów/skryptu: exit 0. Kontrola whitespace zmian
w istniejących plikach: bez błędów. Nie zmieniano kodu po tych weryfikacjach.
Nie wykonywano buildu AAB/IPA ani testów telefonów w tym etapie.

Nie dodano jeszcze rzeczywistych sprawdzonych powiązań do produkcji.
Pozostają przegląd prawdziwych produktów i źródeł cen GBP, dokumentów,
testy natywne Android/iOS i konfiguracja sklepów. Testy automatyczne nie
potwierdzają gotowości do publicznego uruchomienia UK.

## Odzyskanie i wydanie

Kopie zmienianych wcześniej istniejących plików:
`../backups/uk-stage32-20261023-resume/`. Nowe pliki stanowią oddzielną warstwę.
Nie cofać całego drzewa do HEAD: zawiera wcześniejsze prace UK i poprawki PL.
Test gałęzi nie pozostawia tabeli ani danych, więc nie wymaga kasowania danych.
Przed przyszłą produkcyjną migracją sprawdzić ją na aktualnej kopii bazy.

ZIP 270 jest niezmieniony; ten etap nie należy do przekazanej paczki.
Ponownie sprawdzony SHA-256 ZIP-a:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
Przy kolejnym wydaniu trzeba dobrać aktualną podstawę Codespace i zaktualizować
komunikat aktualizacji tylko o faktycznie dostępne użytkownikom zmiany.
