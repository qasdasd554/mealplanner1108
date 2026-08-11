# Naprawy — Smart Meal Planner PL (Flutter + FastAPI + Neon + Render)

> Uwaga: naprawiona została wersja **Flutter** (`mealplanner/frontend` +
> `mealplanner/backend`). Drugi projekt w archiwum (Expo/React Native +
> MongoDB) to starsza, nieużywana wersja.

---

## 1. Błąd logowania Google „invalid_request”

**Przyczyna:** logowanie przez Google szło przez przeglądarkowy flow OAuth
z `redirect_uri`. Klient OAuth typu **Android** w Google Cloud Console nie
akceptuje dowolnego przeglądarkowego `redirect_uri` — stąd `invalid_request`.

**Naprawa:** przejście na natywny pakiet **`google_sign_in` 7.x**
(Credential Manager na Androidzie). Nie używa przeglądarki ani `redirect_uri`,
więc ten błąd nie może już wystąpić.

Zmiany: `pubspec.yaml`, `lib/services/auth_service.dart`,
`lib/providers/auth_provider.dart`, `lib/screens/auth/login_screen.dart`
(nowy przycisk „Kontynuuj z Google”), `lib/config/api_config.dart`.

**Backend:** endpoint `POST /api/v1/auth/google` przyjmuje teraz `id_token`
(zamiast `access_token`) i **weryfikuje go kryptograficznie** biblioteką
`google-auth` — sprawdza podpis, wygaśnięcie i odbiorcę (`aud`). Poprzednia
wersja jedynie odpytywała Google o profil, co jest podatne na podstawienie
cudzego tokenu.

---

## 2. Wylogowywanie użytkownika

**Przyczyny (dwie):**
- Token sesji był ważny tylko **60 minut** (`ACCESS_TOKEN_EXPIRE_MINUTES`).
  Po godzinie `/users/me` zwracało 401 i aplikacja czyściła sesję.
- Brak jakiegokolwiek mechanizmu odzyskiwania sesji.

**Naprawa:**
- Czas życia tokenu podniesiony do **30 dni**.
- Przy starcie aplikacji, jeśli sesja wygasła, następuje **ciche wznowienie
  logowania Google** (`attemptLightweightAuthentication`) — bez pokazywania
  jakiegokolwiek okna użytkownikowi.
- Błędy sieciowe (brak internetu, chwilowa niedostępność serwera) **nie
  wylogowują** już użytkownika — wylogowanie następuje wyłącznie przy 401.

---

## 3. Błędy, które powodowały, że aplikacja w ogóle nie działała

Te błędy znalazłem przy okazji — bez nich logowanie i tak by nie zadziałało:

| Problem | Skutek | Naprawa |
|---|---|---|
| Backend montował API pod `/api`, a aplikacja odpytuje `/api/v1` | **każde** zapytanie → 404 | `API_V1_PREFIX` = `/api/v1` |
| Aplikacja zawsze łączyła się z `http://10.0.2.2:8000` (adres działający tylko w emulatorze) | w zainstalowanym APK brak łączności z serwerem | build release → `https://mealplanner-wv11.onrender.com` |
| Logowanie wysyłało `username` jako `x-www-form-urlencoded`, backend oczekuje JSON z `email` | logowanie zawsze → 400 | wysyłka JSON z polem `email` |
| `/auth/register` i `/auth/login` zwracały `{"token": ...}`, a aplikacja czyta `access_token` | wyjątek przy logowaniu | backend zwraca `access_token` + `token_type` |
| `AuthService.register` parsował odpowiedź jako pełny profil `User` (brak `created_at`) | wyjątek przy rejestracji | rejestracja nie parsuje już profilu |
| `FoodLogService` miał zahardkodowane `http://localhost:8000/api` i nieistniejące ścieżki `/tracker/*` | dziennik kalorii nigdy nie działał | wspólna konfiguracja + poprawne ścieżki `/food-log/*` |
| Token nigdy nie trafiał do `FoodLogProvider` (`updateAuth` nigdzie nie wywoływane) | dziennik pokazywał **zmyślone dane** zamiast prawdziwych | token pobierany z `ApiClient` |
| Niedostępny serwer Google → nieobsłużony wyjątek | błąd 500 | czytelny błąd 503 |

