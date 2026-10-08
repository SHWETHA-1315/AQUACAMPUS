#!/usr/bin/env bash
# AQUACAMPUS Flutter Web build for Render static hosting.
# This creates a *web* view of the same Flutter app, not an Android APK.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  SDK_DIR="${HOME}/.aquacampus-flutter"
  if [ ! -x "$SDK_DIR/bin/flutter" ]; then
    echo "Installing Flutter stable SDK for Render web build..."
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$SDK_DIR"
  fi
  export PATH="$SDK_DIR/bin:$PATH"
fi
flutter --version
flutter config --enable-web
if [ ! -f web/index.html ]; then
  flutter create --platforms=web --project-name aquacampus .
  # A generated Flutter template test expects MyApp, but AQUACAMPUS has a
  # different root widget. Keep project-specific tests, remove only template.
  if [ -f test/widget_test.dart ]; then
    rm test/widget_test.dart
  fi
fi
flutter pub get
flutter test
DEFINES=()
if [[ -n "${FIREBASE_API_KEY:-}" && -n "${FIREBASE_APP_ID:-}" && -n "${FIREBASE_MESSAGING_SENDER_ID:-}" && -n "${FIREBASE_PROJECT_ID:-}" ]]; then
  echo "Building Firebase-connected AQUACAMPUS Web."
  for key in FIREBASE_API_KEY FIREBASE_APP_ID FIREBASE_MESSAGING_SENDER_ID FIREBASE_PROJECT_ID FIREBASE_AUTH_DOMAIN; do
    DEFINES+=("--dart-define=${key}=${!key:-}")
  done
else
  echo "Firebase config absent: offline single-browser demo, NOT connected to campus data."
fi
flutter build web --release "${DEFINES[@]}"
test -f build/web/index.html
echo "Render publish directory: build/web"
