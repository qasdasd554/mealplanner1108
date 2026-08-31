#!/bin/sh
set -e

echo "=== Instalacja Fluttera ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

echo "=== Pobieranie plikow iOS dla Fluttera ==="
flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH/frontend"

echo "=== Pobieranie zaleznosci Fluttera ==="
flutter pub get

echo "=== Generowanie FlutterGeneratedPluginSwiftPackage ==="
flutter build ios --config-only --release --no-codesign

echo "=== Instalacja Podow ==="
cd ios
if [ -f Podfile ]; then
  pod install
fi

echo "=== Gotowe ==="
exit 0
