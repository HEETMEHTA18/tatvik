#!/usr/bin/env bash
set -euo pipefail

# Ensure Flutter is available in the build environment.
if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_HOME="$HOME/flutter"
  if [ ! -d "$FLUTTER_HOME" ]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

flutter --version
flutter pub get

# Build the Flutter web app for Vercel.
flutter build web --release --dart-define=API_BASE_URL=https://devmentor-jmjh.onrender.com/api/v1

# Vercel serves the contents of build/web.
# Keep the Flutter-generated SPA routing config alongside the built assets.
if [ -f "web/vercel.json" ]; then
  cp web/vercel.json build/web/vercel.json
fi


