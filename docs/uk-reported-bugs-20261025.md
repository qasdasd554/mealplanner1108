# UK — zgłoszenia z pierwszego testu telefonu, 25.10.2026

Zmiany po wydaniu 1.0.70+271, przygotowane jako 1.0.71+272 na dokładnym
eksporcie Codespace a03450c. Nie zmieniono wcześniej przekazanego ZIP-a,
nie wykonano push, wdrożenia Render ani zapisu do produkcyjnej bazy.

## Przyczyny i poprawki

1. **Polskie przepisy mimo istniejących tłumaczeń.** Generator indeksu czytał
   deklaracje AST, ale `seed.py` po deklaracjach zmienia ` — ` na `. ` w opisach.
   Odcisk/opis części rzeczywistych rekordów nie pasował do indeksu. Generator
   uwzględnia tę samą normalizację; indeks i dane Fluttera zostały odtworzone.
   Nowy test porównuje wszystkie 137 rzeczywistych systemowych przepisów,
   a nie tylko dwa wygenerowane pliki. Autorzy, ID, ilości, instrukcje PL,
   fotografie i rekordy użytkowników nie są przepisywane. Wszystkie te przepisy
   mają istniejące zdjęcia w mapie aplikacji; nie generowano nowych obrazów.

2. **Pusty katalog produktów UK.** Lista odrzucała systemowy składnik, gdy nie
   miał osobno zaimportowanego dowodu UK. Katalog ogólnych składników do
   gotowania jest teraz dostępny z istniejących 390 rekordów i sprawdzonego
   słownika angielskiego. Nie tworzymy 390 duplikatów w Neon. Projekcja UK nie
   udaje dostępności polskiej marki, polskiej wielkości opakowania ani ceny GBP.
   Obce zgłoszenia oczekujące, zeskanowane SKU i dania restauracyjne nie uzyskują
   wyjątku systemowego na podstawie podobnej nazwy.

3. **Brak puli do generatora.** Kod testował import startowy, ale zwykłe
   wdrożenie go nie wykonywało. Gotowy, zahashowany pakiet 31 przejrzanych
   powiązań OFF jest teraz także małą referencją dostarczaną z kodem, bez
   sztucznego administratora i importu na starcie. Zachowuje daty obserwacji
   23–24 października i limit 30 dni. Powiązanie wymaga dokładnego ID, nazwy,
   marki przykładowej, statusu approved i braku autora/GTIN w produkcie ogólnym.
   Angielska nazwa sama nie potwierdza dostępności. Na tej referencji 19
   systemowych przepisów ma komplet wymaganych składników, w tym 7 śniadań.
   Nie jest to potwierdzenie dostępności wszystkich 137 dań ani wszystkich sieci.

   Zapisany aktualny cache o identycznym odcisku może przedłużyć ważność
   dowodu po rzeczywistym odczycie OFF. Zmieniony/niezgodny odcisk, przyszła data,
   cudzy produkt albo niebrytyjski rekord nie są automatycznie akceptowane.
   Istniejący mechanizm odświeżania po odpowiedzi katalogu obejmuje też te
   znane kody faktycznie używane w aktywnych publicznych przepisach. Maksymalnie
   dwa kody, wspólny budżet sześciu HTTP/minutę na proces, cooldown i brak
   otwartej transakcji podczas HTTP. To nie dump ani nowe płatne usługi.

4. **Recipe(s) not found po imporcie własnego przepisu.** Szczegóły dopuszczały
   właściciela bez dowodu dostępności składników UK, lecz lista zakupów go
   odfiltrowywała. Teraz właściciel aktywnego przepisu może przekazać zapisane
   składniki i ilości do listy. Brak ceny zostaje brakiem ceny, nie zerem.
   Cudzy niedostępny/prywatny przepis, nieaktywny rekord, zły kraj sklepu,
   uprawnienia i limity Standard/Premium nie dostają obejścia.

