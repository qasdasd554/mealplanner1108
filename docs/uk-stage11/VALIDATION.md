# Etapy 11–12 — bieżący stan

Data: 21.10.2026. Prace lokalne, rynek UK wyłączony, wersja 1.0.66+267.
Poniżej wyniki etapów 11–12. Nowszy stan:
[etap 13 — archiwum i automatyzacja](../uk-stage13/VALIDATION.md).

## Zintegrowane

1. Odczyt katalogu sklepu GB z przejrzanych ofert regionalnych, nie z cen
   PLN. Kontrola źródeł/fingerprintu przed paginacją; lokalna gramatura
   i wyraźne odróżnienie ceny orientacyjnej. 16 testów backendu; testy
   ekranu produktów obejmują zachowanie PL i brak nieprawidłowych ofert GBP.
2. Kalendarz konta: London dla GB, Warsaw dla PL. Tygodniowe limity,
   Dziennik, wygaśnięcie planów, automatyzacja i wyrażenia backfillu
   używają właściwego kraju. Nie zmieniono limitów ani uprawnień Premium.
3. Komentarze/moderacja i profil PL/EN, porównanie Premium i etykiety
   dokumentów. Ochrona złych zdjęć Base64, kontrolerów podczas zamykania
   dialogów i nieprawidłowej wagi. Zgodnie ze zgodą właściciela krótki
   panel wyboru diety ma przewijanie; zwykły wygląd pozostaje bez zmian.
4. Naprawione sprawdzanie dostępu do treści komentarzy i powiadomień:
   znany UUID nie omija prywatnego/pending/rejected przepisu; historyczne
   komentowanie lub ulubione nie nadają prawa do kolejnych wiadomości.
   Filtrowanie odbiorców jest grupowe, a nie N+1. Własne usuwanie i moderacja
   pozostają dostępne po utracie prawa do przeglądania przepisu.
5. Premium i kontekstowe korzyści PL/EN. Prawdziwe ceny nadal pochodzą
   ze sklepu, nie z waluty konta aplikacji. Trial 7 dni wymaga właściwej
   bezpłatnej fazy Google lub oferty Apple i potwierdzenia kwalifikacji.
   Błąd/timeout/stara odpowiedź nie obiecują darmowego okresu. Roczna
   oszczędność jest liczona z porównywalnych okresów i tej samej waluty.
   Nie zmieniono zakupu, tokenów, weryfikacji ani nadawania uprawnień.
6. Test ujawnił dosłowny znak `#` w nowo dodanych liczebnikach ARB;
   poprawiono go na jawne interpolacje i dodano test wszystkich plików ARB.
7. Warstwa OFF opisana osobno w `../uk-stage12/OFF-CATALOGUE.md`.

## Neon

`backend/scripts/check_uk_branch.py` wymaga osobnego pliku env i jawnego
potwierdzenia hosta direct gałęzi testowej. Nie uruchamia FastAPI, maili,
workerów, AI ani push. Dwie migracje, ponowny import, czytanie przez
asyncpg, blokada zmiany kraju i wyrażenie tygodnia London/Warsaw przeszły.
Kontrola hashy oryginalnych danych PL i listy tabel po rollbacku przeszła.
Wycofano także syntetyczny import OFF; nic nie pozostało zapisane.

Klon przed testem: 1265 użytkowników, 7 sklepów, 739 produktów,
2739 pozycji sklepów, 293 przepisy, 1899 składników. Z bazy pobierano
wyłącznie agregaty/hashy, nie prywatne rekordy ani sekrety.

## Weryfikacja i otwarte punkty

- Backend: `python -m pytest tests -q` — 1251 passed, 41 ostrzeżeń, exit 0.
- 15 testów prezentacji Premium, selekcji triala i starej odpowiedzi przeszło;
  dwa testy samych liczebników również przeszły.
- Test Premium 320 px / 150% odtworzył ucinanie nagłówka i plakietki.
  Po zgodzie właściciela usunięto sztywną wysokość tylko wtedy, gdy tekst
  się nie mieści, i dodano warunkowe przeniesienie plakietki pod tytuł.
  Plakietka triala w cenniku może zawijać tekst; zwykły układ i styl zachowano.
  [Zakres i dowody](../uk-stage12/PREMIUM-RESPONSIVE.md).
- Pełny zestaw Fluttera: 518 passed, bez niepowodzeń. 16 testów ekranu
  Premium obejmuje PL/GB, 320 px, tekst 150%/200%, jasny/ciemny motyw,
  niski ekran poziomy, trial i zachowanie oryginalnego nagłówka 250 px.
  Analiza pełna: exit 0, 0 błędów i 0 ostrzeżeń, 359 informacji/lintów.
  `git -c core.autocrlf=false diff --check`: exit 0 po normalizacji LF.
  To nie jest zielona bramka wydania: nie budowano AAB/IPA ani nie testowano telefonu.
- Archiwum i ekran automatyzacji zlokalizowano w etapie 13. Pozostają
  inne teksty/błędy, push/e-maile i dokumenty. Dokumenty otwierają
  dotychczasowe adresy.
- Kampanie nie mają jeszcze trwałego przypisania do kraju; przed UK trzeba
  rozdzielić je od polskich ofert i sprawdzić rzeczywiste ceny regionalne.
- Pozostają rzeczywiste lokalne SKU/ceny, mapowanie składników, tłumaczenie
  systemowych przepisów i porad oraz natywne/store testy i konfiguracja.
- Nie instalowano nowego pluginu ani nowej wersji SDK. Istniejący StoreKit
  0.4.11+2 zadeklarowano jawnie, ponieważ używamy jego API kwalifikacji triala.
