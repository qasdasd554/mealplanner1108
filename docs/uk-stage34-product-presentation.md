# UK — prezentacja danych produktu i podpowiedzi, 23.10.2026

Prace lokalne, bez wydania i aktywacji UK, bez nowego interfejsu lub funkcji.
Polskie rekordy pozostają bez zmian. Kopie poprzednich plików:
`../backups/uk-stage34-20261023/`.

## Odtworzone błędy i naprawa

Kontynuacja [próby na prawdziwym składniku systemowym](uk-stage33-real-seed-identity.md).
Dostępność ogólnego rodzaju składnika w UK nie dowodzi sprzedaży jego
polskiej przykładowej marki ani opakowania. Dotychczas API nadal zwracało
„Sante, 500 g” dla takiego składnika. Testy odtworzyły problem w katalogu,
szczegółach i spiżarni, z autoflush oraz bez niego.

Nowa projekcja odpowiedzi API dotyczy wyłącznie konta GB i niezmienionej
znanej tożsamości składnika systemowego bez GTIN. Ukrywa przykładową markę,
niepotwierdzoną gramaturę opakowania i jego miarę. Nie zmienia rekordu,
jednostki bazowej, makro, ilości w spiżarni ani miar łyżeczki/sztuki/szklanki.
Zwykła porcja i możliwość wpisania gramów/ml pozostają. Zeskanowany SKU,
produkt autora i inna tożsamość zachowują własne dane etykiety.

Oferta sklepu UK zachowuje oddzielnie sprawdzone lokalne opakowanie, nazwę
SKU i cenę; nie pożycza marki ani opakowania z ogólnego składnika PL.
To samo zabezpieczenie marki obejmuje istniejące zamienniki. Nie zmieniono
reguł wyboru zamiennika. Spiżarnia zachowuje zapisane ilości i jednostki.

Podpowiedzi po nazwie omijały filtr kraju oraz angielskie etykiety już
działające w głównym katalogu. Używają teraz tej samej kontroli dowodów UK
przed limitem wyników, uwzględniają wyszukiwanie „Oats” i stabilne sortowanie.
Nazwy podpowiedzi systemowych są angielskie, a polskie przykładowe marki,
opakowania i widełki PLN nie stają się faktami o brytyjskim produkcie.
Własne zgłoszenia są zachowane, podobnie jak dotychczasowe uprawnienia.

Nie dodano sieci ani N+1 do projekcji produktu. Nowy filtr jest częścią
istniejącego zapytania SQL. Cache i zewnętrzne wyszukiwanie mają dotychczasowy
przepływ; ponowne wyszukanie produktu z cache OFF nie wymaga kolejnej sieci.

## Kontrola danych cenowych

Ponownie otwarto dwa źródła na oficjalnej stronie Tesco:
[Grower's Harvest 1 kg](https://www.tesco.com/shop/en-GB/products/299669085)
oraz [Scottish Oats 1 kg](https://www.tesco.com/shop/en-GB/products/254853776).
Prywatne obserwacje i zgodność formatu zapisano w
`uk-stage34-reference-prices.json`, bez makro, zdjęć i wymyślonych GTIN.
Plik ma jawne `publication_approved: false` oraz `automatic_import: false`.
Żaden kod startowy, endpoint ani skrypt importujący go nie odczytuje.

Nie podłączono tego jako komercyjnego feedu: strony źródłowe opisują
ograniczenia dalszego wykorzystania informacji produktowych. Takie dwa
przykłady nie zapewniają pokrycia asortymentu kraju ani dziesięciu sieci.
Nie są też gwarancją ceny i dostępności dla konkretnego adresu.
Przed publikacją trzeba rozstrzygnąć uprawnione źródło cen, nie obchodzić
pochodzenia danych przez podmianę adresu źródła lub kopiowanie cen między sieciami.

## Weryfikacja i ograniczenia

Testy regresji kontrolują oba rynki, ochronę rzeczywistych SKU i produktów
autorów, brak zmian w ORM, kontrakt JSON/HTTP oraz zachowanie lokalnego
opakowania w ofercie. Testy Dart sprawdzają przydatną porcję zamiast 1 g,
brak fikcyjnego opakowania, obliczenie kcal dla 60 g i oddzielne pole
potwierdzonego opakowania SKU. Nie zmieniano produkcyjnego kodu Fluttera.

Pełna regresja wykryła także kruchy adapter jednego istniejącego testu:
kierował zapytanie do testowej bazy po samym wystąpieniu nazwy OFF w SQL.
Po dodaniu prawidłowej podkwerendy dostępności wysyłał tam zapytanie Product,
mimo że ta wąska baza zawiera tylko cache OFF. Adapter odróżnia teraz główną
encję SELECT/INSERT przez metadane SQLAlchemy. Nie osłabiono asercji o liczbie
wywołań zewnętrznej bazy. Test ponownego HTTP wyszukiwania przechodzi.

Końcowe wyniki po ostatnich zmianach kodu:

- Backend, domyślne `pytest -q`: **2283 passed**, 43 ostrzeżenia zależności,
  147,56 s, exit 0 (`uk-stage34-backend-confirmed.log`).
- OFF/HTTP i ścieżki prezentacji: **75 passed**, exit 0
  (`uk-stage34-off-adapter-verified.log`). Wcześniejsza szersza partia
  produktów, nazw i makro: **182 passed** (`uk-stage34-targeted-green.log`).
- Trzy pliki testów Dart miar/kontraktu: **21 passed**, exit 0
  (`uk-stage34-dart-contract-final.log`). Początkowa próbka lokalnego SKU
  nie zawierała wymaganego `availability_scope`; uzupełniono próbkę zgodnie
  z rzeczywistym API, nie osłabiano kontroli aplikacji.
- Analiza nowego testu Dart: **No issues found**, exit 0
  (`uk-stage34-dart-analyze.log`). Nie jest to analiza całego Fluttera.
- Compileall zmienionych modułów i kontrola whitespace: exit 0.
- Dwa prywatne szkice cen przeszły walidację `UKProductProposal`; bez importu,
  sieci w walidatorze ani podłączenia do uruchomienia aplikacji.

Zamrożony ZIP 270 ma ponownie ten sam SHA-256:
`ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.
Etapy 32–34 nie znajdują się w tej przekazanej wcześniej paczce.

UK nadal jest wyłączone. Nie wykonano migracji/edycji Neon, wdrożenia,
zakupu usług ani zmiany wersji 1.0.69+270. Nie wykonywano AAB/IPA ani prób
aparatu, udostępniania i zakupów na telefonach. Pozostają rzeczywiste dane
UK, dokumenty i testy natywne przed publicznym uruchomieniem.
