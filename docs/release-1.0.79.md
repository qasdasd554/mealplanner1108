# Meal Planner 1.0.79+280

Aktualizacja dla czystego main 6fb6236676fc1341fcb3b54a81e55e6c7a6aa459 (1.0.78+279).

## Zmiany PL i UK

- Poprawiono aktywację/przywracanie Premium i odzyskiwanie po przerwaniu płatności.
- Potwierdzone punkty zapisują się atomowo; ponowienie tej samej transakcji nie dopisuje ich drugi raz.
- Android konsumuje zakup punktów dopiero po potwierdzeniu zapisu przez backend.
- Wynik weryfikacji jest widoczny od razu, także gdy dodatkowe odświeżenie profilu zawiedzie.
- Ponowne skanowanie, podpowiedzi po nazwie i wybór ilości zachowują podstawę g/ml oraz masę opakowania.
- Poprawiono angielskie komunikaty powiadomień. Oferta triala zależy od potwierdzenia sklepu.
- Zaktualizowano powiadomienie o aktualizacji w obu językach.

## Wdrożenie

Instalator sprawdza dokładny commit i skróty źródeł, tworzy backup, uruchamia
testy powiązanych obszarów backendu, pełną analizę/testy Fluttera i build release
AAB. Dopiero potem tworzy commit i wykonuje push. Przy błędzie przed commitem
przywraca źródła. Nie dodaje AAB do Git.

Backend musi zostać wdrożony na Renderze razem z frontendem. Nowa mała tabela
points_purchases utworzy się przez istniejące create_all przy starcie backendu.
Nie wymaga nowych zmiennych środowiskowych, płatnych usług ani zmiany systemu bazy.
Przy włączonym automatycznym wdrażaniu Render powinien pobrać nowy commit;
sprawdź zakończenie deploya przed testowaniem nowej aplikacji.

## Test sklepowy — do wykonania po wdrożeniu, NIE jest zaliczony lokalnie

Na tej stacji nie jest podłączony telefon z kontem testera; emulator audytu nie
ma Sklepu Play. Nie wykonano rzeczywistego zakupu, triala ani TestFlight.
Automatyczne testy z kontrolowanymi odpowiedziami sklepów nie zastępują tej próby.

Google Play:
1. Wgraj app-release-1.0.79-280.aab na test wewnętrzny.
2. Użyj konta dodanego zarówno do testu aplikacji, jak i testowania licencji.
3. Zainstaluj aplikację przez link testu Google Play na tym koncie.
4. W zakupie wybierz testową kartę Google, zawsze akceptującą; sprawdź oznaczenie
   testu przed zatwierdzeniem. Nie używaj zwykłej karty płatniczej.
5. Kup pakiet punktów: saldo ma wzrosnąć dokładnie raz. Ponów zakup tego samego
   pakietu jako nową transakcję: saldo ma wzrosnąć ponownie, bez blokady zakupu.
6. Sprawdź anulowanie, kartę odrzucającą i zakup oczekujący — nie mogą nadawać
   dostępu ani punktów przed potwierdzeniem zakupienia.
7. Sprawdź subskrypcję/trial, restart aplikacji i przywracanie. Po wygaśnięciu
   testowej subskrypcji bez odnowienia Premium ma zostać odebrane.
8. Powtórz dla PL/UK i sprawdź PLN/GBP oraz ofertę triala dla kwalifikującego się konta.

Instrukcja Google: https://developer.android.com/google/play/billing/test

iOS: wgraj nowy build do TestFlight i testuj punkty/subskrypcję oraz przywracanie
w środowisku sandbox. Zakupy testowe TestFlight są bez opłat i nie przenoszą się
do wersji App Store. Nie zmieniano konfiguracji produkcyjnej Firebase ani podpisów.
https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox

Nie wysyłaj tokenów zakupów, haseł ani danych karty w logach przesyłanych na czacie.
