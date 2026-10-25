# Etap 44 — rzeczywista podstawa odniesienia cen GBP

24.10.2026. Przygotowanie lokalnych danych, bez aktywacji rynku ani importu do Neon.

Oficjalne [narzędzie ONS](https://www.ons.gov.uk/economy/inflationandpriceindices/articles/shoppingpricescomparisontool/latest)
udostępnia miesięczne średnie krajowe wraz z jednostką pomiaru. ONS wyraźnie
odróżnia je od cen konkretnego supermarketu i wskazuje ograniczenia próby.
To odpowiednia podstawa odniesienia dla wyraźnie oznaczanych szacunków,
nie cennik detalisty ani dowód dostępności składnika.

## Przygotowany materiał

Z odnośnika pobierania w oficjalnym osadzeniu ONS pobrano niezmieniony
`datadownload.xlsx`, SHA-256:
`e52e1d5f28122c70af428556717e4b6ff5f880272756d0e47bfe3dbdf8c95289`.

Odczytano arkusz `Average price`, kategorię `Groceries`, najnowszy okres
niedalszy niż 24.10.2026, osobno dla pary ID_DESC/CONSUMPTION_SEGMENT_CODE.
Wynik: 200 pozycji z okresu 2026-09, 199 cen i jedna rzeczywiście niedostępna.
Braku nie zamieniono na zero ani starszą cenę. Zachowano oznaczenie OGL-3.0
i przypisanie do Office for National Statistics zgodnie ze stroną źródła.

Wygenerowana projekcja JSON znajduje się w danych backendu. Nie zawiera
GTIN, wymyślonych SKU, sklepów ani deklaracji stanów magazynowych.
Plik XLSX pozostaje poza pakietem aplikacji. Ekstraktor offline ma `--check`,
odmawia przypadkowego nadpisania pliku i nie łączy się z żadną bazą danych.
Biblioteka arkuszy służy wyłącznie autorowi danych, nie jest nową zależnością
backendu uruchamianego na Renderze.

Czytnik Artifact Tool zgłosił błąd runtime podczas importu. Użyto dostępnego
czytnika Python w trybie read-only. Dodatkowo naprawiono wyłącznie sposób
odczytu błędnie zadeklarowanego zakresu A1; źródłowy workbook nie został
zmodyfikowany. Wynik porównuje się ponownie ze źródłem, a nie z samym sobą.

## Kontrolowane przeliczenie, jeszcze bez automatycznego wpięcia

Pomocnik `estimate_reference_quantity` wymaga dokładnej nazwy pozycji ONS
i jawnej zgodnej jednostki. Zachowuje miesiąc odniesienia oraz informację,
że wynik nie jest ceną sklepową ani dowodem wielkości opakowania.

- g/kg i ml/l przeliczane są tylko w obrębie tej samej wielkości fizycznej.
- `12 pack` jaj oznacza dwanaście sztuk, nie gramów ani mililitrów.
- `each` nie pozwala odgadnąć masy pojedynczego warzywa.
- Nie ma dopasowania nazw na podobieństwo. Mąka samorosnąca nie zastępuje
  mąki zwykłej, a cena gotowego dania nie zastępuje kosztu jego składników.
- Koszt dotyczy wskazanej ilości w miesiącu źródłowym, nie pełnego opakowania
  do kupienia. Nie dodaje mnożników sieci ani nie wskazuje najtańszego sklepu.
- Brak ceny, niezgodna jednostka, przyszły okres i nieprawidłowa ilość zwracają
  brak oszacowania. Nie tworzą fikcyjnego £0.
- Runtime czyta mały lokalny JSON; nie pobiera arkusza ani nie wykonuje HTTP.

To przygotowana warstwa odniesienia, nie zakończone zasilenie cenami zakupów.
Nie podmieniono źródeł ofert etapów 39–43 i nie przypisano średnich krajowych
do konkretnych sklepów. Do bezpiecznego wpięcia pozostają jawne powiązania
rodzajów składników oraz prawdziwe jednostki/opakowania użytych produktów.

## Dowody

- 22 testy przeliczeń i pochodzenia danych: passed, exit 0.
- Pełny backend po dodaniu warstwy odniesienia: **2809 passed**,
  43 istniejące ostrzeżenia zależności/deprecacji, exit 0, 145,67 s
  (`uk-stage44-backend-final.log`).
- Odczyt źródła i `--check` kontrolują rekordy, jednostki, okres, braki i SHA-256.
- Bez zmian Fluttera, schematu bazy, wyglądu i wersji. UK nadal wyłączone.

Osobna ograniczona próba uzupełnienia podstawowych składników OFF wykazała
503 dla czterech z sześciu zapytań tekstowych, pusty wynik dla mąki i
nietrafne gotowe produkty/sosy dla słowa eggs. Nie importowano ich jako jaj.
Próba alternatywnego wyszukiwania kategoriami v2 dała 200 dla cebuli oraz
503 dla jaj; również sama kategoria cebuli zawiera kimchi i przekąski.
Jest to dowód, że automatyczne przyjęcie pierwszego wyniku byłoby błędne,
nie dowód braku tych składników w Wielkiej Brytanii. Nie dołożono tych
prób ani pętli ponawiania do ścieżki użytkownika.

Pozostałe ograniczenia gotowości UK z etapu 43 nadal obowiązują. Nie przedstawiamy
tej projekcji jako działającego feedu cen, całego brytyjskiego katalogu ani
zakończonych testów na telefonie.
