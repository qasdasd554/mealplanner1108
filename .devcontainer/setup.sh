#!/usr/bin/env bash
set -e

echo "==> Instalacja zależności backendu (Python)..."
cd /workspace/backend
pip install --break-system-packages -r requirements.txt

echo "==> Instalacja Flutter SDK (dla frontendu)..."
if [ ! -d "$HOME/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
fi
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$HOME/.bashrc"
export PATH="$PATH:$HOME/flutter/bin"
flutter precache --web 2>&1 | tail -5 || true

echo "==> Pobieranie pakietów Flutter..."
cd /workspace/frontend
flutter pub get || true

echo ""
echo "=========================================================="
echo " Gotowe! Baza danych PostgreSQL uruchamia się automatycznie."
echo " Aby uruchomić backend:"
echo "   cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
echo ""
echo " Aby uruchomić frontend (Flutter web):"
echo "   cd frontend && flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0"
echo "=========================================================="
