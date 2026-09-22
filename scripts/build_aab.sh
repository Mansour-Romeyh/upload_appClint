#!/usr/bin/env bash
# Builds an Android release App Bundle (AAB) pointed at production.
# Override Flutter SDK path with FLUTTER=/path/to/flutter if not on PATH.
set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
DART="${DART:-dart}"
API_BASE_URL="${API_BASE_URL:-https://sar-iq.com}"

cd "$(dirname "$0")/.."

"$FLUTTER" clean
"$FLUTTER" pub get
"$DART" run flutter_launcher_icons
"$FLUTTER" build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo
echo "Done. AAB: build/app/outputs/bundle/release/app-release.aab"
