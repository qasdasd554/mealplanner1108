# Etap 48 — lokalne użycie OFF i krótsza ścieżka zakończenia UK

24.10.2026. Zmiany lokalne, backup w `../backups/uk-stage48-20261024/`.
Bez nowej funkcji, redesignu, migracji, wdrożenia i zmiany wersji 270.

## Usunięte powtórne szukanie

Po etapie 47 pierwszy zapis angielskiego składnika mógł poprawnie użyć
zaakceptowanego produktu o polskiej nazwie. Drugi przepis z tym samym
składnikiem nadal wyszukiwał tę angielską nazwę w OFF: resolver widział
lokalną nazwę produktu, ale nie alias z już zapisanego odczytu OFF.
Test pełnego zapisu odtworzył dwa wywołania zamiast jednego w czterech
wariantach SQLite.

Teraz nierozwiązane nazwy UK są najpierw sprawdzane jednym ograniczonym
odczytem istniejącego cache. Alias może wskazać tylko dokładny GTIN
zaakceptowanego produktu już obecnego w katalogu dostępnym wywołującemu.
Wymagane są aktualne dane UK z przypisanym źródłem i zgodność g/ml.

- Drugi zapis tego samego przepisu nie powtarza zapytania zewnętrznego.
- 30 wystąpień tej samej nazwy wymaga jednego zapytania lokalnego.
- Brak odczytu aliasów, gdy wszystkie nazwy już pasują lub kraj to PL.
- Cache nie nadpisuje autora, nazwy, opakowania ani makro produktu.
- Nie wybiera pierwszego z kilku SKU o jednakowej nazwie; nie promuje
  produktów pending/rejected ani nie udostępnia cudzych prywatnych wpisów.
- Odrzuca przeterminowany/przyszły cache, inny kraj/źródło, nieprawidłowy
  odcisk, niezgodną jednostkę i gotowe danie. Istniejąca ścieżka zewnętrzna
  oraz oznaczony brak danych pozostają ścieżkami awaryjnymi.
- Również edycja AI korzysta z aliasu. Sama zmiana języka etykiety nie jest
  zmianą przepisu i nie powoduje pobrania punktu.

Odczyt jest ograniczony do 30 nazw i maksymalnie 501 rekordów; przekroczenie
500 nie pozwala wybrać częściowego wyniku jako pewnej tożsamości. Nie ma
pełnego importu OFF, przeszukiwania internetu podczas scrollowania ani
nowych bibliotek. Nie zmieniono filtra dostępności kraju.

## Zmiana sposobu prowadzenia dalszych prac

Ręczne sprawdzenie wszystkich 390 produktów lub udostępnienie wszystkich
137 przepisów nie jest warunkiem zachowania polskiego modelu działania.
Brak dowodu kraju ma ukryć konkretny publiczny przepis, a nie blokować
cały rynek. Nadal nie wolno przedstawiać braku ceny jako £0 ani tłumaczyć
polskiej ceny przez podmianę symbolu waluty.

Dalsze prace są grupowane według zależności, nie według pojedynczych SKU:

1. Domknięcie danych potrzebnych do wyceny GBP i przekazania kontrolowanego
   zestawu startowego. Używać istniejących zatwierdzonych obserwacji,
   zgłoszeń i jawnych referencji. Średnia ONS nie jest ceną konkretnego
   sklepu i sama nie dowodzi rozmiaru opakowania. Uzupełnianie katalogu
   kontynuować na żądanie, nie przez pełny dump OFF do Neon.
2. Jedna zbiorcza kontrola wszystkich ścieżek UK/PL po partii zmian.
   Podczas implementacji uruchamiać test odtwarzający błąd i testy zależnych
   modułów; pełny backend raz na końcu partii. Fluttera nie powtarzać tylko
   dlatego, że zmienił się lokalny plik dowodowy OFF lub komentarz backendu.
3. Oddzielny etap wydania: angielskie dokumenty i konfiguracja sklepów,
   rzeczywiste urządzenia/logowanie/IAP/trial oraz świeży snapshot Codespace.
   Braku SDK/Xcode, publikacji dokumentów i zakupów nie ukrywać pod wynikiem
   testów jednostkowych. Nie włączać UK przed zamknięciem tych warunków.

To nie jest zgoda na publikację, zastępowanie niepotwierdzonych danych
domysłami ani osłabianie testów uprawnień, jednostek i finansów.

## Weryfikacja

Celowana partia resolvera, aliasów, źródeł i edycji: 212 passed; dodatkowa
regresja niezmienionej edycji AI: 4 passed. Testy używają lokalnego SQLite,
w tym trybu bez RETURNING zgodnego z wcześniejszym Codespace.
Pełny backend uruchomiony raz po całej partii: **3006 passed**, 43 istniejące
ostrzeżenia zależności/deprecacji, exit 0, 236,10 s
(`uk-stage48-backend-final.log`). Compileall, zgodność wersji i kontrola
UTF-8/LF bez BOM oraz końcowych spacji sześciu plików przeszły. SHA-256
zamrożonego ZIP-a nadal wynosi
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
Nie wykonywano nowego połączenia Neon ani natywnego buildu AAB/IPA.
