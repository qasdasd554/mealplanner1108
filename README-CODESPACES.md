# Uruchomienie w GitHub Codespaces

## 1. Wgraj projekt na GitHub

Zawartość tego folderu (`backend/`, `frontend/`, `.devcontainer/`) musi być
**głównym katalogiem repozytorium** (root repo), np.:

```bash
cd mealplanner   # ten folder, zawierający backend/, frontend/, .devcontainer/
git init
git add .
git commit -m "Smart Meal Planner PL"
git branch -M main
git remote add origin https://github.com/TWOJ-LOGIN/mealplanner.git
git push -u origin main
```

## 2. Otwórz Codespace

Na GitHubie: **Code → Codespaces → Create codespace on main**.

Codespace automatycznie:
- uruchomi kontener z Pythonem 3.12 oraz bazę PostgreSQL 16 (usługa `db`),
- zainstaluje zależności backendu (`pip install -r requirements.txt`),
- zainstaluje Flutter SDK i pobierze pakiety frontendu.

Pierwsze uruchomienie (`postCreateCommand`) trwa ok. 3–5 minut — Flutter SDK
jest klonowany z GitHuba.

## 3. Uruchom backend

W terminalu Codespace:

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Baza danych tworzy się i zasila danymi startowymi automatycznie przy
pierwszym uruchomieniu (`app/main.py` woła `Base.metadata.create_all` i
`seed.py`).

Port **8000** zostanie automatycznie przekierowany (widoczny w zakładce
„Ports”) — **ustaw jego widoczność na „Public”**, żeby frontend webowy mógł
się z nim łączyć z poziomu przeglądarki.

Sprawdzenie, że backend działa:

```bash
curl http://localhost:8000/health
```

## 4. Uruchom frontend (Flutter web)

W nowym terminalu:

```bash
cd frontend
export PATH="$PATH:$HOME/flutter/bin"
flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0
```

Otwórz przekierowany port **5000** (link pojawi się w zakładce „Ports” albo
w wyniku komendy). Frontend automatycznie wykrywa adres backendu w
Codespaces (zamienia numer portu w adresie URL na `8000`) —
patrz `frontend/lib/config/api_config.dart`.

## 5. Dane testowe

Baza jest zasilana automatycznie przykładowymi produktami, przepisami i
sklepami przy starcie backendu. Możesz od razu zarejestrować nowe konto
przez ekran rejestracji w aplikacji.

## Uwagi

- Backend nasłuchuje na porcie **8000**, PostgreSQL na **5432**
  (dostępny wewnątrz kontenera jako `db:5432`, użytkownik/hasło:
  `postgres`/`postgres`, baza `mealplanner`).
- Jeśli zmienisz kod backendu, `--reload` w uvicornie przeładuje go
  automatycznie.
- Redis/Celery są w `requirements.txt`, ale nie są wymagane do działania
  podstawowych funkcji aplikacji (logowanie, przepisy, plany posiłków,
  lista zakupów) — możesz je pominąć.
