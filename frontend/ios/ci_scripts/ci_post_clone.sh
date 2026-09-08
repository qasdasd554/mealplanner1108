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

# Usuwamy zapisany Package.resolved PRZED czymkolwiek, co uruchamia
# xcodebuild.
#
# Xcode Cloud buduje z WYLACZONYM automatycznym rozwiazywaniem zaleznosci
# i wymaga, zeby zapisany Package.resolved dokladnie odpowiadal liscie
# pakietow w projekcie. Po dodaniu Firebase (powiadomienia push) plik
# przestal sie zgadzac i build padal z "an out-of-date resolved file was
# detected ... not allowed when automatic dependency resolution is
# disabled".
#
# WAZNA KOLEJNOSC: usuwanie MUSI byc przed `flutter build ios
# --config-only`, bo ta komenda sama w sobie uruchamia xcodebuild
# i sprawdza ten plik. Wczesniej kasowalismy go dopiero pozniej, wiec
# build padal, zanim doszlo do usuniecia.
echo "=== Czyszczenie nieaktualnego Package.resolved ==="
rm -f ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rm -f ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved

echo "=== Generowanie FlutterGeneratedPluginSwiftPackage ==="
flutter build ios --config-only --release --no-codesign

echo "=== Rozwiazywanie zaleznosci Swift Package Manager ==="
cd ios

xcodebuild -resolvePackageDependencies -project Runner.xcodeproj

echo "=== Instalacja Podow ==="
if [ -f Podfile ]; then
  pod install
fi

echo "=== Gotowe ==="
exit 0
