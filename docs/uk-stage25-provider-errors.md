# Etap 25 — lokalny język błędów stanu aplikacji

To dalsza praca UK po zamrożeniu paczki naprawczej 1.0.67+268.
Nie jest zawarta w tamtej paczce. Bez nowych funkcji i zmiany wyglądu.
Backup przed edycją: `../backups/uk-stage25-before.zip`.

## Przyczyna i zakres

Komponenty ekranowe miały tłumaczenia, ale sześć providerów wywoływało
`friendlyError` bez obiektu języka. Skutek: ogólne błędy sieci/timeout/sesji
były po polsku także po zalogowaniu na konto GB.

Sklepy, plany, zakupy, dziennik, nawodnienie/aktywność i promocje otrzymują
opcjonalny resolver języka. Główna kompozycja aplikacji odczytuje aktualny
zapisany kraj konta podczas obsługi błędu. Nie tworzymy nowych providerów
przy zmianie języka i nie dodajemy mutable globalnego języka ani inferencji IP.
Domyślne konstruktory zachowują dokładne polskie komunikaty.
Jawny język podany ekranowi promocji ma pierwszeństwo.

API-owe komunikaty walidacyjne pozostają oryginalne; nie tłumaczymy nazw
produktów ani tekstu administratora. Dotychczasowe generacje żądań/sesji
są sprawdzane przed odczytem resolvera. Nie zmieniono retry, tokenów,
uprawnień, obliczeń, punktów, źródeł danych ani zapytań.

## Dowód

`provider_error_market_test.dart`: przed poprawką 14 passed / 10 failed;
po poprawce 24 passed. Obejmuje sześć rzeczywistych providerów, 401/429/
500/503/504, timeout, połączenie, format odpowiedzi, oryginalny szczegół
walidacyjny, brak sesji, zmianę konta, stare błędy po clear i pierwszeństwo
języka ekranu. Wszystko z atrapami usług, bez prawdziwych kont i sieci.
Test wyboru języka dodatkowo potwierdza stabilny cache i fallback PL.

Pełne testy i analiza są uruchamiane osobno po integracji tego etapu.
UK nadal wyłączone. Ten etap nie rozwiązuje pozostałych treści przepisów,
mapowań rzeczywistych składników/cen, dokumentów ani natywnych testów.