5. **Polska dieta i błąd generatora.** Profil nie obsługiwał etykiet diety
   bezglutenowej/wysokobiałkowej zapisanych podczas onboardingu. Korzysta teraz
   ze wspólnego tłumaczenia, nie zmieniając kodów zapisu/API. Błędy usług
   generowania i wznowienia planu używają kraju konta; nazwa posiłku w błędzie
   niedostatecznej puli jest tłumaczona, a kod HTTP i polska wersja zachowane.

6. **OFF 503 dla dyni.** To awaria zewnętrznej usługi, nie informacja, że
   produkt nie istnieje. Wyszukiwarka PL ma ograniczony cooldown po awarii,
   używa dostępnego cache i nie wysyła kolejno zapytania dla każdego składnika.
   Log nie powiela wpisanego tekstu/adresu URL. Jawne warianty autora, np.
   `Dynia (hokkaido lub piżmowa)`, mogą użyć dokładnego lokalnego odpowiednika
   przed HTTP. Nie usuwa to kwalifikatorów typu „z kością”, nie zgaduje paczek.
   Brak zewnętrznych danych nadal zachowuje wymagany składnik prywatnie;
   znane makro pozostałych pozycji nie jest zamieniane na fikcyjne zera.

## Weryfikacja

- Nowe regresje odtworzyły pusty katalog, odmowę własnej listy, polski błąd
  generatora, niepasujący tekst rzeczywistego seeda i brak cooldownu OFF.
- Test pełnej ścieżki tworzy tygodniowy plan UK i listę zakupów, sprawdza
  kandydatów śniadaniowych, brak duplikatu dania w dniu oraz 390 pozycji katalogu.
  Istniejące dopełnianie kalorii może dodać posiłki ponad podstawowe 21 wpisów.
- Celowane testy odświeżania/OFF i nowego przepływu: **185 passed**. HTTP to
  kontrolowane odpowiedzi testowe; żądanie jest sprawdzane poza transakcją DB.
- Pełny Flutter: **1133 passed**. Analiza Flutter: exit 0, bez błędów i
  ostrzeżeń; 385 dotychczasowych informacji stylistycznych.
- Końcowy pełny backend: **3262 passed**, 45 ostrzeżeń zależności, exit 0,
  292,48 s — `uk-reported-20261025-backend-verified.log`. Nowy plik zawiera
  67 regresji (w tym warianty autoflush i starego SQLite bez RETURNING).
- Dwa starsze testy jawnego importu odseparowano od wbudowanej referencji,
  aby nadal rzeczywiście sprawdzały akceptację administratora i rollback,
  zamiast przechodzić dzięki już zatwierdzonym danym dostarczonym z kodem.
  Nie usunięto ich asercji bezpieczeństwa ani wycofania transakcji.
- Kontrakt generatora: 137 przepisów, 390 składników, bez zmian ilości.
  Compileall, kompilacja nowych zapytań dla PostgreSQL/SQLite i kontrola
  LF/UTF-8/whitespace przeszły. Nie wykonywano nowej próby na Neon.

Nie wykonano natywnego buildu AAB/IPA ani rzeczywistej próby na telefonie
użytkownika. Stary AAB nie zawiera tych nowych poprawek. Nie wyłączono kontroli
dostępności publicznych przepisów UK ani nie skopiowano cen PLN jako GBP.

## Powiadomienie następnej aktualizacji

- Poprawiliśmy tworzenie list zakupów z własnych przepisów.
- Usprawniliśmy dopasowanie składników przy problemach z bazą zewnętrzną.
- Uzupełniliśmy tłumaczenia przepisów i diet w wersji angielskiej.
- Udostępniliśmy angielski katalog składników systemowych.

Kopie przed zmianami: `../backups/uk-reported-bugs-20261025/` (wybrane źródła,
bez sekretów i bazy). Dwa pominięte przy pierwszym kopiowaniu moduły odzyskano
z niezmienionej, wcześniej przekazanej paczki 271; nie z historycznego HEAD.
