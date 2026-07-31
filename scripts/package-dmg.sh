#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <app-path> [output-dmg-path]" >&2
  exit 64
fi

APP_PATH="$1"
OUTPUT_DMG="${2:-build/TavernBlink.dmg}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
VOLUME_NAME="${VOLUME_NAME:-TavernBlink}"

test -d "$APP_PATH"
mkdir -p "$(dirname "$OUTPUT_DMG")"

STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -R "$STAGING_DIR"
}
trap cleanup EXIT HUP INT TERM

ditto "$APP_PATH" "$STAGING_DIR/TavernBlink.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$OUTPUT_DMG"

codesign \
  --force \
  --timestamp \
  --sign "$SIGNING_IDENTITY" \
  "$OUTPUT_DMG"

codesign --verify --verbose=2 "$OUTPUT_DMG"
hdiutil verify "$OUTPUT_DMG"
