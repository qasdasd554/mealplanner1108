#!/usr/bin/env bash
set -e
ANDROID_SDK_ROOT="$HOME/android-sdk"
echo "==> [1/5] JDK 17..."
sudo apt-get update -qq && sudo apt-get install -y -qq openjdk-17-jdk unzip
echo "==> [2/5] Android command-line tools..."
if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"; cd /tmp
  curl -sSL -o cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  unzip -q -o cmdline-tools.zip -d "$ANDROID_SDK_ROOT/cmdline-tools"
  mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -f cmdline-tools.zip
fi
export ANDROID_SDK_ROOT ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$HOME/flutter/bin"
echo "==> [3/5] Komponenty SDK (najdluzej)..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager --install "platform-tools" "platforms;android-35" "build-tools;35.0.0" >/dev/null
echo "==> [4/5] Konfiguracja Fluttera..."
flutter config --android-sdk "$ANDROID_SDK_ROOT" >/dev/null
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
flutter precache --android 2>&1 | tail -3 || true
echo "==> [5/5] Zapis do ~/.bashrc..."
if ! grep -q "ANDROID_SDK_ROOT" "$HOME/.bashrc"; then
cat >> "$HOME/.bashrc" <<'BASHRC'

export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which javac)")")")"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$HOME/flutter/bin"
BASHRC
fi
echo ""
echo "Gotowe. Sprawdz: flutter doctor"
