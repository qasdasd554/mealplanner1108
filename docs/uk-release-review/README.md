# Dokumenty UK — projekty, nie publikacja

## Aktualizacja: istnieją już publiczne strony angielskie

Po wskazaniu adresu przez właściciela 24.10.2026 sprawdzono cztery strony
bez prefiksu `/en/`: `https://mealplannerworld.com/privacy-policy.html`,
`terms-of-use.html`, `delete-account.html` i `support.html`. Wszystkie zwracają
HTTP 200, mają język angielski, właściwe nagłówki, treść i kontakt
`support@mealplannerworld.com`. Treść podaje datę 15.10.2026. Wcześniejsze
404 dotyczyły wyłącznie nieprawidłowych ścieżek `/en/`, nie braku dokumentów.

Nie trzeba publikować kolejnych kopii ani zastępować tych stron starszymi
lokalnymi szkicami. Poniższy katalog review zachowano jako historyczny
materiał do przeglądu; nie jest źródłem aktualnie opublikowanej treści.
Checker sprawdza teraz prawidłowe adresy główne i nie wymaga prywatnych
atrybutów HTML z naszych projektów. Dostępność stron i formalne zatwierdzenie
ich treści są odrębnymi sprawami. Nie wysyłano wiadomości testowej, więc
obecność adresu kontaktowego nie potwierdza działania skrzynki.

Przygotowano 24.10.2026 na podstawie czterech rzeczywistych polskich stron
z datą treści 14.10.2026. Starsze pliki `docs/privacy-policy.html`,
`docs/terms-of-use.html` i `docs/support.html` nie są aktualnym źródłem strony.
Nie zostały nadpisane. Sam etap projektów nie zmieniał aplikacji. Późniejsza
lokalna poprawka 24.10 podpięła istniejące strony UK i brytyjski kontakt do
rejestracji, Premium i profilu. PL zachowuje dotychczasowe linki; konfiguracja
sklepów, wersja 270 i przełącznik UK nie zostały zmienione.

## Co jest gotowe lokalnie

- `en/privacy-policy.html` — angielski projekt polityki prywatności.
- `en/terms-of-use.html` — angielski projekt regulaminu/EULA.
- `en/delete-account.html` — instrukcja usuwania konta, wraz z wyraźnym
  rozróżnieniem otwarcia programu pocztowego i wysłania zgłoszenia.
- `en/support.html` — pomoc i kontakt.
- `sources/*.html.txt` — tekstowe migawki stron, nie uruchamiane kopie witryny.
- `manifest.json` — źródła, daty, odciski, stan draft i lista spraw do decyzji.

Każdy projekt ma wyraźny komunikat DRAFT, `noindex,nofollow`, angielski język,
poprawne lokalne odnośniki i kontakt `kontakt@mealplannerpolska.pl`. Nie ma
skryptów analitycznych ani aktywnego formularza zbierającego dane. To strony
do przeglądu treści, nie redesign witryny. Nie kopiować katalogu review na
produkcję jako zatwierdzonych dokumentów.

To tłumaczenie źródła i notatki dla recenzenta, nie zaświadczenie zgodności
z prawem ani nowa umowa. Źródłowe obietnice, np. dotyczące 24 godzin na
moderację, natychmiastowego usunięcia danych i 30 dni na kopie zapasowe,
nie zostały uznane za udowodnione przez sam fakt tłumaczenia.

## Co wymaga potwierdzenia

1. Pełna tożsamość prawna i dane kontaktowe operatora/administratora danych.
   Marka aplikacji i nazwa katalogu na komputerze nie są takim potwierdzeniem.
2. Przegląd dokumentu dla UK, w tym właściwe informacje o prawach użytkownika
   i podstawach przetwarzania informacji dotyczących zdrowia/diety.
3. Rzeczywiści dostawcy, regiony przetwarzania i zasady transferów danych.
   Nie można potwierdzić umów/DPA i całej zgodności dostawcy testem aplikacji.
4. Faktyczna retencja kont, zdjęć, zadań importu, logów, rozliczeń i kopii
   zapasowych. Trzeba też uzgodnić siedem dni versus siedem dni roboczych
   dla zgłoszeń mailowych — oba sformułowania występują w obecnym źródle.
