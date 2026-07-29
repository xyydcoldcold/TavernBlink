#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <app-path> <dmg-path>" >&2
  exit 64
fi

APP_PATH="$1"
DMG_PATH="$2"
EXTENSION_BUNDLE_ID="$(
  /usr/libexec/PlistBuddy -c "Print :ProxyExtensionBundleIdentifier" \
    "$APP_PATH/Contents/Info.plist"
)"
EXTENSION_PATH="$APP_PATH/Contents/Library/SystemExtensions/$EXTENSION_BUNDLE_ID.systemextension"

test -d "$APP_PATH"
test -d "$EXTENSION_PATH"
test -f "$DMG_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --verify --strict --verbose=2 "$EXTENSION_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
shasum -a 256 "$DMG_PATH"
