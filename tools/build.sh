#!/usr/bin/env bash
set -euo pipefail
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
cd "$(dirname "$0")/../mobile"
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug --dart-define="UNIFIED_GATEWAY_BASE_URL=${UNIFIED_GATEWAY_BASE_URL:-}"