5. Warunki konsumenckie, subskrypcje, trial oraz brzmienie licencji Apple.
   Repozytorium zawiera osobną klauzulę licencji do treści użytkowników,
   której nie ma w aktualnym publicznym regulaminie. Nie łączymy tych
   dokumentów po cichu ani nie zmieniamy umów już zawartych przez użytkowników.

## Potwierdzona domena UK

24.10.2026 właściciel potwierdził na czacie, że `mealplannerworld.com` jest
jego domeną. Poprawne adresy czterech dokumentów to
`https://mealplannerworld.com/*.html`; checker sprawdza je bez pośredniego
przekierowania z polskiej witryny. Historyczne źródła pozostają na
`mealplannerpolska.pl` i nie zostały przepisane na nową domenę.

Kontrola niepoprawnego prefiksu `/en/` zwróciła wcześniej 404. Kontrola
właściwych adresów głównych zwraca **200 dla wszystkich czterech stron**.
Potwierdzenie własności domeny nie jest zatwierdzeniem projektów dokumentów
ani oceną prawną opublikowanej treści. Działające linki PL pozostają bez
zmian, a UK ma już lokalnie podpięte istniejące strony główne i kontakt
`support@mealplannerworld.com`. Poprawka czeka na uzgodnione wydanie aplikacji.

Lista jest techniczną listą do przeglądu, nie pełnym audytem prawnym.
Wskazówki dotyczące treści informacji prywatności:
[ICO — What privacy information should we provide?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/).
Wytyczne zawierają również zastrzeżenie o aktualizacji w związku z Data
(Use and Access) Act; publikację powinien zatwierdzić operator z odpowiednią
pomocą prawną, nie automat.

Źródła użyte do tłumaczenia:
[polityka](https://mealplannerpolska.pl/privacy-policy.html),
[regulamin](https://mealplannerpolska.pl/terms-of-use.html),
[usuwanie konta](https://mealplannerpolska.pl/delete-account.html),
[pomoc](https://mealplannerpolska.pl/support.html).

## Kontrola przed wydaniem

Z katalogu repozytorium, interpreterem z zależnościami backendu:

```bash
python scripts/check_uk_documents.py
python scripts/check_uk_documents.py --check-published --require-ready
```

Pierwsze polecenie jest lokalne i niczego nie publikuje. Sprawdza treść plików,
odciski, język, oznaczenie projektu, komplet czterech stron, kontakt i odnośniki.
Odciski są liczone z tekstu po ujednoliceniu CRLF/LF i BOM UTF-8, żeby zwykły
checkout Windows/Linux nie udawał zmiany zatwierdzanej treści. Rzeczywista
zmiana tekstu nadal unieważnia odcisk.
Drugi wariant wykonuje wyłącznie cztery odczyty HTTPS. Nie uruchamia skryptów,
nie wysyła formularzy/maili i nie podąża za przekierowaniem na inną stronę.
Zbyt duża odpowiedź, inny język, HTML innego dokumentu, projekt zamiast
publicznej treści lub sam status 200 nie wystarczą do gotowości całego wydania.
Nie wymagamy niestandardowych atrybutów `data-publication-state` i
`data-document` na istniejącej witrynie; kontrolujemy rzeczywisty nagłówek
dokumentu, język, tożsamość aplikacji i kontakt. Skrypty i formularze strony
nie są wykonywane przez checker.

Aktualny prawidłowy wynik to `structure_passed: true`, `approved: false`,
`ready_for_release: false`. Przy `--require-ready` kod 2 oznacza świadomie
zablokowane wydanie, nie awarię aplikacji. Samo ustawienie `approved: true`
w manifeście nie wystarczy: projekty i nierozwiązane pytania nadal blokują
kontrolę. Automat nie weryfikuje kompetencji recenzenta i nie zastępuje
rzeczywistego zatwierdzenia treści.

Do wydania używamy istniejącej treści na potwierdzonej domenie, po jej
przeglądzie względem faktycznego działania UK. Nie nadpisujemy jej lokalnymi
projektami. Prawidłowe URL są już podpięte lokalnie w aplikacji; do wydania
pozostaje konfiguracja lokalizacji App Store Connect/Google Play. Nie przekierowujemy użytkowników
do szkiców. Potwierdzona publikacja przechodzi już kontrolę techniczną;
nie oznacza to automatycznego zatwierdzenia prawnego treści.
