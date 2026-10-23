# Składniki przepisu → lista zakupów (PL i GB)

Prace lokalne po przygotowaniu niezmienianej paczki `sqlite-fix` 1.0.67+268.
Nie oznacza to wdrożenia na Render, Codespace ani telefonach. Nie zmieniono
numeru wersji, wyglądu ani zasad limitów/Premium.

## Kontrakt

Źródłem listy są wiersze `RecipeIngredient`: produkt, ilość i jednostka,
z mnożnikiem wpisu planu. Nie wyszukujemy produktu po nazwie całego przepisu.
Ceny i opakowania dotyczą tego samego produktu, nie podobnie nazwanego obiadu.
Uwzględnianie spiżarni i sumowanie wspólnych składników pozostają bez zmian.

## Odtworzone błędy i poprawki

1. Blokada oparta na podobieństwie tytułu i nazwy składnika odrzucała też
   prawidłowe składniki, np. mięso w marynacie. Usunięta z tworzenia listy
   i jej przeliczenia. Przetworzony komponent nie oznacza całego obiadu.
2. `_load_meal_plan` mógł zachować stare `entries` w identity map po
   dopisaniu dania przy `expire_on_commit=False`. Flush i ponowny odczyt
   z `populate_existing=True` zapewniają przeliczenie faktycznych wpisów.
3. Ekran po tymczasowej edycji pokazywał nowy skład, ale wysyłał ID oryginału.
   Przed utworzeniem listy zapisuje teraz wariant istniejącym mechanizmem
   „Moje”, bez zmiany oryginału. Pomoc w edytorze uprzedza o zapisie.
   Błąd zapisu nie powoduje cichego użycia oryginalnego przepisu.
4. Fuzzy matching mógł zamienić składnik na produkt „w sosie”. Nie wybiera
   teraz produktu wyglądającego na całe danie dla nazwy zwykłego składnika.
5. Walidacja importu AI sprawdzała tylko zgodność z tytułem: inny tytuł
   przepuszczał gotowy obiad jako składnik. Wspólna kontrola przy zapisie
   odrzuca taki wynik także przy innym tytule, przed pobraniem punktów.
   Katalog wejściowy tworzenia/edycji AI pomija rozpoznane gotowe posiłki.
6. Filtr katalogu niesłusznie odrzucał „Pierś z kurczaka”, „Filet z dorsza”,
   „Sok z cytryny” czy „Melasa z granatu”. Rozróżnia teraz nazwę produktu
   pochodnego/części mięsa i prawidłowe komponenty konserwowe od całego obiadu.
   Instrukcja AI wyraźnie dopuszcza mleko, masło, bułkę tartą i sos.

## Zrzut właściciela i granice potwierdzenia

Zrzut sekcji składników potwierdził, że produkt „Kotlet schabowy z buraczkami
i puree” występuje już w samym przepisie jako 4 sztuki. Nie jest to wyłącznie
podmiana podczas budowania zakupów. Nie zmieniano tego produkcyjnego rekordu
ani nie zgadywano masy schabu czy brakującej kapusty. Nowa walidacja chroni
powstawanie kolejnych takich zapisów; nie odtwarza automatycznie źródła
starych błędnych przepisów. Rozpoznawanie roli produktu po nazwie jest
zabezpieczeniem heurystycznym, nie dowodem poprawności dowolnej odpowiedzi AI.

## Testy

- Red: 25 niepowodzeń dla blokady list/nieprawidłowego dopasowania.
- Dodatkowy test ujawnił 8 przypadków pominięcia dopisanego przepisu.
- Cztery scenariusze widgetu odtworzyły użycie starego przepisu po edycji.
- Testy importu: tekst, zdjęcie i link, PL/GB; brak zapisu i pobrania punktów
  dla dania użytego jako składnik, również przy innym tytule.
- Testy faktycznej bazy SQLite obejmują autoflush/no-autoflush i brak
  INSERT RETURNING (zgodność z Codespace SQLite 3.34).
- Sprawdzono składniki wszystkich 112 bazowych przepisów systemowych oraz
  prawidłowe komponenty przetworzone/konserwowe. To dane testowe, nie audyt
  produkcyjnych rekordów ani wywołanie zewnętrznego AI.
- Pełny backend: **1907 passed**, 43 ostrzeżenia deprecacyjne, 140,12 s.
- Pełny Flutter: **1036 passed**. Analiza: **0 errors, 0 warnings**,
  380 komunikatów info/lint; nie są to błędy kompilacji.
- Bieżące pełne wyniki: `shopping-source-20261023-backend-final.log`,
  `shopping-source-20261023-flutter-final.log`, `shopping-source-20261023-analyze.log`.

Treść powiadomienia o aktualizacji PL/GB uwzględnia przenoszenie składników
i ilości po edycji oraz dopisaniu dania. Brak natywnego buildu/device testu
w tym środowisku. Brak zapisu do produkcyjnej bazy i zewnętrznych powiadomień.
SHA-256 dostarczonej wcześniej paczki `sqlite-fix` sprawdzono ponownie:
`34f7605936d8e62f76cafc9dd091cdf321142aadedfedea52fd1824c1fe3048e`.
Pozostaje niezmieniona i nie zawiera opisanych tutaj późniejszych poprawek.
