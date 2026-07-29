#!/bin/sh
set -eu

PROJECT_PATH="${PROJECT_PATH:-TavernBlink.xcodeproj}"
SCHEME="${SCHEME:-TavernBlink}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/TavernBlink.xcarchive}"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/TavernBlink.app"
EXTENSION_BUNDLE_ID="$(
  /usr/libexec/PlistBuddy -c "Print :ProxyExtensionBundleIdentifier" \
    "$APP_PATH/Contents/Info.plist"
)"
EXTENSION_PATH="$APP_PATH/Contents/Library/SystemExtensions/$EXTENSION_BUNDLE_ID.systemextension"

test -d "$APP_PATH"
test -d "$EXTENSION_PATH"

codesign -d --entitlements :- "$APP_PATH"
codesign -d --entitlements :- "$EXTENSION_PATH"
