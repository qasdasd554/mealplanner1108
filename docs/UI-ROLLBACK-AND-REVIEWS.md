# Aktualizacja 1.0.64+265

Przywrócono poprzedni wygląd Startu, przepisów, Dziennika, Premium, motywu
i plakietek z backupu sprzed odświeżenia UI. Nie cofnięto miniaturek zdjęć,
synchronizacji subskrypcji, dat w Neon ani innych poprawek funkcjonalnych.

Prośba o ocenę używa natywnego API Apple/Google przez in_app_review 2.0.12.
Sygnał pochodzi wyłącznie z udanego utworzenia planu, dodania wpisu w Dzienniku
lub ręcznego zapisu przepisu. Aplikacja czeka na spokojny ekran po zakończeniu
czynności: nie otwiera oceny w formularzu, podczas używania klawiatury,
na ekranie zakupów Premium ani gdy jest w tle. Nie wymaga pięciu gwiazdek,
nie nagradza za ocenę i nie przechowuje wystawionej oceny.

Backend atomowo ogranicza żądania do jednego na 10 dni na konto, również
na kilku urządzeniach i po reinstalacji. Po ofercie triala odczekuje co najmniej
dobę. Kolumna users.review_prompt_last_requested_at jest dodawana przy deployu.

Apple/Google mogą nie wyświetlić okna mimo żądania z powodu własnych limitów.
W TestFlight API oceny nie wyświetla okna. Test Androida wymaga instalacji
ze sklepu kontem testera; rzeczywiste publiczne oceny dotyczą wersji produkcyjnej.

Źródła: https://developer.android.com/guide/playcore/in-app-review,
https://developer.apple.com/app-store/review/guidelines/ (5.6.1),
https://pub.dev/packages/in_app_review.

Budowanie Androida i archiwum iOS należy sprawdzić w Codespace/Xcode Cloud.
Podnieś progi aktualizacji na Renderze do 265 dopiero po publikacji buildu.

## Skaner gazetek administratora

Przyczyna błędu "serwer nie odpowiedział na czas": telefon czekał maksymalnie
45 sekund, a pobranie PDF i zapasowe modele AI mogły zajmować kilka minut.
Nowy klient tworzy trwałe zadanie w promotion_scan_jobs, odbiera odpowiedź 202
i odpytuje krótki status. Zamknięcie panelu nie przerywa pracy. Po powrocie
panel odnajduje aktywne zadania. Nowe promocje nadal wymagają akceptacji.

Jeden skan danego sklepu może być aktywny jednocześnie. Worker odzyskuje
przerwany skan po restarcie, ogranicza czas całego zadania i zapisuje rzeczywisty
błąd AI. Dane PDF są pobierane strumieniowo z limitem rozmiaru; HTML zamiast
PDF i nieprawidłowe ceny są odrzucane. Linki PDF z parametrami są obsługiwane.
Do AI trafia katalog produktów przypisanych do sklepu, nie cała baza skanowanych
produktów. Baza jest odłączana na czas pracy sieciowej.

Zmiana wymaga deployu backendu i nowego buildu aplikacji. Stary klient korzysta
ze starego endpointu synchronicznego. Nie wykonano skanu z prawdziwym kluczem
produkcyjnym ani testu na fizycznym urządzeniu w lokalnym środowisku.
