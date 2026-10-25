# UK — spójność dostępności i język systemowego kanału push, 24.10.2026

Prace lokalne po etapie 44. Backup pięciu istniejących plików:
`../backups/uk-stage45-20261024/`. Nie zmieniono wyglądu, funkcji,
identyfikatorów produktów, schematu bazy, wydania ani flagi UK.

## Odtworzona przyczyna blokowania przepisów

Zapytanie katalogu akceptowało sprawdzony dowód sprzedaży składnika w UK,
ale kontrola szczegółów i generatora dodatkowo wymagała przeliczenia każdej
ilości na g/ml. Dlatego przepis widoczny w katalogu znikał po otwarciu,
jeśli np. sztuka lub łyżeczka nie miała zapisanej masy. Problem dotyczył
zarówno dokładnego kodu OFF, sprawdzonego powiązania generycznego, jak
i zatwierdzonej oferty sklepu.

Kontrola kraju nie wykonuje już wyceny porcji. Zachowuje pełną walidację
tożsamości produktu, źródeł, dat, fingerprintu i zgodnej podstawy g/ml
oferty sklepu; dowody OFF przechodzą dotychczasową lokalną kontrolę SQL.
Nie dopuszcza produktu wyłącznie na podstawie podobnej nazwy.

Rzeczywista lista/wycena nadal wymaga wiarygodnego przeliczenia. Gdy go
brakuje, pozostaje oryginalna ilość i jednostka, np. 3 szt., bez ceny,
gramatury opakowania lub fikcyjnego zera. Znany mnożnik porcji jest
uwzględniany dokładnie raz. Nie kopiujemy masy paczki OFF do masy sztuki.
Usunięto także polski komunikat z końcowej odmowy dostępu do przepisu UK.
Polska ścieżka dostępności nadal wraca bez dodatkowych zapytań.

## Natywna nazwa powiadomień Androida

`PushService` miał polską nazwę i opis kanału wpisane na stałe, także dla GB.
Teraz przed zalogowaniem wybiera region telefonu, a po odtworzeniu profilu
otrzymuje zapisany kraj konta ze wspólnej ścieżki logowania. Spóźniony profil
po wylogowaniu nadal nie rejestruje powiadomień. Niezwerfikowane konto
nie wywołuje nowej prośby o zgodę.

PL zachowuje poprzednie teksty; GB używa `Notifications` i angielskiego
opisu. Tworzenie kanału i powiadomienie pierwszoplanowe korzystają z tego
samego opisu. Nie zmieniono ID `meal_planner_default`, ważności, dźwięku,
uprawnień, treści przychodzących powiadomień ani konfiguracji iOS.
Ponowne ustawienie niezmienionej nazwy jest pomijane. Błąd aktualizacji
opisu nie blokuje logowania ani rejestracji tokenu.

Android dopuszcza zmianę nazwy/opisu istniejącego kanału bez zastępowania
ustawień zachowania wybranych przez użytkownika:
[oficjalna dokumentacja kanałów](https://developer.android.com/develop/ui/compose/notifications/channels).
To podstawa implementacji, nie dowód wykonania na telefonie w tym środowisku.

## Dane i dokumenty — wynik sprawdzenia, nie import

Jedno ograniczone wyszukiwanie kategorii OFF zwróciło rekordy cebuli,
w tym zwykłą brązową i czerwoną. Ta sama kategoria zawierała kimchi,
marynowane cebulki i przekąski: nie przyjęto pierwszego wyniku jako
generycznego składnika. Następne zapytanie otrzymało 503, więc próbę
zatrzymano bez dalszego ponawiania. Publiczny zapis odpowiedzi jest poza
repozytorium w `../uk-price-references-20261024/off-categories-20261024.json`.
Nie wpisano tych danych do Neon, cen ani startowego katalogu aplikacji.

Sprawdzono rzeczywisty GET czterech istniejących adresów aplikacji:
`privacy-policy.html`, `terms-of-use.html`, `delete-account.html` i
`support.html` na `mealplannerpolska.pl`. Wszystkie zwróciły HTTP 200
i dokument z `lang=pl` oraz polskim tytułem. Sam angielski przycisk
w aplikacji nie oznacza angielskiego dokumentu. Nie zmieniono strony,
adresów, regulaminu ani praktyk danych i nie potwierdzono jeszcze
kompletności dokumentów dla UK.

## Weryfikacja

- Dostępność OFF: najpierw 20 odtworzonych odmów i 4 przechodzące kontrole;
  następnie próby sklepowe odtworzyły 10 takich samych odmów i 2 błędne
  komunikaty językowe. Po poprawce nowy moduł ma 38 przypadków.
- Skupiona partia dostępności, miar i list: **273 passed**, exit 0
  (`uk-stage45-targeted.log`).
- Pełny backend po obu korektach dostępności i komunikatu: **2847 passed**,
  43 istniejące ostrzeżenia zależności/deprecacji, exit 0, 189,50 s
  (`uk-stage45-backend-final.log`).
- Kanał i przekazanie kraju: najpierw 5 odtworzonych błędów i 5 kontroli;
  po poprawce 10 nowych przypadków oraz 13 dotychczasowych testów sesji
  przeszło (`uk-stage45-push-green.log`).
- Pełny Flutter: **1096 passed**, exit 0, 133 s, concurrency 2
  (`uk-stage45-flutter-final.log`). Testy nie używają prawdziwego FCM.
- Analiza czterech zmienionych plików Dart: exit 0, 0 błędów i ostrzeżeń;
  jedna istniejąca informacja o nawiasach w innej części AuthProvider.
- Wersja pozostaje 1.0.69+270, `UK_MARKET_ENABLED=False`. Zamrożony ZIP
  nadal ma SHA-256
  `ca150f378cd0ba9bdddce841d05269e5da16dd92c1610ec781a7e94a1e4e6db6`.

Nie testowano fizycznego urządzenia, okna zgody, realnego dostarczenia FCM,
AAB/IPA ani płatności. Nie wykonano nowej próby Neon — nie zmieniano SQL,
schematu ani DDL; ostatnia próba rollback jest opisana w etapie 43.
Do publikacji pozostają dane startowe UK i GBP, dokumenty/konfiguracja
sklepów oraz rzeczywiste testy natywne. Poprawka nie oznacza gotowego UK.
