# Etap 16 — istniejące funkcje społecznościowe PL/GB

Prace lokalne 21–22.10.2026. Bez nowych funkcji użytkownika, zmiany cen,
limitów Premium, układu ekranów ani aktywacji rynku UK.

- Przetłumaczono znajomych, szczegóły znajomego, zaproszenia do list zakupów
  i ekran powiadomień. Wiadomości pochodzące z serwera/użytkownika nie są
  przepisywane przez klienta. Angielskie daty mają format brytyjski.
- Zaproszenie do znajomych i jego przyjęcie używają kraju ODBIORCY.
  Tytuły push tych dwóch typów również są angielskie dla GB. Inne typy push
  pozostają do sprawdzenia — nie jest to pełne tłumaczenie powiadomień.
- Dotychczasowe role, identyfikatory, uprawnienia, zgody na udostępnienie,
  waluty list i nawigacja pozostają zachowane. Nie dodano zapytań do bazy
  w celu osobnego ustalania języka znajomego.
- Test odtworzył istniejący także po polsku wyjątek po zamknięciu dialogu
  zaproszenia. Zastosowano istniejący `showRetainedDialog`, aby kontroler
  tekstu był zwalniany po animacji zamknięcia, nie w jej trakcie.
- Opcjonalne wstrzyknięcie usług w ekranach służy lokalnym testom. Domyślne
  usługi i ich publiczne żądania pozostają takie same.

Weryfikacja: 10 testów widgetowych przepływów społecznościowych,
5 ekranu powiadomień i 21 celowanych testów backendu przeszło. Kolejne pełne
przebiegi, obejmujące również ten etap, opisuje etap 17.
Testy używają atrap usług i lokalnego SQLite; nie wysyłają push, e-maili
ani płatnych zapytań AI. Nie zastępują próby na Androidzie/iPhonie.
