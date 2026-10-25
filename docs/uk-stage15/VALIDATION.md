# Etap 15 — weryfikacja 21.10.2026

Zakres: [SCOPE-AND-PARITY.md](SCOPE-AND-PARITY.md).

## Wykonane sprawdzenia

- Zestaw regresyjny backendu: `ENVIRONMENT=test python -m pytest tests -q`:
  **1293 passed**, 41 ostrzeżeń zależności, exit 0.
  Log: `uk-stage15-backend-tests-final.log`.
- Pełny Flutter, `flutter test --no-pub`: **576 passed**, exit 0.
  Log: `uk-stage15-flutter-tests-final.log`.
- Po uporządkowaniu prywatnych helperów testowych ponowiono trzy nowe
  pliki widgetowe: **11 passed**, exit 0 (`uk-stage15-last-targeted.log`).
- Flutter analyze: **0 errors, 0 warnings, 364 info/linty**, exit 0.
  Log: `uk-stage15-flutter-analyze.log`. To nie wynik „zero uwag”.
- `compileall -q backend/app backend/scripts`: exit 0.
- `git -c core.autocrlf=false diff --check`: exit 0 po normalizacji LF.
- Inwentaryzacja AST routerów: wyłącznie dwa wcześniej opisane techniczne
  endpointy listy GBP, zero usuniętych tras. Ten etap nie dodał endpointu.
- Wersja `1.0.66+267`, `UK_MARKET_ENABLED=False`; pliki natywne, weryfikacja
  IAP, podstawowe uprawnienia Premium i update_service bez zmian.

## Regresje odtworzone przed poprawką

- Testy skanu GB ujawniły brak countries_tags w projekcji oraz gubienie
  źródłowych danych kraju przez parser/scalenie i zadanie cache.
  Testy kraju PL nadal nie wymagają tej dodatkowej informacji.
- Pełny backend wykrył, że surowe metadane mogły ponownie zawierać NaN/Inf
  po prawidłowym oczyszczeniu gramatury. Zablokowano taką metadaną,
  zachowując prawidłowy wynik samego produktu; regresja przeszła ponownie.
- Testy angielskich ekranów wykryły pozostawione polskie etykiety i błędy.
  Sprawdzono niezmienione ID, payloady, premium gate, save/retry i jednostki.
- Test kompletności lokalizacji wykrył brak nowych kluczy w en_GB.
  Uzupełniono wszystkie 64 klucze w trzech locale, nie osłabiono testu.
- Test 320 px/150% (Ahem) wykrył przepełnienie wiersza makro. Szczegółowy
  log ustalił właściwy Row; pierwszą błędną hipotezę o wyborze płci
  odrzucono i usunięto niepotrzebną zmianę. Właściciel zaakceptował wrap
  makro oraz osobno pionowe cele przy dużym tekście i wąskim kontenerze.

## Podgląd i Stark

Wygenerowano i obejrzano cztery zrzuty kalkulatora: PL i EN, 390 px/100%
oraz 320 px/150%. Test używa lokalnego Roboto z SDK i MaterialIcons wyłącznie
do renderu testowego. Nie dodano fontu do aplikacji ani pobierania z sieci.
Pierwszy podgląd z Ahem w stylu przycisków był niewiarygodny; naprawiono
konfigurację renderu i wykonano zrzuty ponownie, zamiast zmieniać aplikację.

- Zwykły układ zachowuje trzy kolumny, kolory, slider i przyciski.
- Wąski widok z dużą czcionką ma czytelne pełne nazwy celów w pionie;
  makro i przycisk zapisu pozostają dostępne przez istniejące przewijanie.
- Obliczenia i proporcje makro są identyczne w PL/GB, zapis profilu nadal
  używa canonical danych i dotychczasowej akcji powrotu.
- Gate: **akceptowalne z ryzykiem testów natywnych**. Zrzut widgetowy nie
  dowodzi zachowania SF Pro/Dynamic Type na iOS, klawiatury, aparatu ani IAP.

Dowody: `calculator-en-320-150.png`, `calculator-en-390-100.png`,
`calculator-pl-320-150.png`, `calculator-pl-390-100.png`.
Osiem testów w trybie kontrolnego renderu przeszło (`uk-stage15-calculator-render.log`).

## Ważne ograniczenia

Początkowe `pytest -q` z katalogu backend zebrało również dwa ręczne,
nieoznaczone funkcjami pytest-asyncio skrypty `test_generate.py` i
`test_seed.py`. Nie wykonały swojej treści; drugi korzysta z sesji bazy
i potrafi commitować. Nie zmieniano ich ani nie uruchamiano na żywej bazie.
Wynik 1293 dotyczy pełnego katalogu automatycznych testów `backend/tests`,
nie ręcznych skryptów operacyjnych z katalogu głównego.

Nie wykonano nowego testu natywnego Android/iOS, AAB/IPA, zakupu UK,
produkcji ani pełnego testu brytyjskiego asortymentu. Niezależny subagent
pozostaje ograniczony limitem, a cały projekt UK nie jest zakończony.
Brak produkcyjnego DDL/importu, push, deploy i paczki do Codespace.
