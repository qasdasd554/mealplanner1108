# Generowanie przepisów, autor i prośba o opinię — 23.10.2026

## Mechanizm składników

Problem był ogólny: zapis AI wymagał dopasowania każdego składnika do już
istniejącego katalogu. Nie ograniczał się do wody, soli czy schabu.

1. Najpierw dopasowujemy rzeczywiste składniki w Neon, bez zamieniania ich
   na całe gotowe dania. Istotne określenie „z kością” nie znika przy dopasowaniu.
2. Brakujące nazwy wyszukujemy w zewnętrznym katalogu OFF, na żądanie,
   z deduplikacją zapytań, maksymalnie trzema równoległymi wyszukiwaniami
   i ograniczonym czasem oczekiwania. Bez pobierania całego OFF do Neon.
3. Produkt z pasującą tożsamością i kompletnymi, skończonymi wartościami
   odżywczymi zapisujemy jako współdzielony. Zachowujemy źródło i licencję;
   nie tworzymy fikcyjnej ceny, dostępności w sklepie ani masy opakowania.
4. Gdy danych nadal brakuje, zgodnie z decyzją właściciela zapisujemy cały
   przepis i wszystkie ilości. Produkt bez danych jest prywatny, przypisany
   do autora, ze statusem pending. Nie otrzymuje fikcyjnego makro ani GTIN.
5. Nieznane makro ma w API null, nie zero. Ekran przepisu pokazuje brak
   danych, Dziennik nie zapisuje automatycznie nieznanych wartości jako zer,
   a generator nie używa takiego przepisu do bilansowania celu kalorycznego.
   Właściciel może uzupełnić produkt lub zastąpić składnik w przepisie.
   Edycja własnego produktu odświeża wcześniej niepełne sumy przepisu.
6. Brak informacji o alergenach nie oznacza bezpieczeństwa dla alergika.
   Automatycznie wyszukany produkt bez potwierdzenia alergenów nie przechodzi
   filtra planu dla osoby z zadeklarowanymi alergiami.

Ten sam resolver obsługuje tekst, zdjęcie, link oraz edycję AI. Każdy zapis
zachowuje komplet składników; punkty pobierane są według istniejących zasad
dopiero przy udanym zapisie. Automatyczne uzupełnienie katalogu nie daje
nagrody za zgłoszenie produktu użytkownikowi. Nie wprowadzono migracji SQL.

## Autor bez przeskoku

Lista przepisów zawiera lekki podgląd autora pobrany jednym batchem na stronę,
bez adresu e-mail, hasła czy dużego zdjęcia profilu. TikTok nadal wymaga
aktywnego Premium. Szczegóły pobierane są raz; nie odtwarzają widoku ani
pozycji przewinięcia. Starsze linki bez podglądu autora mają stan wczytywania
i ponawiania zamiast kompletnej strony, do której później doskakuje autor.
Nie stwierdzono, że ta zmiana wyjaśnia wszystkie zgłoszone awarie Androida.

## Prośba o opinię — UX

Stark UX: cel to dobrowolna, uczciwa ocena po doświadczeniu wartości aplikacji.
Wzorzec: natywna prośba o ocenę, nie dodatkowy ekran sprzedażowy. Bez ankiety,
punktów, wybierania zadowolonych użytkowników czy zachęty do konkretnej oceny.

- Dopiero po dwóch udanych czynnościach w danej sesji konta.
- Osiem sekund bez kolejnej takiej czynności; krótkie okno okazji do 2 minut.
- Nie podczas formularza, klawiatury, aparatu, generowania planu, innej trasy,
  okna Premium, w tle ani po zmianie konta/sesji.
- Najwyżej jedno wywołanie natywnego API w sesji, dodatkowo backendowy limit
  10 dni na konto i zabezpieczenie przed konkurencją dwóch urządzeń.
- Nie nakładamy automatycznej oferty Premium tuż po wywołaniu prośby o ocenę.
  Dotychczasowa rezerwa po niedawnej ofercie Premium pozostaje zachowana.

Wygląd, treść, możliwość pominięcia i rzeczywiste wyświetlenie okna kontroluje
Google/Apple. Wywołanie API nie potwierdza wystawienia opinii. Nie ma gwarancji
pokazania okna co 10 dni ze względu na dodatkowe limity sklepów. Natywnego
okna nie renderowano w tutejszych testach widgetowych.

## Weryfikacja i granice

Regresje obejmują wszystkie trzy źródła AI, PL/GB, edycję, izolację właścicieli,
ponowne użycie produktu, odrzucanie nierzetelnych danych dostawcy, timeout,
brak podwójnych zapytań, prawdziwe zera soli/wody, uzupełnienie makro i UI
320 px/czcionkę 150%. Testy używają syntetycznych odpowiedzi, lokalnej bazy
SQLite i atrap — nie dowodzą jakości każdej odpowiedzi rzeczywistego modelu
ani kompletności OFF. Dokładne końcowe wyniki są w raporcie paczki 1.0.68.

Brak produkcyjnych zapisów, wysłanych pushy i zakupów podczas prac. Brak
Android SDK/Xcode: rzeczywisty AAB powstaje dopiero podczas instalacji
w Codespace; iOS wymaga kompilacji w Xcode Cloud i testu na urządzeniu.
UK pozostaje wyłączone i nie jest publicznie uruchamiane tą aktualizacją.
