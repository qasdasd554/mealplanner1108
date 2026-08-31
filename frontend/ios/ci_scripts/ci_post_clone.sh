#!/bin/sh
set -e

echo "=== Instalacja Fluttera ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

echo "=== Pobieranie plikow iOS dla Fluttera ==="
flutter precache --ios

echo "=== Instalacja CocoaPods ==="
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "=== Pobieranie zaleznosci Fluttera ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/frontend"
flutter pub get

echo "=== Instalacja Podow ==="
cd ios
pod install

echo "=== Gotowe ==="
