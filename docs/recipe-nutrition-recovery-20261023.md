# Ogólna naprawa składników i makro, 23.10.2026

## Diagnoza

OFF 503 oznacza niedostępność źródła, nie 0 kcal oleju. Dotychczas jeden
prywatny składnik bez danych zmieniał całą sumę na null; starszy interfejs
prezentował null jako zero. Znane składniki na zrzucie nadal miały kcal.

Drugim źródłem błędu był dowolny katalog produktów w podpowiedziach AI.
Filtr nazw dań nie może rozpoznać wszystkich istniejących potraw. Dlatego
naprawa NIE polega na dopisywaniu kolejnych zakazanych nazw:

1. AI komponuje danie z nazwami faktycznie potrzebnych składników. Jako
   opcjonalny słownik dostaje tylko 150 sprawdzonych nazw składników systemowych,
   po zgodnym ID, oryginalnej nazwie, zatwierdzeniu i braku autora produktu.
   To nie limit liczby dostępnych składników: spoza słownika też zostają zapisane.
2. Dopiero gotowy skład jest dopasowywany do pełnego dozwolonego katalogu.
   Nazwa po normalizacji/znany alias może wskazać ten sam składnik; podobieństwo
   znaków nie może wskazać innego produktu, smaku ani gotowego dania.
3. Brakujące dane są szukane w istniejącej ścieżce OFF. Potem jeden ograniczony
   czasowo batch AI może oszacować nieznane składniki metryczne. Opcjonalne
   USDA Foundation/SR Legacy wymaga własnego klucza, dokładnej nazwy i 100 g.
   Nie przeliczamy 100 g na 100 ml bez gęstości ani nie wymyślamy masy sztuki.
4. Szacunek nie jest potwierdzoną etykietą: prywatny produkt pending,
   metadane źródła/estimated, brak GTIN/opakowania/ceny i publicznego zatwierdzenia.
   Nie dodano kosztu punktowego za samo uzupełnienie danych.
5. Niewiarygodna odpowiedź/timeout nie blokuje przepisu. Braki zostają jawne,
   znana część sumy jest zachowana. Niepełne dane nadal blokują zapis zerowego
   posiłku do Dziennika i dobór przepisu do celu kalorycznego.

Zapytanie szacunku zawiera wyłącznie nazwy składników i jednostki, bez danych
konta. AI nie jest przedstawiane jako przeglądarka. Źródło USDA ma URL z
odpowiedzi API, nie link wymyślony przez model. Kluczy nie zapisujemy w logach.

Pozostaje dodatkowa defensywna regresja dla rozpoznanego gotowego Cordon Bleu,
ale ogólne odseparowanie katalogu i dopasowanie bez fuzzy działa dla dowolnych
nazw, także takich, których żaden filtr dań nie rozpoznaje.

## Generowanie planu — 500

Odtworzono brak Recipe.tags po przebudowie listy, która odświeża istniejące ORM
przez populate_existing. Odpowiedź Pydantic próbowała wtedy wykonać leniwy odczyt
poza kontekstem asynchronicznego zapytania. Końcowy odczyt planu ładuje teraz tagi.
Test serializuje odłączone obiekty: dowodzi, że odpowiedź nie wymaga dalszego I/O.
Sam ogólny stos ResponseValidationError nie wyklucza innych przyczyn; ewentualne
nowe przypadki po wdrożeniu wymagają szczegółów walidacji, nie zgadywania.

## Kontrola i granice

Testy najpierw wykazały brak znanej sumy, przepuszczony gotowy produkt i błąd
serializacji tagów w czterech ustawieniach bazy. Obejmuje to SQLite bez RETURNING.
Osobne testy sprawdzają różne potrawy/produkty, nazwy PL/GB, jednostki, błędne
odpowiedzi AI, proweniencję i niepublikowanie szacunków.

Nie wykonywano prawdziwego Gemini/OFF/USDA ani zapisu produkcyjnego Neon,
płatności, pushy czy testów aparatu. Szacunków nie należy przedstawiać jako
zmierzonych wartości etykiety. Starsze przepisy z niewłaściwym gotowym daniem
trzeba ponownie wygenerować/edytować: nie zgadujemy automatycznie ich ilości.

Backup przed zmianami: `../backups/recipe-nutrition-20261023/` poza checkoutem.
Paczka zawiera kod napraw, nie kopię sekretów ani danych użytkowników.
