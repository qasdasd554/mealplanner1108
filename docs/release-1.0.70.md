# Wydanie 1.0.70+271 — przygotowanie UK do testów

Paczka zbiorcza na dokładnym eksporcie Codespace `9623b28`, wersja 1.0.69+270.
Nie jest publiczną aktywacją UK. Domyślnie `UK_MARKET_ENABLED=False`.
Nie importuje danych do produkcyjnego Neon i nie tworzy usług na Renderze.

Obejmuje lokalne zmiany UK opisane w `UK-EXPANSION.md`, od powiązań i
odświeżania OFF na żądanie, przez zatwierdzone źródła wycen GBP i ich
etykiety, po dokumenty/kontakt UK. PL zachowuje kraj konta, walutę i sklepy.
Nie ma pełnego importu OFF do Neon. Gotowość danych danego przepisu nadal
podlega kontroli; brak źródła ceny nie jest kosztem zero.

W zestawie są testy regresyjne i kontrolowany importer danych startowych
z rollbackiem jako domyślnym trybem. Nie zastępujemy źródeł aktualnymi
datami ani nie uznajemy średnich ONS za ceny konkretnego sklepu.

Do testowego APK dodano jawne `API_BASE_URL` dla debug/profile z walidacją
HTTPS. Release je ignoruje. Nie zmieniono domyślnego adresu produkcyjnego.
Instrukcja z ZIP-a rozdziela build sklepowy i bazę/serwer/nowe konto UK.

Powiadomienie po polsku:

- Usprawniliśmy dopasowywanie składników w przepisach AI.
- Poprawiliśmy obsługę opakowań i danych odżywczych podczas skanowania produktów.
- Dopracowaliśmy listy zakupów i oznaczanie niepełnych wycen.
- Poprawiliśmy czytelność i spójność komunikatów aplikacji.

Raport walidacji przekazany obok ZIP-a oddziela rzeczywiste testy kodu od
symulacji natywnego buildu. Brak Android SDK/Xcode na tym Windowsie:
instalator wymaga rzeczywistego buildu AAB w Codespace przed commitem/pushem.
