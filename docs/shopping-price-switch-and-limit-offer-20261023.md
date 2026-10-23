# Zakupy i limit Premium — zmiany lokalne po paczce 269

## Kontrakt UX przed domknięciem integracji

- Zadanie: porównać rzeczywistą listę, wybrać sklep lub wrócić do zakupów
  po osiągnięciu tygodniowego limitu. Użytkownik powracający, PL/GB.
- Ryzyko: utrata wyboru/składu listy i błędne przedstawienie kosztu lub triala.
- Wzorzec: istniejąca lista → porównanie z jawnym brakiem cen → zmiana sklepu;
  limit → istniejący ekran Premium z przejrzystą ceną i drogą powrotu.
- Akcje: wybór sklepu nie wymaga wymyślania ceny; oferta prowadzi do cennika,
  nie do automatycznego zakupu. Powrót do listy nie usuwa formularza pod spodem.
- Stan częściowy: brak wyceny nie oznacza 0 zł ani najtańszego sklepu.
- Odzyskiwanie: błąd oferty nie może ukryć oryginalnego limitu; ponowna próba
  pozostaje możliwa. Zmiana konta unieważnia spóźniony wynik i nawigację.
- Częstotliwość: pełna oferta limitu najwyżej raz na sesję; potem krótki
  komunikat z odnośnikiem Premium. Brak oferty dla aktywnego Premium.
- Ciągłość: zachowane komponenty, kolory, typografia, kwoty sklepu i istniejące
  trasy. Bez przebudowy nawigacji, nowej ankiety i nowych danych telemetrycznych.
- Dowody: testy serwisów i rzeczywistych widgetów PL/GB, 320 px / 150%,
  anulowanie/powrót, ponowienie błędu, zmiana sesji i niepełna wycena.
- Granica: testy widgetowe nie zastępują Androida/iOS ani rzeczywistej płatności.

Paczka `mealplanner-update-1.0.68-269-49576a6-verified.zip` jest zamrożona:
poniższe późniejsze zmiany nie modyfikują przekazanego ZIP-a. UK nadal wyłączone.

## Przyczyny

Parser Fluttera zamieniał brak pełnej wyceny PLN na zero. Karta ukrywała
przycisk zmiany sklepu, a endpoint wymagał kompletnego zestawu cen.
Backend odróżniał brak wyceny od darmowego koszyka, ale interfejs gubił tę
różnicę. Naprawa dotyczy list zakupów PL i GB, nie wymyśla ofert ani cen.

## Weryfikacja

Wyniki bieżącej partii zostaną uzupełnione po testach zmienianych miejsc.
Pełna regresja UK pozostaje zaplanowana na zamknięcie wdrożenia, zamiast
ponownego wykonywania całego zestawu po każdej drobnej zmianie.
