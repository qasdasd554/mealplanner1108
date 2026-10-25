# Etap 13 — archiwum planów i automatyczny tydzień

21.10.2026. Prace lokalne; UK nadal wyłączone, wersja 1.0.66+267.
Bez wdrożenia, zmiany subskrypcji, limitów ani funkcji użytkownika.

## Zakres

- Teksty archiwum, wyboru daty, potwierdzenia wznowienia i automatyzacji
  przeniesiono do PL/en/en_GB ARB. Polskie brzmienie zachowano.
- Daty archiwum: dd.MM.yyyy dla PL, dd/MM/yyyy dla GB. Nazwy miesięcy
  w statusie automatyzacji korzystają z lokalizacji ekranu.
- Dni pozostają numerami API 0–6, godziny 0–23. Zmiana języka nie zmienia
  zapisanego harmonogramu. Nie zmieniano generatora, kalendarza backendu
  ani daty początku planu.
- Znane komunikaty błędów mają opcjonalną lokalizację w friendlyError.
  Dotychczasowe wywołania bez argumentu strings zachowują polskie teksty.
  Szczegół serwera nie jest zastępowany dla 403/404/409/422.
- API archiwum, wznowienia i automatyzacji lokalizuje wskazane błędy
  według kraju konta. Statusy odpowiedzi i bramki Premium są niezmienione.

## Odtworzone i naprawione błędy

1. Po błędzie wczytania przycisk Ponów nie usuwał _error, więc nawet udana
   odpowiedź ponownie pokazywała ekran błędu. Retry czyści błąd, pokazuje
   ładowanie i nie uruchamia równocześnie drugiego odczytu.
2. Dwa szybkie kliknięcia zapisu wysyłały dwa żądania przed przebudowaniem
   przycisku. Zapis i generowanie mają synchroniczną blokadę single-flight;
   kontrolki nie zmieniają danych w trakcie żądania.
3. Po odpowiedzi generowania przełącznik nie odzwierciedlał wyłączenia
   automatyzacji przez serwer, np. po wygaśnięciu Premium. Formularz
   stosuje ustawienia z otrzymanej odpowiedzi.
4. Archiwum nie rozróżniało dwóch kont Premium. Po zmianie konta czyści
   poprzednią listę, ponownie ją pobiera i odrzuca stare odpowiedzi.
   Kontrola generacji obejmuje też oczekiwanie na wybór daty/wznowienie.
5. Pole dnia przepełniało się przy 320 px / 150%, także po polsku.
   Po zgodzie właściciela rozwijana lista korzysta z dostępnej szerokości
   i naturalnej wysokości elementów; tekst może się zawijać.

## Decyzja UI i dowody

Stark: naprawa responsywności istniejącego formularza Flutter na Android/iOS,
nie nowy projekt. Obiekt: harmonogram tygodnia; akcje: zapisz / generuj.
Pozostają istniejące kolory, obramowania, kolejność, ikony i natywne
wybieranie daty/godziny. Nie zmniejszamy czcionki i nie dodajemy animacji.
Przewijanie należy do istniejącej listy. Stany: ładowanie, błąd/retry,
wyłączony harmonogram, zapis/generowanie, wynik i zamknięcie ekranu.

Referencje: ui-audit-rubric, visual-repair-playbook oraz
responsive-adaptation-gate; po renderze rendered-typography-quality-gate.
Testy Ahem są konserwatywnym sprawdzianem szerokości. Zrzuty używają
wyłącznie testowo Arial i ikon Material, bez zmiany fontów produkcyjnych.
Sprawdzono zamknięte pole i wybór dnia po otwarciu listy.

- [GB, 320 px, 150%, jasny](evidence/weekly-gb-320-150-light.png)
- [GB, 320 px, 150%, ciemny](evidence/weekly-gb-320-150-dark.png)
- [PL, 320 px, 150%, jasny](evidence/weekly-pl-320-150-light.png)
- [PL, 320 px, 150%, ciemny](evidence/weekly-pl-320-150-dark.png)

## Weryfikacja

- Pełny Flutter: **550 passed**, bez niepowodzeń.
- Pełny backend: **1261 passed**, 41 ostrzeżeń; ENVIRONMENT=test.
- 19 testów ekranów, 13 testów lokalizacji błędów i 10 testów API dodano
  w tym etapie. Zachowano istniejące testy polskiego przebiegu wznowienia.
- Analiza: exit 0, bez błędów i ostrzeżeń; 359 informacji/lintów
  (liczba nie wzrosła względem etapu 12).
- Kontrola `git -c core.autocrlf=false diff --check`: exit 0 po LF.

Polecenia:

```powershell
# frontend
flutter test --no-pub -r expanded
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub --dart-define=UK_WRITE_UI_PROOF=true test/screens/meal_plan/plan_management_market_test.dart -r expanded
# backend — bez sekretów ani połączenia do produkcji
$env:ENVIRONMENT='test'
python -m pytest tests -q
```

Nowe testy obejmują wznowienie z zachowaniem daty, brak pobierania archiwum
bez Premium, numery dni, błędy sieci/serwera, retry, podwójne kliknięcia,
wygaśnięcie Premium, zamknięcie w trakcie żądania i zmianę konta.

Nie wykonywano testów fizycznego urządzenia, TalkBack/VoiceOver ani AAB/IPA.
Etap nie oznacza gotowości UK: pozostają dane SKU/cen, mapowania składników,
treść przepisów/porad, inne teksty/powiadomienia/dokumenty, kampanie krajowe
oraz natywne testy i konfiguracja sklepów. Produkcyjny Neon nie był używany.
