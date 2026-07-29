#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <dmg-path> <notarytool-keychain-profile>" >&2
  exit 64
fi

DMG_PATH="$1"
NOTARY_PROFILE="$2"

test -f "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
