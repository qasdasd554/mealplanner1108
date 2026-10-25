# Etap 17 — składniki list zakupów, porównanie cen i zaakceptowane oferty

22.10.2026. Wersja pozostaje 1.0.66+267, UK_MARKET_ENABLED=False.
Nie przygotowano wydania ani paczki, nie wykonano push/deploy. Nie zmieniono
produkcji. Zapytanie diagnostyczne do udostępnionej kopii Neon było tylko
do odczytu; nie uruchamiało aplikacji, migracji, workerów ani AI.

## Nowa prośba właściciela: PL oraz UK

1. Lista ma zawierać rzeczywiste składniki przepisu i ich ilości, nie
   gotowy posiłek o podobnej nazwie. Nie ma wyjątku dla konkretnego dania.
2. Porównanie cen listy utworzonej z przepisu nie może wymagać dostępnego
   aktywnego planu posiłków.
3. Właściciel osobno zaakceptował: oferty co 24 godziny na konto,
   3 sekundy i 120 px przewinięcia przepisu, maksymalnie jedno automatyczne
   okno na sesję; inne konteksty po udanym zapisie. Bez przerywania edycji,
   aparatu czy aktywnego Premium, z zachowanym „Nie teraz”.

To jawnie zatwierdzone poprawki PL/GB, nie nowe funkcje wymyślone w ramach
lokalizacji UK. Nie zmieniono wyglądu, cen, warunków triala ani uprawnień.

## Lista ze składników

- Builder nadal korzysta z zapisanych `RecipeIngredient.product_id`, ilości
  oraz mnożników porcji, nie z wyszukiwania gotowego dania po tytule przepisu.
- Przed zapisem lub przebudową kontroluje podejrzane przypisanie całego
  dania do jego własnego przepisu. Nazwy są normalizowane, porównywany jest
  rdzeń tytułu i sygnały dania z dodatkami / gotowego posiłku, z wyjątkami
  dla komponentów takich jak pasta curry, przyprawa, sos, masło itp.
  Nie jest to wyczerpujący klasyfikator wszystkich potraw z samej nazwy.
- Przepis z takim błędnym składnikiem nie tworzy fałszywej listy. Zwracany
  komunikat wskazuje składnik do poprawy. Kontrola `/from-recipes` jest
  przed dopisaniem wpisów do istniejącej listy i przed naliczeniem limitu.
- Import AI nie podpowiada gotowego posiłku jako zamiennika surowego mięsa.
  Prompty PL/GB wymagają rzeczywistych składników. Nie wykonuje się
  dodatkowych wywołań AI przy tworzeniu listy.
- Dopasowanie wszystkich składników jest wymagane PRZED pobraniem punktów.
  Usunięto ciche pomijanie niedopasowanego produktu oraz odrzucanie tylko
  nieprawidłowego wiersza podczas czyszczenia odpowiedzi AI. Zamiast
  niepełnego przepisu jest błąd walidacji bez zapisu i bez pobrania punktów.
- Test integracyjny dla PL i GB potwierdza cztery dokładne składniki
  (mięso, ziemniaki, jajka, bułka tarta) i ilości. Nawet tańsze gotowe danie
  obecne w tym samym katalogu nie zostaje wybrane. Osobne testy obejmują
  pełną nazwę zgłoszoną przez właściciela, inne rodziny dań, komponenty
  oraz wszystkie oficjalne przepisy z seeda.

W dostarczonej kopii testowej nie było przepisu „Schabowy w mlecznej
marynacie z młodą kapustą i puree ziemniaczanym”. Nie zmieniono więc jego
rzeczywistego zapisu. Nie rozkładamy gotowego dania automatycznie na
domyślone składniki ani gramatury. Już błędne przepisy wymagają poprawy
ze źródła/autora, nie masowej podmiany produktów w produkcji.

## Porównanie aktualnego koszyka

- Polska zakładka Zakupy korzysta teraz z listowego endpointu, jak UK.
  Techniczny plan listy nie jest traktowany jak usunięty/archiwalny plan
  użytkownika. Planowy endpoint pozostaje bez zmian dla jego konsumentów.
- Listowy endpoint i zmiana sklepu obsługują PLN. Czytają faktyczne pozycje
  listy (w tym ręczne/scalone i stan kupienia), nie regenerują przepisów.
- Zmiana sklepu jest walidowana w całości przed mutacją i chroniona
  SAVEPOINT-em. Kupione pozycje zachowują swój zapis ceny/produktu,
  spiżarnia nie jest odliczana drugi raz. Niepełny koszyk nie jest
  oznaczany najtańszym, brak ceny nie oznacza 0 zł/£0.
- Niezależny przegląd znalazł błędną konwersję nieznanej jednostki na gramy.
  Poprawiono ją i dodano 50 regresji: nieznana szklanka/waga sztuki nie
  dostają zmyślonej ceny, a dokładne sztuki/opakowania nie wymagają masy.
  Konwersje masy/objętości wymagają jednoznacznego zapisanego przelicznika;
  zaokrąglanie opakowań używa dokładnego ilorazu, nie obciętego float.
- Uprawnienia właściciela/zaakceptowanego współdzielenia i rynek LISTY
  są zachowane. Nie ma cichej zmiany PLN na GBP przy współdzieleniu.

Ograniczenie starego modelu PL: wiersz bez oferty źródłowej ma tylko
`custom_name`, bez kanonicznego ID produktu. Taki wiersz pozostaje
niewyceniony, nawet gdy potencjalnie istnieje oferta w innym sklepie.
Nie zgadujemy tożsamości po podobnej nazwie; nie dodano tu nowej migracji.

## Premium i komunikat aktualizacji

- Backend nadal atomowo rezerwuje ofertę warunkowym UPDATE konta.
  Zmieniony jedynie globalny odstęp z 48 na 24 godziny, bez podziału PL/GB.
- Klient sprawdza sesję/konto ponownie po odpowiedzi serwera, aktualną
  trasę, aktywność aplikacji i edycję tekstu. Zachowuje jeden automatyczny
  pokaz w sesji, nie blokuje funkcji przy awarii API.
- Przepis: wspólne stałe 3 s i 120 px. Plan i lista: po udanej czynności.
  Dziennik/spiżarnia/zapis skanu: lokalny sygnał po sukcesie, sprawdzany
  z ekranu głównego po 2 s; jeśli formularz/aparat nadal jest otwarty,
  opcjonalne przypomnienie jest pomijane. Sygnał nie wysyła żądania sam.
- Nie zmieniono dostępności ani ceny 7-dniowego triala w sklepach.
- Tekst aktualizacji ma trzy aktualne punkty PL/en/en_GB: listy ze
  składników i porównanie cen, kompletność importu, stabilność ekranów.

## Weryfikacja i granice dowodu

Logi aktualnego przebiegu: `uk-stage17-backend-final.log`,
`uk-stage17-flutter-final.log`, `uk-stage17-analyze-final.log`.
Wyniki końcowe zapisano w `VALIDATION.md` po zakończeniu poleceń.
Red/green dla błędu listowego, niepełnego importu, ogólności kontroli
oraz częstotliwości Premium są zachowane w lokalnych logach.

Testy backendu używają lokalnego SQLite i atrap zewnętrznych usług.
Nie pobierają rzeczywistych cen, nie uruchamiają płatnego Gemini ani push.
Widget-testy i analiza nie dowodzą przejścia natywnego AAB/IPA.
UK nadal wymaga dalszej lokalizacji, danych katalogowych zgodnych
z zatwierdzoną polityką i prób natywnych. Nie jest to ukończone wydanie UK.
