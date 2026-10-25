# Weryfikacja etapu 14 po korekcie zakresu — 21.10.2026

Zakres i odstępstwa: [SCOPE-AUDIT.md](SCOPE-AUDIT.md).

## Bieżący stan

- Pełny backend: **1278 passed**, 41 ostrzeżeń zależności, exit 0.
  Log: uk-stage14-backend-tests-final.log.
- Pełny Flutter po wycofaniu pełnego katalogu: **565 passed**, exit 0.
  Log: uk-stage14-flutter-tests-after-scope.log.
- Analiza Flutter: **0 errors, 0 warnings, 362 info/linty**, exit 0.
  Log: uk-stage14-flutter-analyze-after-scope.log.
- compileall backend/app i backend/scripts: exit 0.
- git -c core.autocrlf=false diff --check: exit 0 po normalizacji LF.
- Dodano 5 testów zgodnego mechanizmu skanera PL/GB; trafienie lokalne
  nie odpytuje OFF, brak trafienia korzysta z istniejącego fallbacku/cache.
  Nie istnieje nowy endpoint pełnego katalogu.
- 16 testów backendu kampanii (w tym walidacja dotychczasowej oferty)
  i 15 nowych testów Fluttera kampanii/kalendarza przeszło.

## Neon — wyłącznie gałąź testowa i rollback

Ponownie wykonano scripts/check_uk_branch.py na wskazanym uk-test
przez potwierdzony direct hostname. Test obejmuje idempotentne migracje,
zachowanie dotychczasowych kont/kampanii w PL, niezmienność kraju,
10 sklepów UK, izolację danych OFF, krajową dostępność OFF na prawdziwym
PostgreSQL i różne granice tygodnia London/Warsaw.
Nie uruchamiano lifespan, workerów, płatnego AI ani powiadomień.
Test kończy się rollbackiem oraz porównaniem fingerprintów starych danych
i listy tabel. Hasła i rekordy użytkowników nie trafiają do raportu.

Eksperymentalne narzędzia pełnego importu, endpoint i ścieżka pełnego
katalogu na ekranie zostały usunięte. 3 publiczne artefakty lokalnego
eksperymentu skasowano (łącznie 1 573 785 634 bajty); można je ponownie
odtworzyć z publicznego OFF. Backup źródeł i dane użytkowników są zachowane.

## Ograniczenia

Nie wykonano niezależnego audytu subagenta (limit użycia).
Nie potwierdzono pełnej zgodności wszystkich funkcji UK ani gotowości
całego języka/danych. Nie ma nowego AAB/IPA ani testu fizycznych urządzeń
i rzeczywistych brytyjskich zakupów. Nie wykonano push, deploy, produkcyjnego
DDL/importu ani paczki aktualizacji. Wersja 1.0.66+267 i UK wyłączone.
