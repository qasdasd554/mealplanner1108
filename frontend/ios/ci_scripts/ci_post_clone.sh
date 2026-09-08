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

echo "=== Rozwiazywanie zaleznosci Swift Package Manager ==="
cd ios

# Usuwamy zapisany Package.resolved PRZED rozwiazywaniem zaleznosci.
#
# Xcode Cloud buduje z wylaczonym automatycznym rozwiazywaniem zaleznosci
# i wymaga, zeby zapisany Package.resolved dokladnie odpowiadal liscie
# pakietow w projekcie. Po dodaniu firebase-ios-sdk (powiadomienia push)
# plik w repozytorium przestal sie zgadzac i build padal komunikatem
# "an out-of-date resolved file was detected ... which is not allowed
# when automatic dependency resolution is disabled".
#
# Skasowanie go tutaj sprawia, ze xcodebuild generuje swiezy plik na
# podstawie AKTUALNEGO stanu projektu. Jest to bezpieczne w CI: wersje
# pakietow i tak sa okreslone w samym projekcie, a kazdy build zaczyna
# od czystego klonu repozytorium.
rm -f Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rm -f Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved

xcodebuild -resolvePackageDependencies -project Runner.xcodeproj

echo "=== Instalacja Podow ==="
if [ -f Podfile ]; then
  pod install
fi

echo "=== Gotowe ==="
exit 0
