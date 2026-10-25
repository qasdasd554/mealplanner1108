# Etap 10 — szczegóły przepisu i język AI

Praca lokalna; bez wydania, wdrożenia, produkcyjnych zmian danych, aktywacji
UK lub zmiany wersji 1.0.66+267. Nie jest to zakończona lokalizacja aplikacji.

## Backend

- Import z tekstu, zdjęcia i niestrukturalnego linku oraz edycja AI dostają
  kraj z uwierzytelnionego konta. GB wymaga treści generowanej w brytyjskim
  angielskim. PL zachowuje dotychczasowy prompt i kontrakt wywołań.
- Nazwy katalogowe, marki, identyfikatory produktów i protokołu pozostają
  niezmienne. `meal_type`, `difficulty` i jednostki API nie są tłumaczone.
  Oryginalne przepisy innych autorów nie są masowo nadpisywane.
- Worker odczytuje kraj użytkownika z bazy, nie z payloadu zadania.
  Powiadomienie gotowości/błędu, błędy importu/edycji i kolejki mają EN dla GB.
  Country z payloadu nie zastępuje zapisanej wartości konta.
- Zachowano blokady uprawnień, limity, koszty punktowe, ponowną autoryzację
  w workerze, idempotencję, odzyskanie zadania i ochronę SSRF.
  Nie dodano wywołań tłumaczących, źródeł ani większych timeoutów AI.
- Poprawna szybka ścieżka schema.org nadal pomija AI i zachowuje oryginalną
  treść strony. Nie wymuszamy tłumaczenia autorskiej strony dodatkowym AI.
  Odtworzony błąd `2 oz chicken breast` jako `2 szt` jest zablokowany:
  nieobsługiwana miara kieruje do istniejącego fallbacku AI, nie do
  zgadywania gramatury lub jednostki sztukowej.
- Import tworzy prywatny przepis z kanonicznych produktów. Nie tworzy
  ofert UK ani nie dowodzi dostępności składnika w sklepie. Publiczny
  katalog UK nadal wymaga zweryfikowanych RegionalProductOffer.

## Frontend

- Etykiety szczegółów przepisu, makro na porcję, autora, instrukcji, wariantu,
  jednostek, edycji AI, zdjęć i zwykłych akcji mają PL/EN. Interfejs korzysta
  z istniejących ARB i języka konta. Nazwa, opis, instrukcje, marki i składniki
  zapisane przez autora pozostają jego treścią, nie automatycznym tłumaczeniem.
- Dialog ilości zatrzymuje nieprawidłową wartość do korekty, zamiast zamykać
  się po błędzie. Akceptuje przecinek dziesiętny. Granice ilości odpowiadają
  istniejącej walidacji API: do 50 szt/opak i do 20 000 dla pozostałych jednostek.
  To nie nowy limit serwera ani nowy przelicznik masy.
- Kontroler pola jest usuwany dopiero po zakończeniu animacji zamknięcia.
  Odtworzono błąd użycia kontrolera po dispose podczas zwykłej edycji ilości.
- Podpowiedź domyślnej ilości produktu opakowanego oznacza jedno opakowanie,
  nie historyczne 100 opakowań. Nie przypisuje opakowaniu domyślnej masy.
- Wyszukiwanie składnika ignoruje spóźnione wyniki poprzedniego zapytania.
  Wyczyszczenie pola unieważnia wynik w toku i usuwa stan ładowania.
- Edycja AI nadal kosztuje 1 punkt po udanej operacji; brak punktów blokuje
  wysłanie i pokazuje istniejące przejście do zakupu. Nie zmieniono cen IAP.

## Decyzje Stark UX i zaakceptowane wyjątki dopasowania

- Zadanie: odczytać przepis i bezpiecznie skorygować roboczą listę składników.
  Użytkownik powracający; edycja odwracalna, AI kosztuje punkt.
- Wzorzec: istniejące szczegóły + modalna edycja, tymczasowy wariant z cofaniem.
  Nie dodajemy nowej nawigacji, animacji, ekranu ani dekoracji.
- Styl: zachowane motyw, kolory, dwie kolumny makro, ikonografia i obramowania.
- Stany: lekki przepis, dociąganie danych, błąd z ponowieniem, roboczy wariant,
  błędna ilość z zachowaniem wpisu, oczekiwanie AI i brak punktów.
- Reguły formularza: walidacja po zatwierdzeniu, błąd przy polu, anulowanie,
  zachowanie wpisu, bez wysyłania NaN/Infinity i wartości odrzuconych przez API.
- Po zgodzie właściciela wysokość kafelków makro jest zwiększana wyłącznie,
  gdy pomiar rzeczywistej czcionki/tekstu wymaga więcej miejsca. Dwie kolumny
  i podstawowe proporcje pozostają. 150% to test powiększenia tekstu, nie
  nowy domyślny rozmiar czcionki w aplikacji.
- Po osobnej zgodzie napis przycisku listy zakupów może się zawinąć w razie
  braku miejsca; normalny układ, kolor i działanie są zachowane.
- Flutterowe kontrolki zachowują modalny focus, Tab/Enter oraz Escape;
  nie zastępujemy ich nową biblioteką ani innymi idiomami platform.

## Dowody i granice akceptacji

- `recipe_variant_market_test.dart`: odczyt EN, NaN/Infinity/ujemne/zero/tekst,
  duża ilość, zachowanie wpisu, przecinek, poprawne przeliczenie makro roboczego,
  jedno opakowanie, spóźniona odpowiedź, Tab/Enter i Escape.
- `recipe_detail_market_test.dart`: PL/EN, zachowana treść autora, suma na
  porcję, doładowanie i ponowienie szczegółów, anulowanie publikacji, koszt AI,
  busy/duplikaty i brak punktów. Żądania i zapis w testach są atrapami.
- `recipe_ingredient_defaults_test.dart`: granice ilości zgodne z API.
- `test_ai_recipe_market.py`: 49 nowych przypadków, w tym kraj workera,
  prompt PL/GB, zachowanie ID i jednostek, import/edycja, błędy oraz URL/SSRF.
- Dla potwierdzonych błędów wykonano przebiegi czerwony → poprawka → zielony.
  Błędy nowych testów wynikające z niejednoznacznego findera, oczekiwania na
  nieskończony spinner i nieprawidłowego fixture Base64 poprawiono w testach;
  nie liczymy ich jako błędów produkcyjnej aplikacji.
- Dowody wizualne: cztery PNG w `evidence/`, PL/EN, jasny/ciemny, 320x740,
  tekst 150%, z testowym fontem Arial i MaterialIcons. To render WidgetTester,
  nie fizyczny telefon. Oglądnięto m.in. EN jasny i PL ciemny widok makro.
- Najpoważniejsze odtworzone problemy: controller po dispose (blokujący błąd),
  nieprawidłowe ilości/100 opakowań i wynik starego wyszukiwania (dane),
  ucinanie makro/przycisku (czytelność). Ponowiono te same interakcje po naprawie.
- Zakres UX: akceptowalny lokalnie z ryzykiem natywnym. Brak testu VoiceOver,
  TalkBack, rzeczywistej kamery, AI, płatności i Neon. Nie ogłaszamy kompletnej
  gotowości UK lub wszystkich funkcji aplikacji na podstawie tych testów.
- Komentarze, moderacja, kontekstowe oferty Premium, profil i inne ekrany
  nadal wymagają dalszej lokalizacji; obecność EN w tym zakresie ich nie zastępuje.

Końcowe wyniki pełnych testów są zapisane w `../UK-EXPANSION.md`.
