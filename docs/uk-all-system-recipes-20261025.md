# UK: wszystkie przepisy systemowe — 25.10.2026

## Zakres

Angielski katalog i generator planów obejmują wszystkie **137 przepisów
systemowych**, zamiast wcześniejszych 19 spełniających filtr dostępności UK.
Używane są istniejące identyfikatory, tłumaczenia i zdjęcia. Nie powstają kopie
przepisów w Neon; przepisy użytkowników nie są tłumaczone ani kopiowane.
Ilości, składniki i wartości odżywcze przepisów pozostają bez zmian.

Przyczyną małego katalogu był brak dowodów dostępności części składników w UK,
a nie brak tłumaczeń. Pozostawiono kontrolę dostępności zamiast wyłączać ją
dla całych przepisów lub zastępować ich składniki innymi produktami.

## Dane i ograniczenia

- 148 różnych wymaganych składników ma pokrycie na dzień weryfikacji.
- Zachowano 31 wcześniejszych referencji i dodano 120: 116 sprawdzonych
  rekordów produktu OFF API v3 z oznaczeniem UK oraz 4 referencje oficjalnych
  katalogów sklepów. Trzy wcześniejsze referencje nie są wymagane przez te
  przepisy, stąd łącznie 151 referencji.
- Rekordy OFF zachowują prawdziwe daty pobrania, kod kreskowy i fingerprint.
  Dane są przypięte sumą SHA-256 i oznaczone ODbL-1.0 z odnośnikiem atrybucji.
- Referencje sklepowe nie udają obserwacji OFF i nie tworzą danych OFF w bazie.
  Są ograniczone do istniejącego, zatwierdzonego, systemowego składnika o dokładnym
  identyfikatorze, nazwie i marce; nie przechodzą na podobnie nazwany produkt autora.
- Dowód sprzedaży w kraju nie oznacza bieżącego stanu magazynowego każdej sieci.
  Nie przenosimy między produktami cen, gramatur, alergenów ani makroskładników.
- Nie pobrano całego katalogu OFF i nie dodano nowej usługi, zadania ani migracji.
  Plik nowych referencji ma około 534 KB i jest częścią backendu, nie importem do Neon.

Obowiązuje dotychczasowe okno ważności dowodów: **30 dni**. Rozszerzone referencje
OFF korzystają z istniejącego ograniczonego mechanizmu odświeżania znanych kodów.
Cztery referencje sklepowe nie mają automatycznego odnawiania: po 30 dniach trzeba
ponownie sprawdzić źródła i zaktualizować przypięty zestaw danych. Sam upływ czasu
nie może odświeżać daty dowodu. Bez ponownej weryfikacji część przepisów może
ponownie wypaść z filtra UK.

## Cztery źródła sklepowe

- Śmietana 30%: [Tami, Slovakia Foods UK](https://www.slovakia-foods.co.uk/smot-slah-trv-30-250ml-tami-box-27pcs.html).
- Świeża szałwia: [Waitrose Cooks' Ingredients Sage](https://www.waitrose.com/ecom/products/cooks-ingredients-sage/086111-43939-43940).
- Żółta papryka: [Tesco Yellow Peppers Each](https://www.tesco.com/shop/en-GB/products/258905427).
- Proszek budyniowy waniliowy: [Fresh, Slovakia Foods UK](https://www.slovakia-foods.co.uk/puding-v-prasku-s-vanilkovou-aromou-40g-fresh-box-30pcs.html).

## Weryfikacja

- Pełny backend: **3412 passed**, 45 ostrzeżeń, 382,06 s.
  Log: `uk-all-system-recipes-backend-full.log`.
- 150 nowych przypadków regresyjnych: dostępność wszystkich 137 przepisów,
  tłumaczenia, paginacja 30/30/30/30/17, rzeczywisty plan 7 dni po 3 posiłki,
  izolacja produktów użytkowników, nieważne/przyszłe dowody i ochrona danych.
- Testy Flutter komunikatu aktualizacji, zdjęć i autora: **7 passed**.
  Log: `uk-all-system-recipes-flutter.log`.
- Flutter analyze: brak błędów i ostrzeżeń; 385 uwag informacyjnych.
  Log: `uk-all-system-recipes-analyze.log`.
- Kontrola etykiet systemowych: 137 przepisów i 390 składników; ilości bez zmian.
- Komunikat aktualizacji ma nowy punkt PL/EN o całym katalogu systemowym.
- Nie wykonano w tym etapie natywnego buildu AAB/IPA, testu na telefonie ani
  wdrożenia na produkcję. Testy backendu korzystały z lokalnych baz testowych.

SHA-256 kanonicznego JSON nowych referencji:
`7d0f75bd3a12d891a2b9ee480bd69933d0fa71406a7d1825ea007746be5cc2df`.

## Stan wdrożenia

Zmiany są wyłącznie lokalne. Nie zmieniono opublikowanego ZIP-a 1.0.71+272
(`396705366ea7f38f8f13680b9c7bd8be25eb31dc65f7b7261b54ae3e37bec296`),
który nie zawiera tego rozszerzenia. Kolejną paczkę trzeba przygotować względem
aktualnego źródła Codespace i z kolejnym wolnym numerem buildu.

Kopia plików sprzed tego etapu: `../backups/uk-all-system-recipes-20261025/`
(względem katalogu repozytorium). Zmiany nie dotykały produkcyjnej bazy.
