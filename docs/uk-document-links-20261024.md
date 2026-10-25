# Dokumenty i kontakt UK — lokalne powiązanie z aplikacją

24.10.2026. Backup przed zmianą: `../backups/uk-document-links-20261024/`.
Bez publikacji, wdrożenia, zmiany wersji 270, nowego ZIP-a i aktywacji UK.

## Przyczyna i zmiana

Angielskie etykiety przycisków nie zmieniały ich adresów: współdzielony
panel Premium/profilu oraz rejestracja korzystały ze statycznych linków PL.
Testy odtworzyły otwarcie polskiego regulaminu przez ekran GB oraz kopiowanie
polskiego maila z brytyjskiego okna kontaktowego.

`AppLinks.forCountry` zwraca niezmienny zestaw dokumentów i kontaktu.
Dotychczasowe stałe PL pozostają kompatybilne. Współdzielony panel i
rejestracja używają lokalizacji głównej aplikacji: dla konta pochodzi ona
z zapisanego kraju, nie z ponownego odczytu regionu telefonu; przed
rejestracją region ustala istniejąca logika aplikacji. Brak lub nieobsługiwany
kraj zachowuje dotychczasowy PL. Nie dodano przełącznika kraju.

| Rynek | Dokumenty | Kontakt |
| --- | --- | --- |
| PL | `https://mealplannerpolska.pl/*.html` | `kontakt@mealplannerpolska.pl` |
| GB | `https://mealplannerworld.com/*.html` | `support@mealplannerworld.com` |

Cztery pliki to `terms-of-use.html`, `privacy-policy.html`,
`delete-account.html`, `support.html`. Ścieżka UK nie ma prefiksu `/en/`.
Istniejące strony publiczne sprawdzono po HTTPS; lokalne projekty review nie
zostały opublikowane ani nadpisane na stronie. Adres kontaktowy UK pochodzi
z istniejącej witryny; nie sprawdzano dostarczalności wiadomości i nie
wysyłano maila bez zgody. Techniczna dostępność nie jest oceną prawną.

Gdy nie ma aplikacji pocztowej, okno pokazuje i kopiuje dokładnie adres
z wcześniejszej próby otwarcia. Nie przełącza go po cichu na kontakt PL.
Nie zmieniono kolorów, układu ani liczby przycisków. Wybór linków jest
lokalny i nie dodaje żądań HTTP przy wyświetlaniu ekranu.

## Weryfikacja

Przed poprawką regresje GB zwracały rzeczywiste adresy PL. Po poprawce
celowana partia konfiguracji, panelu, rejestracji, rynku i żądań konta
przeszła 37 testów. Dodano też próbę panelu GB przy szerokości 320 px i
czcionce 150%. Pełny Flutter po wszystkich zmianach: **1120 passed**, exit 0,
3 min 49 s (`uk-document-links-flutter-full.log`). Kontrola publikacji:
**31 passed** i cztery poprawne strony HTTPS, bez zmiany zatwierdzenia treści.
Pełna analiza (`uk-document-links-analyze.log`) nie wykryła błędów ani
ostrzeżeń; zgłosiła 391 uwag informacyjnych, w tym uwagi w dopisywanych
testach, które następnie usunięto. Końcowa analiza sześciu zmienionych
plików (`uk-document-links-target-analyze.log`) ma tylko dwie wcześniejsze
uwagi informacyjne w rejestracji i kod 0, bez błędów i ostrzeżeń.
Testy używają atrap przeglądarki, poczty
i WebView — nie są testem natywnego zakupu, aparatu ani prawdziwego logowania.

Nie zmieniono backendu, danych Neon, konfiguracji sklepów ani
`UK_MARKET_ENABLED=False`. Natywne próby Android/iOS i uzgodnione wydanie
pozostają odrębnym etapem; ten komputer nie ma Android SDK ani Xcode.
