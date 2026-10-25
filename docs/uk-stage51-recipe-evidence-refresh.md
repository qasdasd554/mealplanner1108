# UK — odświeżanie użytych składników bez ponownego skanowania

24.10.2026. Prace lokalne, UK nadal wyłączone. Backup zmienianych plików:
`../backups/uk-stage51-20261024/`. Bez migracji, nowej funkcji w interfejsie,
zmiany wersji 270, wdrożenia, ZIP-a, workera ani płatnej usługi.

## Odtworzony problem

Dotychczas dokładny użyty kod odświeżał cache po skanowaniu albo w istniejącej
ścieżce administratora. Sam odczyt katalogu przepisów nie uruchamiał tego
mechanizmu. Po wygaśnięciu faktów OFF (30 dni) poprawnie zapisany przepis UK
mógł zniknąć z publicznego katalogu, nawet jeśli ludzie korzystali z przepisów,
ale nie skanowali ponownie danego opakowania.

Test HTTP przed poprawką: cztery warianty GB kończyły się bez zadania
odświeżającego (4 failed); cztery warianty PL przechodziły bez zmian.
Osobny test pokazuje pusty wynik filtra dla wygasłych faktów, odświeżenie
tego samego kodu i ponowną dostępność przepisu przy kolejnym odczycie.
Dotyczy to dokładnego GTIN oraz zatwierdzonego powiązania składnika ogólnego.

## Naprawa i ograniczenia obciążenia

Po odpowiedzi `GET /recipes/` dla konta GB dodawane jest zadanie best-effort:

- Przed rollbackiem materializuje się lekki rekord odpowiedzi, także autor,
  warunkowy TikTok, ulubione i własność przepisu. Ciężkie zdjęcia, instrukcje
  i relacja składników nie są dodatkowo ładowane.
- Transakcja tylko do odczytu jest zwalniana **przed wysłanym w tle HTTP**.
  Test ASGI potwierdza kolejność: odpowiedź telefonu, potem zadanie.
- Co najwyżej jeden ograniczony SELECT na proces i minutę. Maksymalnie
  osiem kandydatur, dwa poprawne istniejące kody do pobrania. Nie ma
  przeszukiwania OFF po nazwie ani pełnego skanowania zewnętrznego katalogu.
- Selekcja obejmuje tylko zaakceptowane produkty rzeczywiście użyte jako
  wymagane składniki aktywnych publicznych/systemowych przepisów oraz
  przypisane im oficjalne fakty OFF UK starsze niż siedem dni.
- Dla składników ogólnych muszą nadal zgadzać się przegląd, nazwa, marka,
  jednostka, wymiar i odcisk. Zmiana tożsamości, status pending i dane
  przyszłe nie są automatycznie naprawiane ani promowane do katalogu.
- Działają te same limity co dla skanów: maksymalnie sześć pobrań HTTP/minutę,
  dwa jednocześnie, deduplikacja GTIN/UPC/EAN, pięć minut przerwy dla kodu
  oraz backoff po 429/503. To limity procesu, nie rozproszona blokada wszystkich
  instancji Rendera. Ścieżka katalogu nie tworzy trwałej kolejki.
- Kod w cooldownie jest pomijany już w selekcji, żeby dwa nieudane kody
  nie blokowały pozostałych. Jedno zadanie ma limit 13 sekund; każdy istniejący
  dokładny odczyt zachowuje własne limity czasu i rozmiaru odpowiedzi.
- Każda sesja selekcji/odczytu zamyka się przed połączeniem z OFF. Timeout,
  błąd bazy lub providera nie psuje już wysłanej listy. Anulowanie zadania
  zwalnia blokadę uruchomienia i nie jest połykane jako zwykły błąd.

Nie zmieniono zachowania PL, uprawnień do prywatnych przepisów, paginacji,
wyglądu, ceny, makro ani opakowania produktu. UK nie zostało aktywowane.

## Nie jest to automatyczna ponowna akceptacja

Niezmieniona projekcja OFF otrzymuje prawdziwy nowy czas pobrania i działa
bez nowego skanu lub ręcznego przeglądu. Jeśli źródło zmieni zatwierdzony
odcisk, dotychczasowy przegląd nie jest przepisywany. Taki składnik nadal
wymaga kontroli tożsamości. Nie wolno odświeżać wyłącznie dat, podstawiać
podobnego SKU albo automatycznie przenosić cudzych makro/gramatur.

Nie ma gwarancji odświeżania bez ruchu w aplikacji, działania po ubiciu
procesu ani natychmiastowego odświeżenia wszystkich nieużywanych produktów.
Nowe fakty są widoczne przy kolejnym odczycie; nie przedłużamy wygasłych
danych tylko po to, żeby pokazać więcej przepisów. ONS i obserwacje cenowe
mają odrębne daty i mechanizmy — pobranie OFF nie odmładza ich cen.

## Sprawdzenie PostgreSQL

W udostępnionej gałęzi testowej Neon sprawdzono rzeczywisty skorelowany
SELECT oraz wykluczenie już próbowanych kodów:
`recipe_off_refresh_selection_pg: true`, `rollback_verified: true`.
Próba nie wykonywała żadnych wywołań OFF ani startu aplikacji, a cała
transakcja została wycofana. Produkcja nie została zmieniona.

## Weryfikacja lokalna

Celowana partia: **247 passed**, jedno istniejące ostrzeżenie zależności,
exit 0 (`uk-stage51-focused.log`). Zawiera HTTP/ASGI, SQLite z autoflush i bez
niego, wariant bez RETURNING jak we wcześniejszym Codespace, kontrolę
paginacji/autorów, budżetów, anulowania, błędów i niezmienności przeglądu.
Compileall i kontrola końców linii przeszły. W tej partii nie zmieniono
Fluttera, więc nie powtarzano jego pełnego zestawu tylko dla backendowego
odświeżania cache. Nie wykonano buildu AAB/IPA ani testów natywnych.

Pełny backend po całej partii: **3164 passed**, 43 istniejące ostrzeżenia,
exit 0, 257,26 s (`uk-stage51-backend-final.log`). Zgodność wersji 1.0.69
pozostaje zachowana. Zamrożony ZIP ma niezmieniony SHA-256
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
