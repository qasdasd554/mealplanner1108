# Aktualizowanie końca subskrypcji w Neon

Backend zapisuje `premium_expires_at`, `premium_status`, `premium_auto_renew_enabled`
i `premium_last_verified_at`. Powiadomienie ze sklepu jest sygnałem do ponownej
weryfikacji zakupu w API Apple lub Google; samo powiadomienie nie nadaje Premium.

## Render

Wygeneruj sekret poleceniem `openssl rand -hex 32` i dodaj w Environment:

```text
BILLING_WEBHOOK_SECRET=<wygenerowany-sekret>
```

Zachowaj dotychczasową konfigurację weryfikacji zakupów Apple/Google.
Sekretu nie zapisuj w GitHubie.

## App Store Connect

W ustawieniach aplikacji otwórz App Store Server Notifications, wybierz wersję V2
i ustaw Production URL oraz Sandbox URL:

```text
https://TWÓJ-BACKEND.onrender.com/api/v1/billing/webhooks/apple?token=SEKRET
```

Wyślij test. HTTP 204 potwierdza odbiór; rzeczywistą aktualizację daty należy
sprawdzić także po testowym odnowieniu subskrypcji.

## Google Play / Google Cloud Pub/Sub

1. Utwórz temat Pub/Sub, np. `mealplanner-subscriptions`.
2. Nadaj `google-play-developer-notifications@system.gserviceaccount.com`
   rolę Pub/Sub Publisher dla tego tematu.
3. Ustaw temat w Google Play Console jako Real-time developer notifications.
4. Utwórz subskrypcję Push z adresem:

```text
https://TWÓJ-BACKEND.onrender.com/api/v1/billing/webhooks/google?token=SEKRET
```

5. Wyślij wiadomość testową, a następnie sprawdź testowe odnowienie/wygaśnięcie.

## Neon

```sql
SELECT email, premium_platform, premium_product_id, premium_status,
       premium_auto_renew_enabled,
       premium_expires_at AT TIME ZONE 'Europe/Warsaw' AS premium_wygasa,
       premium_last_verified_at AT TIME ZONE 'Europe/Warsaw' AS ostatnia_weryfikacja
FROM users
WHERE premium_expires_at IS NOT NULL
ORDER BY premium_expires_at DESC;
```

Kolumny i miniatury istniejących zdjęć są uzupełniane po uruchomieniu nowego backendu.
Nie zmieniaj progów aktualizacji w Render przed udostępnieniem nowego buildu w sklepie.
