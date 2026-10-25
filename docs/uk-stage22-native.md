# Etap 22 — natywne zasoby językowe iOS, 22.10.2026

## Zakres

- Runner ma polskie i angielskie `InfoPlist.strings` opisujące dotychczasowe
  użycie aparatu i galerii. Polski tekst jest identyczny z istniejącym
  `Info.plist`; jego bazowe opisy i nazwa Meal Planner Polska pozostają.
- ShareExtension używa standardowego `NSLocalizedString` dla ośmiu istniejących
  tekstów, w tym przycisku Gotowe. Nie zmieniono odczytu linku, walidacji URL,
  App Group, klucza zapisu, otwierania aplikacji ani przetwarzania przepisu.
- Obie tabele mają osobne grupy wariantów, odwołania pl/en i wpisy Resources
  we właściwych targetach Xcode. `developmentRegion = pl` i `knownRegions`
  nie zmieniły się. Nie zmieniono brandingu, Bundle ID ani podpisu aplikacji.
- Natywne zasoby wybiera standardowy mechanizm języka aplikacji/iOS, także
  przed logowaniem. Nie dodano synchronizacji kraju konta do App Group.
  Język zalogowanej części Flutter nadal wynika z dotychczasowego kraju konta.

## Backup i weryfikacja

Przed edycją powstał backup poza checkoutem:
`../backups/uk-native-before-20261022-1820-paths.zip` (10 298 bajtów).
Obejmuje oba Info.plist, ShareViewController.swift i project.pbxproj.
Zachowuje jednoznaczne ścieżki obu plików Info.plist; pierwotny ZIP z płaskimi
nazwami również pozostał zachowany, ale do odtwarzania należy użyć wersji `paths`.

`ENVIRONMENT=test python -m pytest tests/test_ios_market_resources.py -q`:
**7 passed**, exit 0. Testy najpierw wykazały brak plików i ich rejestracji,
następnie przeszły po dodaniu zasobów. Sprawdzają zgodność kluczy, zachowanie
polskich tekstów i brandingu, składnię źródłową `.strings`, odwołania kontrolera,
powiązania wariantów z zasobami właściwych targetów i unikalność ID obiektów.

To testy statyczne, nie test wykonania systemowego okna uprawnień. W środowisku
Windows nie wykonano `xcodebuild`, `plutil`, archiwizacji IPA ani testu urządzenia.
Przed wydaniem potrzebny jest build na macOS oraz ręczne sprawdzenie zgód
aparatu/galerii i udostępniania linku dla języka polskiego i angielskiego.
Nie wykonano wdrożenia, podbicia wersji, aktywacji UK ani zmiany uprawnień.
