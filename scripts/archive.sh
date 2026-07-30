#!/bin/sh
set -eu

PROJECT_PATH="${PROJECT_PATH:-TavernBlink.xcodeproj}"
SCHEME="${SCHEME:-TavernBlink}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/TavernBlink.xcarchive}"
ARCHIVE_ARCHS="${ARCHIVE_ARCHS:-arm64 x86_64}"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  ARCHS="$ARCHIVE_ARCHS" \
  ONLY_ACTIVE_ARCH=NO \
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
