# iOS: build 1.0.22+219 przez Xcode Cloud

Nie wpisuj żadnej komendy `cd` na Macu. Po wykonaniu skryptu w Codespace
zmiany są wysyłane na GitHuba, a istniejący skrypt Xcode Cloud
`frontend/ios/ci_scripts/ci_post_clone.sh` automatycznie:

1. instaluje Fluttera i zależności (`flutter pub get`),
2. generuje konfigurację iOS,
3. rozwiązuje pakiety Xcode,
4. wykonuje `pod install`.

Workflow Xcode Cloud powinien uruchomić się po nowym pushu. Jeśli workflow
nie jest ustawiony na automatyczny start, uruchom ręcznie nowy build z panelu
Xcode Cloud. Oczekiwana wersja to `1.0.22`, a numer builda `219`.

Po zainstalowaniu builda z TestFlight uruchom aplikację i zaloguj się co
najmniej raz, aby nowy token urządzenia trafił do backendu. Powiadomienia
w ustawieniach iPhone'a, capability `Push Notifications` oraz klucz APNs
`.p8` muszą pozostać włączone — zostało potwierdzone, że są skonfigurowane.
