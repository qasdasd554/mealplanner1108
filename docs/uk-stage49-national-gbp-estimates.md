# Etap 49 — szacunki potrzebnych ilości w GBP

24.10.2026. Prace lokalne; UK nadal wyłączone, wersja 1.0.69+270 i poprzedni
ZIP bez zmian. Backup: `../backups/uk-stage49-20261024/`. Bez migracji bazy,
nowych bibliotek, wywołań AI, zmian makro i cen PL.

## Podłączona wycena

Referencje ONS z etapu 44 nie są już osobnym nieużywanym modułem. Teraz
20 jawnie powiązanych produktów systemowych może otrzymać wycenę potrzebnej
ilości, gdy nie ma zatwierdzonej ceny wybranego sklepu. Ta sama kwota trafia
do tworzonej/odświeżanej listy, budżetu oraz porównania planu i pozycji listy.

Źródło: [ONS Shopping prices comparison tool](https://www.ons.gov.uk/economy/inflationandpriceindices/articles/shoppingpricescomparisontool/latest).
Pakiet z 24.10.2026 zachowuje okres cen 2026-09. Są to średnie krajowe,
nie potwierdzone oferty Tesco, Aldi lub innych sieci.

- Zatwierdzona właściwa cena sklepowa ma pierwszeństwo przed ONS.
- Powiązania dotyczą m.in. płatków, suchego makaronu, ryżu basmati, piersi
  kurczaka, mleka półtłustego, masła, oleju rzepakowego i części warzyw.
- Wymagane są znany systemowy ID, niezmieniona nazwa, brak autora,
  akceptacja i zgodna fizyczna jednostka. Nie ma fuzzy matchingu.
- Mąka samorosnąca nie zastępuje zwykłej. Cena ogórka „each” nie staje się
  ceną 150 g. Nie przeliczamy g na ml i nie kopiujemy opakowań z PL.
- Brak ceny pozostaje nieznany, nie £0. Wynik poniżej grosza nie jest
  udawanym darmowym zakupem. Spiżarnia zachowuje własne 0 zł/£0.
- Nowe szacunki nie powstają z danych przyszłych lub starszych niż 120 dni
  od początku miesiąca źródłowego. Aktualizacje referencji wymagają
  ponownego pozyskania i sprawdzenia danych; nie ma nowego płatnego joba.

## Informacja dla użytkownika i historia

Istniejące opisy pozycji wyświetlają „ONS UK average (2026-09), needed amount —
not a shop price”. Dla polskiego odbiorcy listy współdzielonej GBP opis jest
po polsku. Zwinięta karta również ostrzega o średnich krajowych. Nie zmieniono
kolorów, przycisków, nawigacji ani normalnego układu listy.

Referencja nie ma oferty, SKU, liczby opakowań ani masy opakowania. Ma osobny
typ w istniejącym JSON `quote_data`; nie wymaga nowego schematu. Gdy
porównanie zawiera średnie krajowe, nie wskazujemy najtańszego sklepu ani
pozornych oszczędności. Także parser Fluttera odrzuca takie twierdzenia
z odpowiedzi API zawierającej referencję krajową.

Zaznaczona pozycja zachowuje pierwotny okres i wycenę. Kontrole odcisku,
tożsamości, ilości, jednostki, źródła i arytmetyki odrzucają uszkodzone dane.
Wpisane 500 g trafia do spiżarni jako 500 g, nie fikcyjne opakowanie 750 g.
To nadal szacunek kosztu, nie dowód kwoty faktycznie zapłaconej w sklepie.

## Wydajność i ograniczenia

Mały lokalny JSON jest ładowany do cache; runtime nie pobiera arkusza ani
nie wykonuje HTTP. Produkty porównywanej listy są pobierane jednym zapytaniem,
nie osobno dla każdego sklepu/produktu. Nie importujemy całego OFF do Neon.

Nie jest to pełny feed wszystkich cen. Nieobsługiwane składniki wymagają
rzeczywistej ceny, zaakceptowanego zgłoszenia lub kolejnej uzasadnionej
referencji. Ceny nie stanowią dowodu dostępności produktu w UK: wcześniejszy
filtr kraju nadal obowiązuje. Brak choćby jednej ceny pozostawia sumę całej
listy nieznaną, zamiast zaniżać ją do ceny części składników.

Pozostają dokumenty UK, kontrolowane zasilenie danych startowych, utrzymanie
aktualności źródeł oraz rzeczywiste próby urządzeń/logowania/IAP/triala.
Nie wykonywano publikacji ani AAB/IPA. Następna paczka wymaga aktualnego
snapshotu Codespace, nowego numeru i nowych notatek w powiadomieniu.

## Weryfikacja

Pierwszy test odtworzył brak wyceny: 1 failed, 5 passed. Nowe testy obejmują
całą listę/porównanie/spiżarnię, pierwszeństwo ceny sklepowej, niezgodną
jednostkę i osiem typów uszkodzenia historii. Końcowy zestaw cen i schematów:
91 passed, exit 0. Flutter celowany: 24 passed, w tym EN/PL 320 px i 150%.

Pierwszy pełny backend: 3027 passed i 3 stare oczekiwania braku ceny,
które nie uwzględniały nowego jawnego fallbacku ONS. Zmieniono wyłącznie
oczekiwanie ceny/pochodzenia; nadal wymagamy braku SKU/opakowania oraz braku
pożyczania niezweryfikowanej nazwy. Log ponownej weryfikacji:
`uk-stage49-backend-verified.log`.

Końcowy pełny backend po tych zmianach: **3031 passed**, 43 istniejące
ostrzeżenia, exit 0, 308,11 s. Powtórkę wykonano bez równoległego pełnego
Fluttera (wcześniejsza próba przy obu zestawach trwała 765,51 s).

Pełny Flutter: 1104 passed, exit 0 (`uk-stage49-flutter-final.log`).
Po końcowej korekcie podpisu karty uruchomiono ponownie test nowej referencji
(`uk-stage49-flutter-verified.log`): **8 passed**, exit 0. Analiza sześciu plików: 0 błędów,
0 ostrzeżeń, 20 informacji/lintów, m.in. dotychczasowe `withOpacity`.
