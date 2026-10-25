# UK — angielskie dokumenty i kontrola publikacji

24.10.2026. Wyłącznie lokalnie, bez wydania i aktywacji UK. Backup głównej
checklisty: `../backups/uk-stage52-20261024/`.

Przygotowano [cztery projekty i listę do zatwierdzenia](uk-release-review/README.md)
na podstawie aktualnych stron, a nie starszych plików repozytorium. Zapisano
tekstowe migawki, adresy, daty i odciski. Wszystkie projekty mają stan draft
i są wyraźnie oznaczone jako niezatwierdzone; nie ma w nich aktywnych
formularzy ani skryptów, a operator nie został ustalony przez zgadywanie.

Nowy `scripts/check_uk_documents.py` oddziela:

- poprawność techniczną lokalnych projektów,
- odnotowane zatwierdzenie finalnych dokumentów,
- rzeczywiste odczytanie czterech angielskich stron na potwierdzonej domenie.

Żadna z tych rzeczy osobno nie oznacza gotowości wydania ani zgodności
prawnej. Przekierowania nie są automatycznie śledzone, nawet jeśli wywołujący
przekazał klienta HTTP z domyślnie dozwolonym śledzeniem. Ten przypadek
odtworzył test, a poprawka sprawia, że nie wychodzi żądanie do obcej domeny.

Sprawdzenie na żywo: obecne cztery polskie dokumenty — 200. Proponowane
cztery ścieżki `/en/*.html` — 301 do `mealplannerworld.com`. Nie potwierdzano
własności domeny ani nie zmieniano `AppLinks`. Kontrola wydania kończy się
prawidłowo stanem `ready_for_release: false` i kodem 2 w trybie wymagającym
gotowości. Szczegóły: `uk-stage52-documents-live-check.log`.

Testy celowane: **25 passed**, exit 0. Obejmują drafty, zmianę odcisków,
brakujące/niezgodne dokumenty, zły język, błędne HTTP, przekierowania,
przekroczony rozmiar, błędy transportu i rozdzielenie zatwierdzenia od
publikacji oraz odporność na CRLF/BOM i niezależność historycznego źródła
od przyszłej domeny publikacji. Nie uruchamiano ponownie pełnego backendu ani Fluttera wyłącznie
dla narzędzia i dokumentów; kod działania aplikacji nie został zmieniony.

Do domknięcia tego punktu potrzebne są decyzje/treść operatora i potwierdzenie
docelowej domeny. Pozostałe zewnętrzne warunki startu UK to testy natywne,
konfiguracja produktów i ofert w sklepach oraz uzgodniony import danych
startowych na produkcję. Nie twierdzimy, że wykonano te czynności.
