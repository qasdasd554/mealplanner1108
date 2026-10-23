# Meal Planner 1.0.68+269

Źródło: czysty eksport Codespace 49576a630d429cb73b84d061bf054cb003323eee,
wersja 1.0.67+268. Paczka przyrostowa zachowuje poprzednie wdrożone poprawki.

Najważniejsze: ogólny mechanizm brakujących składników AI, oznaczenie braków
makro zamiast zer, stabilny podgląd autora, listy ze składników i aktualnych
ilości, poprawki logowania/aparatu oraz dobrowolna natywna prośba o ocenę
w spokojniejszym momencie. Szczegóły i ograniczenia:
[raport](recipe-discovery-and-review-20261023.md),
[listy zakupów](shopping-ingredient-source-20261023.md).

Nie zmieniamy wyglądu całej aplikacji i nie włączamy publicznie rynku UK.
Nie naprawiano produkcyjnego starego przepisu przez zgadywanie jego składu.

## Wdrożenie

Instalator tworzy backup, sprawdza dokładny commit i hashe, uruchamia wersje,
formatowanie, analizę i testy, buduje prawdziwy AAB, a dopiero potem robi
commit i push. Błąd przed commitem przywraca pliki. Zachowuje stare AAB-y
i nieśledzone raporty. Nie dodaje ich do Git.

Po pushu sprawdź pomyślny deploy backendu na Renderze. Gdy automatyczny
deploy jest wyłączony, użyj Manual Deploy → Deploy latest commit. Jeśli
ustawiasz APP_VERSION ręcznie, zmień na 1.0.68; w przeciwnym razie wersja
wynika z repozytorium/fallbacku backendu. Nie ma nowej migracji SQL względem 268.

Po opublikowaniu wersji w danym sklepie ustaw na Renderze odpowiednio
LATEST_ANDROID_VERSION_CODE=269 i LATEST_IOS_BUILD_NUMBER=269. Nie ustawiaj
ich przed dostępnością wersji na danej platformie. Nie zmieniaj FORCE_UPDATE.
Tekst powiadomienia PL/GB zaktualizowano w zasobach aplikacji. Starsze klienty
zachowują swój starszy tekst do czasu instalacji aktualizacji.

Po instalacji pobierz app-release-1.0.68-269.aab. Natywne okna ocen, aparat,
Google/Apple login, zakupy i iOS wymagają testu na urządzeniu. Lokalna
symulacja budowania nie jest rzeczywistym buildem Androida.
