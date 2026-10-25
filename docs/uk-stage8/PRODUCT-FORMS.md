# Etap 8 — zgłaszanie produktów i odczyt etykiet

Praca lokalna, bez aktywacji rynku UK i bez zmiany numeru wydania.
Obecne kolory, motyw, standardowy układ, nawigacja i nagroda za produkt
pozostają bez redesignu.

## Zakres

- Formularz dodania/edycji produktu oraz zdjęcia przodu opakowania i tabeli:
  etykiety, walidacja, komunikaty i potwierdzenie PL/en/en_GB.
- Waluta ceny ze zgłoszenia wynika z kraju konta/edytowanego produktu.
  Podpowiedzi historycznego zakresu cen PLN nie są pokazywane jako GBP.
- Wybór sklepów pokazuje tylko właściwy kraj i walutę. Backend pozostaje
  źródłem walidacji uprawnień i rynku; błąd ładowania sklepów nie kasuje
  wcześniej wybranych identyfikatorów przy edycji.
- Jednostki widoczne po angielsku nie zmieniają identyfikatorów API.
  Opakowanie płynu zachowuje ml. Stary rekord opakowania bez jednoznacznej
  jednostki wymaga jej wyboru zamiast domyślnego przepisania masy na gramy.
- Baza w polach makro to 100 g albo 100 ml; wielkość całego opakowania
  jest osobnym polem. Pusta gramatura pozostaje nieznana, bez zastępczych 100 g.

## Odtworzone i naprawione błędy

1. Edycja produktu ml/opak z metadanymi ml wysyłała `serving_unit: g`.
2. Wybranie drugiej podpowiedzi zachowywało markę, kod, makro lub gramaturę
   poprzedniego produktu, gdy nowy wynik nie miał tych danych.
3. Ponowny skan przypisywał nowy kod do poprzedniej nazwy/danych, również
   po błędzie wyszukiwania; spóźniony wynik mógł uzupełnić nowszy wybór.
4. Niektóre nieprawidłowe liczby były pomijane lub wysyłane do API.
   Walidacja obejmuje puste wymagane wartości, tekst, NaN, nieskończoność,
   liczby ujemne i przekroczone limity. Zwinięcie makro nie omija kontroli.
5. Zaokrąglenie wartości źródłowych przed zapisem zamieniało np. 0.04 na 0.
   Edytowalne dane zachowują precyzję, a prawdziwe zero pozostaje zerem.
6. Błąd uprawnień/wyboru zdjęcia wychodził jako nieobsłużony wyjątek.
   Jest komunikat i możliwość ponowienia bez utraty formularza/zdjęć.
7. Rozwijane jednostki nie mieściły się przy 320 px/150% tekstu. Kontrolki
   dostają pełną szerokość tylko przy braku miejsca; zwykłe dwie kolumny
   pozostają. Przycisk jest przewijalny ponad klawiaturę i margines systemowy.
8. Formularz zgłoszenia dublował uchwyt przeciągania istniejącego motywu.
   Pozostawiono pojedynczy uchwyt dostarczany przez BottomSheet.

## Dowody i ograniczenia

- Testy `submit_product_market_test.dart`, `product_label_market_test.dart`
  i `product_form_validation_test.dart` obejmują 60 przypadków. Dla błędów
  danych/numerów wykonano cykle czerwony -> poprawka -> zielony.
- Odtworzenie pominiętej kontroli przy zwinięciu makro było czerwone;
  osobny test pól przewiniętych poza ekran przechodził już przed poprawką.
  Nie traktujemy tego drugiego przypadku jako potwierdzonego starego błędu.
- Odczyt i zapis są atrapami; testy nie robią zdjęć, nie pytają AI/OFF,
  nie przyznają punktów ani nie zapisują danych w Neon.
- Sprawdzono zapis/ponowienie, zachowanie danych po błędzie, podwójne
  zatwierdzenie, anulowanie zdjęcia, Back podczas OCR, Escape oraz przejście
  klawiaturą do przycisku zapisu. To nie pełny test VoiceOver/TalkBack.
- Rendery `evidence/submit-*` i `evidence/label-*`: PL/GB, jasny/ciemny,
  320x740, tekst 150%, symulowane 280 px klawiatury i 24 px dolnego marginesu.
  Obrazy powstają wyłącznie przy `--dart-define=UK_WRITE_UI_PROOF=true`,
  z testową lokalną czcionką Arial i MaterialIcons.
- Brak fizycznego iPhone/Androida: rzeczywiste uprawnienia kamery/galerii,
  klawiatura, czytniki ekranowe, jakość OCR i aktualne etykiety nadal wymagają QA.
- Nie jest to przegląd wszystkich rekordów produkcyjnych ani dowód gotowego
  katalogu UK. Realne SKU, ceny, dostępność i pozostałe teksty aplikacji są
  nadal bramkami wydania opisanymi w `../UK-EXPANSION.md`.

Akceptacja UX: lokalny zakres sprawdzony w testach/renderach, z nazwanym
ryzykiem natywnym. Nie ogłaszamy pełnej gotowości do publicznego wydania UK.

## Weryfikacja końcowa — 2026-10-20

- Pełny backend: 981 testów, exit 0, 37 istniejących ostrzeżeń (32.77 s).
- Pełny Flutter: 412 testów, exit 0 (62 s); w tym 60 nowych przypadków.
- Pełna analiza Flutter: exit 0, 0 błędów, 0 ostrzeżeń, 328 informacji.
- Generowanie l10n: exit 0; 748 zgodnych kluczy w PL/en/en_GB.
- Osobny przebieg renderów z prawdziwymi fontami testowymi: 8/8, exit 0.
  Sprawdzono wizualnie m.in. EN jasny początek, EN ciemny przycisk zapisu,
  PL ciemny przegląd makro i PL/EN jasny wybór zdjęć. Zduplikowany uchwyt
  usunięto po inspekcji pierwszego obrazu i ponowiono te same rendery.
- Kopie ZIP/bundle sprzed rozbudowy UK nadal mają sumy SHA-256 zgodne
  z pierwotnie zapisanymi; produkcyjna baza nie była zmieniana.
- Wersja 1.0.66+267 i flaga UK wyłączona; bez zmian w motywie, natywnych
  projektach Android/iOS oraz obsłudze zakupów. Nie budowano AAB/IPA.
