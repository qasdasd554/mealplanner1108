# 1.0.67+268 — etap naprawczy i przygotowanie UK

Źródło: przesłany przez właściciela `mealplanner-current-for-update.zip`,
commit `3cf0c24d2ecfffa0b37a7e10d8f9b49c7d41d2f1`, wersja 1.0.66+267.
To wydanie napraw PL z przygotowaniem nieaktywnego rynku GB, nie publiczny
start UK. `UK_MARKET_ENABLED` pozostaje false; nie importujemy całego OFF.
Układ, kolorystyka i funkcje nie są przeprojektowane.

## Najważniejsze poprawki

- Lista z przepisu korzysta ze składników. Ogólna kontrola odrzuca podejrzany
  zapis całego gotowego dania zamiast surowego składnika, a import AI nie
  pomija po cichu nierozpoznanych składników. Nie zgadujemy ilości ani składu
  starego błędnego przepisu: taki przepis wymaga poprawy ze źródła/autora.
- Porównanie cen działa na rzeczywistych pozycjach listy, także gdy lista
  z przepisu nie ma aktywnego planu. Brak ceny nie jest traktowany jak zero;
  niepełny koszyk nie jest zwycięzcą porównania.
- Ograniczono zbędne odświeżanie przy zmianie fokusu i pracę animacji ukrytych
  zakładek. Spóźnione odpowiedzi po zmianie konta nie nadpisują nowej sesji.
- Sterowanie aparatem jest serializowane; ręczne wpisanie kodu zawiesza
  skanowanie i nie jest nadpisywane kolejnym odczytem. Poprawiono obsługę
  powrotu z tła i zamknięcia ekranu.
- Pierwsza konfiguracja ma ochronę przed podwójnym zapisem, błędy wyboru
  sklepu pozwalają ponowić próbę, a mała wysokość/klawiatura nie zasłaniają
  wymaganych akcji. Poprawiono odświeżanie CAPTCHA i obsługę błędu pamięci
  bezpiecznej bez niekontrolowanego blokowania uruchomienia aplikacji.
- Zatwierdzanie produktów/przepisów i operacje administracyjne mają osłony
  przed podwójnym wykonaniem i starymi odpowiedziami wyszukiwania.
- Ofertę Premium pokazujemy zgodnie z zaakceptowanymi zasadami: co najmniej
  24 godziny na konto, najwyżej raz na sesję, w przepisie po 3 s i przewinięciu,
  w innych miejscach po sukcesie. Nigdy podczas edycji/skanowania ani przy
  aktywnym Premium. Nie zmieniono cen ani kwalifikacji triala w sklepach.

## Przygotowanie UK

Stały kraj konta; istniejący użytkownicy pozostają PL. Dodano izolację rynku,
wyświetlanie GBP, tłumaczenia istniejących ekranów, lokalne daty, komunikaty
serwera oraz zasoby językowe iOS. OFF jest odpytywane i cache'owane na żądanie,
nie kopiowane hurtowo do Neon. UK Deliveroo/Tesco to wyszarzone pozycje
„Coming soon”; polskie Jush/Glovo pozostają bez zmian.

Podłączono tłumaczenia 137 przepisów systemowych i etykiety 150 ich składników,
także w wyszukiwaniu. Treści użytkowników nie są tłumaczone na podstawie nazwy.
Komunikaty błędów dobierane są do kraju konta, a przed logowaniem do regionu
urządzenia, bez zmiany przypisanego rynku istniejących kont. Do publicznego
wydania UK pozostają zweryfikowane mapowania lokalnych składników/dostępności
i cen, pozostałe komunikaty natywnych usług, dokumenty,
konfiguracja ofert sklepowych oraz testy na urządzeniach. Nie deklarujemy
pełnego katalogu wszystkich sklepów ani bieżących potwierdzonych cen UK.

## Weryfikacja i ograniczenia

Korekta paczki `sqlite-fix` z 23.10: Codespace właściciela ma SQLite 3.34.1,
bez INSERT RETURNING. Trzy nowe fixture'y testowe nie miały adaptera dla
serwerowych UUID i 126 testów zakończyło się błędem. Instalator przywrócił
źródła; właściciel potwierdził ten sam commit i brak zmienionych śledzonych
plików. Odtworzono osiem reprezentatywnych błędów bez RETURNING, dodano
adapter wyłącznie do lokalnych sesji testowych i rozszerzono regresje.
Pełny backend po korekcie: 1827 testów, 43 ostrzeżenia zależności. Bez zmiany
modeli aplikacji, schematu Neon, wygenerowanego UI ani numeru buildu 268.
Techniczna korekta testów nie dodaje punktu do powiadomienia dla użytkowników.

Historyczny przebieg pierwszej paczki: 813 testów Flutter i 1636 backendu.
Po kolejnych lokalnych poprawkach 23.10 pełny backend: 1682 testy, 42 ostrzeżenia
zależności, a pełny Flutter: 1008 testów bez niepowodzeń. Wyniki dotyczą nowej
zbiorczej paczki z 23.10, nie starego ZIP-a. Testy są lokalne,
z atrapami usług i tymczasową bazą SQLite.
Analiza Flutter z `--no-fatal-infos`: 0 błędów, 0 ostrzeżeń, 378 uwag
informacyjnych. Nie jest to deklaracja całkowicie czystego lintu.
Ostateczny payload jest dodatkowo sprawdzany w osobnej kopii źródeł przez
instalator. Raport walidacji paczki jest dostarczony oddzielnie.

Nie ma lokalnie Android SDK ani macOS/Xcode: nie zbudowano tutaj rzeczywistego
AAB/IPA. Instalator wymaga powodzenia analizy, testów i rzeczywistego AAB
w Codespace przed commitem/push. Natywne okna uprawnień, aparat, rozszerzenie
iOS i zakupy wymagają testu na urządzeniu. Brak stosów Android Vitals nie
pozwala przypisać wszystkich zgłoszonych zamknięć procesu jednej przyczynie.

## Tekst powiadomienia o aktualizacji

• Poprawiliśmy listy zakupów ze składników przepisów i porównywanie cen.
• Usprawniliśmy import przepisów, aby brakujące składniki nie były pomijane.
• Ograniczyliśmy zbędne odświeżanie ekranów i pracę ukrytych animacji.
• Usprawniliśmy uruchamianie aplikacji i obsługę aparatu; skanowanie nie przerywa ręcznego wpisywania kodu.
• Ułatwiliśmy pierwszą konfigurację i poprawiliśmy stabilność weryfikacji podczas logowania oraz zmiany konta.

Po publikacji 268 ustaw odpowiednio `LATEST_ANDROID_VERSION_CODE=268` oraz
`LATEST_IOS_BUILD_NUMBER=268` dopiero po dostępności na danej platformie.
Wcześniejsze klienty mają wbudowany starszy tekst; aktualny jest w tej wersji.
Nie ustawiaj FORCE_UPDATE bez osobnej decyzji o wymuszaniu aktualizacji.