Backend przetestowałem end-to-end (rejestracja, logowanie, złe hasło, profil,
logowanie Google, brak duplikatów kont, czas życia tokenu) — wszystkie testy
przechodzą.

---

## 4. Naprawy specyficzne dla Neon / PostgreSQL

Te błędy nie ujawniłyby się na SQLite, ale **uniemożliwiłyby działanie na Neonie**:

### 4.1. Uszkadzanie adresu połączenia (krytyczne)

`app/db/session.py` czyścił connection string podmianą tekstową:
`db_url.replace("?sslmode=require", "")`.

Neon podaje dziś adres w postaci
`...neon.tech/neondb?sslmode=require&channel_binding=require`.
Po tej podmianie zostawało `...neon.tech/neondb&channel_binding=require`,
czyli **nazwa bazy = `neondb&channel_binding=require`** → połączenie kończyłoby
się błędem „database does not exist”.

Naprawione: adres jest teraz poprawnie parsowany (`make_url`), a parametry
libpq (`sslmode`, `channel_binding`, `sslrootcert`, `options`) usuwane
niezależnie od kolejności. Sprawdzone na 5 wariantach adresu.

### 4.2. Brak `pool_pre_ping` — błędy po uśpieniu bazy

Neon usypia bazę po bezczynności (autosuspend), a Render w darmowym planie
usypia serwis. Połączenia w puli stają się wtedy martwe. Udowodnione testem
(restart bazy w trakcie działania aplikacji):

```
pool_pre_ping=False : BŁĄD -> InterfaceError
pool_pre_ping=True  : DZIAŁA
```

Dodane `pool_pre_ping=True` i `pool_recycle=300`.

### 4.3. Dziennik kalorii i porównywarka cen — zawsze błąd 500

`app/api/v1/food_log.py` i `app/api/v1/price_compare.py` były napisane
**synchronicznie** (`def`, `db.execute(...)`, `db.commit()`), podczas gdy
aplikacja używa **asynchronicznej** sesji SQLAlchemy. Każde wywołanie kończyło
się błędem `AttributeError: 'coroutine' object has no attribute 'scalars'`.

Dodatkowo odwoływały się do pól, których modele nie mają
(`entry.meal_type`, `entry.servings`, `meal_plan.date` — w rzeczywistości
`meal_slot`, `servings_multiplier`, `start_date` + `day_number`).

Oba moduły przepisane na kod asynchroniczny, z poprawnymi nazwami pól
i jawnym ładowaniem relacji (`selectinload`).

---

## 5. Co zostało przetestowane

Postawiłem **prawdziwy PostgreSQL 16** i przetestowałem backend na nim
(nie na SQLite), więc typy `UUID`, `JSON`, `gen_random_uuid()` i sterownik
`asyncpg` zostały zweryfikowane realnie:

- tworzenie schematu (`create_all`) — wszystkie tabele i klucze obce,
- rejestracja, logowanie, błędne hasło, brak tokenu,
- `/users/me` — serializacja UUID i `created_at`,
- zapis i odczyt kolumny JSON (`dietary_preferences`),
- logowanie Google: brak tokenu / zły token / Google niedostępne / poprawny,
- zakładanie konta przez Google, brak duplikatów, logowanie do istniejącego
  konta o tym samym e-mailu,
- ważność tokenu sesji (~30 dni),
- dziennik kalorii: dodawanie, odczyt, podsumowanie, usuwanie, walidacja,
  izolacja danych między użytkownikami,
- odporność na uśpienie i powrót bazy (autosuspend Neon),
- parsowanie 5 wariantów connection stringa Neon.

**Czego nie przetestowałem:** kodu Flutter (brak Flutter SDK w środowisku) —
sprawdzony przeglądem i zgodnością z API `google_sign_in` 7.x. Nie łączyłem
się też z Twoją prawdziwą bazą Neon ani z serwerami Google (weryfikacja
tokenu jest w testach zamockowana — sam mechanizm to standardowa biblioteka
`google-auth`).

---

## 6. ⚠️ PILNE — wyciekłe hasła

W plikach źródłowych znalazłem **prawdziwe, działające poświadczenia**:

1. **Hasło do bazy Neon** (`app/core/config.py`, `.env.production`,
   `docker-compose.yml`) — pełny connection string z hasłem otwartym tekstem.
