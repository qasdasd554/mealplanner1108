# Etap 23 — angielskie treści systemowe, 22.10.2026

## Zakres danych

- `backend/app/data/system_recipes_en_GB.json`: 137 rekordów, czyli wszystkie
  112 wpisów `RECIPES_DATA` i 25 wpisów `AIRFRYER_RECIPES` z obecnego `seed.py`.
  Kluczem jest dokładna, oryginalna polska nazwa. Wartość zawiera wyłącznie
  angielskie `name`, `description`, `instructions` i `suggested_seasonings`.
- `backend/app/data/system_ingredients_en_GB.json`: 150 odrębnych, dokładnych
  nazw składników używanych przez te przepisy, z angielską etykietą wartości.
  To etykiety, nie mapowania tożsamości SKU, dostępności czy cen sklepowych.
- Tłumaczenie zachowuje kolejność przepisów, kroków i przypraw, liczby, czasy,
  temperatury, gramatury i jednostki fizyczne. Nie dodaje brakujących ilości.
  Polskie przecinki dziesiętne w tekście stają się angielską kropką.
- Użyto brytyjskich określeń: courgette, aubergine, coriander, prawns,
  yoghurt, tinned, cornflour, desiccated coconut i rapeseed oil.
  Szklanka nie została przeliczona na brytyjski cup ani gramy na mililitry.
  Produkty specyficzne, np. Silesian sausage i Kaiser roll, nie zostały
  zastąpione innym produktem tylko z powodu podobieństwa.

Nie zmieniono `seed.py`, przepisów użytkowników, polskich treści, odżywiania,
algorytmu gotowania, zdjęć, identyfikatorów ani uprawnień. Nie wykonano importu
do bazy, zewnętrznego płatnego tłumaczenia ani wywołań usługi AI. Samo dodanie
plików JSON nie zmienia odpowiedzi API — ich bezpieczna integracja i testy
warstwy prezentacji są osobnym zadaniem głównego agenta.

## Sprawdzenie danych

Odczyt źródłowego AST, bez importowania modułu i bez dostępu do bazy, potwierdził:

- dokładnie 137/137 kluczy przepisów w oryginalnej kolejności;
- dokładnie 150/150 kluczy składników, bez nadmiarowych lub pominiętych;
- brak powtórzonych kluczy JSON i kodowanie UTF-8 bez BOM;
- zgodność pól i ich typów oraz liczby kroków i proponowanych przypraw;
- identyczną kolejność wszystkich liczbowych tokenów w każdym polu po
  normalizacji przecinka dziesiętnego do kropki;
- brak polskich znaków diakrytycznych w angielskich wartościach.

Kontrola została powtórzona po ostatniej partii; exit 0. Nie jest to test
integracyjny renderowania ani potwierdzenie danych istniejącej bazy produkcyjnej.

## Granice i odziedziczone niespójności

To wierne tłumaczenie, nie modyfikacja receptur. Oryginały zawierają m.in.:

- określenie „roślinna” przy sałatkach zawierających fetę;
- deklarację „bez dodatku cukru” w omlecie z cukrem waniliowym;
- opis dania na parze jako „bez dodatku tłuszczu” mimo oliwy w końcowym kroku;
- „grzyby leśne” w tytule risotta, ale pieczarki w instrukcji;
- opisy i tytuły wspominające granolę lub szczypiorek, których kroki nie
  rozwijają, oraz opisy masła/ziół nie zawsze zgodne ze szczegółami kroków;
- ocenę ugotowania części mięsa wyłącznie na podstawie koloru.

Nie ukryto tych różnic przez zmienienie tylko wersji angielskiej. Ewentualna
korekta przepisu powinna być osobno zatwierdzona i spójna po polsku i angielsku.
Statyczny overlay nie potwierdza dostępności żadnego składnika w UK i nie
uprawnia do aktywacji rynku. Nadal nie przygotowano paczki ani wdrożenia.
