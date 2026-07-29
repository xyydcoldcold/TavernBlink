#!/bin/sh
set -eu

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "usage: $0 <app-path> <host-bundle-id> <extension-bundle-id> <app-group> [evidence-dir]" >&2
  exit 64
fi

APP_PATH="$1"
EXPECTED_HOST_BUNDLE_ID="$2"
EXPECTED_EXTENSION_BUNDLE_ID="$3"
EXPECTED_APP_GROUP="$4"
EVIDENCE_DIR="${5:-build/phase0-evidence}"
EXTENSION_PATH="$APP_PATH/Contents/Library/SystemExtensions/TavernBlinkProxy.systemextension"
HOST_ENTITLEMENTS="$EVIDENCE_DIR/host-entitlements.plist"
EXTENSION_ENTITLEMENTS="$EVIDENCE_DIR/extension-entitlements.plist"
SUMMARY_PATH="$EVIDENCE_DIR/summary.txt"

fail() {
  echo "error: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

require_value() {
  actual="$(plist_value "$1" "$2")"
  [ "$actual" = "$3" ] || fail "$2 expected '$3', found '$actual'"
}

require_universal_binary() {
  archs="$(lipo -archs "$1")"
  case " $archs " in
    *" arm64 "*) ;;
    *) fail "$1 is missing arm64" ;;
  esac
  case " $archs " in
    *" x86_64 "*) ;;
    *) fail "$1 is missing x86_64" ;;
  esac
}

test -d "$APP_PATH" || fail "app not found: $APP_PATH"
test -d "$EXTENSION_PATH" || fail "embedded system extension not found: $EXTENSION_PATH"

mkdir -p "$EVIDENCE_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --verify --strict --verbose=2 "$EXTENSION_PATH"
codesign -d --entitlements :- "$APP_PATH" >"$HOST_ENTITLEMENTS"
codesign -d --entitlements :- "$EXTENSION_PATH" >"$EXTENSION_ENTITLEMENTS"

plutil -lint "$HOST_ENTITLEMENTS" "$EXTENSION_ENTITLEMENTS"

require_value "$APP_PATH/Contents/Info.plist" "CFBundleIdentifier" "$EXPECTED_HOST_BUNDLE_ID"
require_value "$EXTENSION_PATH/Contents/Info.plist" "CFBundleIdentifier" "$EXPECTED_EXTENSION_BUNDLE_ID"
require_value "$HOST_ENTITLEMENTS" "com.apple.developer.system-extension.install" "true"
require_value "$HOST_ENTITLEMENTS" "com.apple.developer.networking.networkextension:0" "app-proxy-provider-systemextension"
require_value "$HOST_ENTITLEMENTS" "com.apple.security.application-groups:0" "$EXPECTED_APP_GROUP"
require_value "$EXTENSION_ENTITLEMENTS" "com.apple.developer.networking.networkextension:0" "app-proxy-provider-systemextension"
require_value "$EXTENSION_ENTITLEMENTS" "com.apple.security.application-groups:0" "$EXPECTED_APP_GROUP"
require_value "$EXTENSION_ENTITLEMENTS" "com.apple.security.app-sandbox" "true"
require_value "$EXTENSION_ENTITLEMENTS" "com.apple.security.network.client" "true"

MACH_SERVICE_NAME="$(plist_value "$EXTENSION_PATH/Contents/Info.plist" "NetworkExtension:NEMachServiceName")"
case "$MACH_SERVICE_NAME" in
  *"$EXPECTED_EXTENSION_BUNDLE_ID") ;;
  *) fail "NEMachServiceName does not end with the extension bundle identifier" ;;
esac

require_universal_binary "$APP_PATH/Contents/MacOS/TavernBlink"
require_universal_binary "$EXTENSION_PATH/Contents/MacOS/TavernBlinkProxy"

{
  echo "TavernBlink Phase 0 archive evidence"
  echo "Host bundle ID: $EXPECTED_HOST_BUNDLE_ID"
  echo "Extension bundle ID: $EXPECTED_EXTENSION_BUNDLE_ID"
  echo "App Group: $EXPECTED_APP_GROUP"
  echo "Mach service: $MACH_SERVICE_NAME"
  echo "Host architectures: $(lipo -archs "$APP_PATH/Contents/MacOS/TavernBlink")"
  echo "Extension architectures: $(lipo -archs "$EXTENSION_PATH/Contents/MacOS/TavernBlinkProxy")"
  echo "Host entitlements: $HOST_ENTITLEMENTS"
  echo "Extension entitlements: $EXTENSION_ENTITLEMENTS"
} >"$SUMMARY_PATH"

echo "Phase 0 archive evidence captured in $EVIDENCE_DIR"