2. **Sekret JWT** (`.env.production`) — kto go ma, może wygenerować token
   dowolnego użytkownika.

Usunąłem je z kodu, ale **to nie unieważnia samych sekretów**. Musisz:

1. **Zresetować hasło użytkownika bazy w panelu Neon** (Dashboard → Roles →
   Reset password).
2. **Wygenerować nowy `SECRET_KEY`**: `openssl rand -hex 32`
3. Ustawić oba w **Render → Environment → Environment Variables**
   (nie w plikach w repozytorium).

Jeśli repozytorium na GitHubie jest publiczne — potraktuj to jako pewny wyciek.

---

## 7. Co musisz zrobić, żeby to uruchomić

### A. Zmienne środowiskowe w Render

| Zmienna | Wartość | Wymagana? |
|---|---|---|
| `DATABASE_URL` | nowy connection string z Neon (po resecie hasła) | **TAK** |
| `SECRET_KEY` | nowy, losowy: `openssl rand -hex 32` (min. 32 znaki) | **TAK** |
| `API_V1_PREFIX` | `/api/v1` — **sprawdź, czy nie jest ustawione na `/api`** | zalecana |
| `GOOGLE_WEB_CLIENT_ID` | `780793039743-6ap1jq18i31hqt04pf7gj8i4jip67uts.apps.googleusercontent.com` | ma domyślną |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `43200` (30 dni) | ma domyślną |
| `CORS_ORIGINS` | domeny wersji webowej po przecinku; pomiń, jeśli tylko mobile | opcjonalna |
| `ENVIRONMENT` | zostaw puste (domyślnie `production`) | — |

> ⚠️ **Uwaga:** `DATABASE_URL` i `SECRET_KEY` są teraz **twardo wymagane**.
> Jeśli ich nie ustawisz, aplikacja celowo nie wystartuje i wypisze w logach
> Render, czego brakuje. To zamierzone — wcześniej startowała po cichu
> z sekretem zapisanym w kodzie, co pozwalało każdemu podrobić token
> dowolnego użytkownika.

Render sam zainstaluje nowe zależności (`google-auth`) z `requirements.txt`.
Limity prób logowania nie wymagają żadnej dodatkowej usługi ani biblioteki.

### B. Projekt Android dla Fluttera — WAŻNE

W archiwum, które przesłałeś, **nie ma folderu `android/`** — jest tylko
`lib/`, `web/` i `test/`. Bez niego `flutter build apk` nie zadziała.
Wygeneruj go:

```bash
cd frontend
flutter create --platforms=android .
flutter pub get
```

Następnie w `android/app/build.gradle.kts` (lub `.gradle`) ustaw:

```kotlin
defaultConfig {
    applicationId = "com.meal_planner_polska_v1"   // MUSI zgadzać się z Google Cloud Console
    minSdk = 23                                     // wymagane przez google_sign_in 7.x
}
```

`applicationId` **musi** być dokładnie taki, jak nazwa pakietu wpisana
w Twoim kliencie OAuth typu Android (`com.meal_planner_polska_v1`).

### C. SHA-1 w Google Cloud Console

Ten, który mi pokazałeś, był wygenerowany dla poprzedniego projektu (Expo/EAS).
Build Fluttera będzie podpisany **innym kluczem**, więc musisz dodać nowy
odcisk SHA-1:

```bash
# klucz debug (do testów):
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
        -storepass android -keypass android

# klucz release — z Twojego własnego keystore
```

Wklej SHA-1 do klienta OAuth typu **Android** w Google Cloud Console.
Możesz mieć tam wiele odcisków naraz (debug + release) — dodaj oba.

Klient typu **Web** (`780793039743-6ap1jq18i31hqt04pf7gj8i4jip67uts...`)
musi istnieć w tym samym projekcie — jest używany jako `serverClientId`
i to on sprawia, że Google zwraca `idToken`.

### D. Build

```bash
cd frontend
flutter pub get
flutter build apk --release
```

---

## 8. Uwagi końcowe

Backend przetestowałem automatycznie na prawdziwym PostgreSQL 16 (szczegóły
w sekcji 5). Kodu Flutter **nie skompilowałem** — nie mam w tym środowisku
Flutter SDK — więc sprawdziłem go przeglądem i zgodnością z aktualnym API
`google_sign_in` 7.x. Przy pierwszym `flutter pub get` / `flutter analyze`
mogą wyjść drobne ostrzeżenia; jeśli coś wyskoczy, wystarczy przesłać wynik.

