#!/usr/bin/env bash
# Builds an iOS release IPA pointed at production.
# Always pass --dart-define so the API base URL is baked in correctly.
# Override Flutter SDK path with FLUTTER=/path/to/flutter if not on PATH.
set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
DART="${DART:-dart}"
API_BASE_URL="${API_BASE_URL:-https://sar-iq.com}"

cd "$(dirname "$0")/.."

"$FLUTTER" clean
"$FLUTTER" pub get
"$DART" run flutter_launcher_icons
"$FLUTTER" build ipa --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo
echo "Done. IPA: build/ios/ipa/"
echo "Verify the API URL is baked in:"
echo "  unzip -p build/ios/ipa/*.ipa Payload/Runner.app/Frameworks/App.framework/App | strings | grep -F sar-iq"
