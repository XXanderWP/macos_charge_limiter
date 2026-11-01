#!/bin/bash
# Builds ChargeLimiter.app from source with the Command Line Tools (no Xcode project needed).
# Usage: app/build.sh [VERSION] [OUTPUT_DIR]   (defaults: dev, ./build)
# The bundle is ad-hoc signed, no developer certificate required.
set -euo pipefail

cd "$(dirname "$0")"
VERSION="${1:-dev}"
OUT="${2:-../build}"
APP="$OUT/ChargeLimiter.app"

command -v swiftc >/dev/null || { echo "swiftc not found. Install the Command Line Tools: xcode-select --install" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework IOKit \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/ChargeLimiter"
sed "s|@VERSION@|$VERSION|g" Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