---

## 9. Poprawki bezpieczeństwa (wykonane osobno)

### 9.1. Zabezpieczenie przed ponownym wyciekiem sekretów

Backend **nie miał pliku `.gitignore`** — to była bezpośrednia przyczyna
trafienia `.env.production` z hasłami do repozytorium. Dodane:

- `backend/.gitignore` — wyklucza `.env*` (poza `.env.example`), klucze, `*.pem`,
- rozszerzony `frontend/.gitignore` — dodatkowo `*.jks`, `*.keystore`,
  `key.properties`, `google-services.json`,
- `.env.production` (z sekretami) → zamieniony na `.env.example` (sam szablon).

Cały projekt przeskanowany — żadnych pozostałych haseł ani connection stringów.

> To zabezpiecza **na przyszłość**. Nie unieważnia sekretów, które już
> wyciekły — reset hasła w Neonie i nowy `SECRET_KEY` nadal są konieczne.

### 9.2. Limity prób logowania

`/auth/login` i `/auth/register` nie miały żadnego ograniczenia — hasła można
było łamać metodą siłową bez przeszkód. Dodany moduł `app/core/rate_limit.py`:

- **10 nieudanych** prób logowania z jednego IP / 5 min → `429` z `Retry-After`,
- licznik rośnie **tylko przy nieudanej** próbie i zeruje się po udanym
  logowaniu, więc normalny użytkownik nigdy na limit nie trafi,
- **5 rejestracji** z jednego IP / 5 min (ochrona przed masowym zakładaniem kont),
- adres klienta brany z `X-Forwarded-For` — bez tego Render (proxy) dawałby
  wszystkim użytkownikom jeden wspólny licznik,
- limity konfigurowalne przez `RATE_LIMIT_*`.

Bez dodatkowych zależności; licznik w pamięci procesu. Ograniczenie: przy
wielu instancjach każda liczy osobno. Dla jednej instancji na Render
wystarczające — przy skalowaniu warto przenieść na Redis.

### 9.3. CORS

Było `allow_origins=["*"]` razem z `allow_credentials=True` — kombinacja
pozwalająca dowolnej stronie wysyłać uwierzytelnione żądania w imieniu
zalogowanego użytkownika wersji webowej. Teraz:

- `allow_credentials=False` (aplikacja używa nagłówka `Authorization`,
  nie ciasteczek — nic nie traci),
- dozwolone domeny konfigurowalne przez `CORS_ORIGINS`,
- zawężone metody i nagłówki,
- ostrzeżenie w logach, jeśli na produkcji zostanie `*`.

Aplikacja mobilna nie wysyła nagłówka `Origin`, więc te zmiany jej nie dotyczą.

### 9.4. Wymuszenie sekretów na produkcji

`SECRET_KEY` miał działającą wartość domyślną w kodzie — gdyby zmienna nie
została ustawiona w Render, aplikacja wystartowałaby normalnie, podpisując
tokeny sesji sekretem znanym każdemu, kto widział kod. Każdy mógłby wtedy
wygenerować sobie token dowolnego użytkownika.

Teraz aplikacja w trybie produkcyjnym **nie wystartuje**, jeśli:
- `SECRET_KEY` ma wartość domyślną albo jest krótszy niż 32 znaki,
- `DATABASE_URL` nie został ustawiony.

Komunikat błędu mówi dokładnie, czego brakuje i jak to wygenerować.
Do pracy lokalnej: `ENVIRONMENT=development` (wtedy tylko ostrzeżenie).

### Przetestowane

Wszystkie powyższe zweryfikowane automatycznie na prawdziwym PostgreSQL:
start bez `SECRET_KEY` / ze zbyt krótkim / bez `DATABASE_URL` / poprawny /
tryb deweloperski; odrzucenie obcej domeny w CORS i przepuszczenie własnej;
działanie żądań bez `Origin` (mobile); zablokowanie ataku siłowego po 10
próbach; brak limitowania udanych logowań; limit rejestracji. Uruchomiona
też pełna regresja wcześniejszych napraw — bez zmian.
