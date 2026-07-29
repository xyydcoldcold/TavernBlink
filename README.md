# TavernBlink

TavernBlink is an experimental macOS 13+ menu-bar app that explores using an
`NETransparentProxyProvider` Network System Extension to identify and close
Hearthstone TCP flows on an explicit user command.

This repository currently contains the Phase 0/Phase 1 engineering core
described in the implementation report:

- one Xcode project;
- a menu-bar host app;
- one embedded Network System Extension;
- shared, versioned provider messaging models;
- system-extension, proxy-manager, messaging, and signing-identity service
  boundaries;
- an exact-identity provider with a bounded, bidirectional TCP relay;
- unit tests and a local relay harness;
- signing, notarization, and release-verification scripts;
- Phase 0 acceptance and manual-test documents.

The provider returns `false` for non-target or unidentifiable flows. Exact
target-signing-identifier matches are relayed through one bounded in-flight
block per direction and can be closed through versioned provider messaging.
Signed physical-Mac and real-game testing are still required before the route
can pass Phase 0.

Target selection requires Blizzard Team ID `G847MC6JZ5` and signing identifier
`unity.Blizzard Entertainment.Hearthstone`. TavernBlink first performs complete
static validation. For current Battle.net installations that fail only because
of a bundle resource-seal error, it may retry while skipping resources, but it
still validates all architectures and present nested code against the fixed
Blizzard designated requirement. The UI reports this reduced verification mode,
and the app revalidates immediately before every proxy start.

## Requirements

- macOS 13 or newer
- Xcode 26 or a compatible recent Xcode
- Apple Developer Program membership for system-extension testing
- explicit App IDs, App Group, entitlements, and matching provisioning profiles

## Configure signing

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. Replace every `com.example` identifier and set `DEVELOPMENT_TEAM`.
3. Register the host App ID, system-extension App ID, and App Group in the Apple
   Developer portal.
4. Create development and Developer ID provisioning profiles carrying the
   `app-proxy-provider-systemextension` entitlement.
5. Open `TavernBlink.xcodeproj`, select the `TavernBlink` scheme, and verify both
   targets use the intended team and profiles.

`Config/Local.xcconfig` is ignored so developer-specific identifiers are not
committed. The checked-in defaults are placeholders and are not suitable for
distribution.

## Build and test

The unsigned build validates source code and bundle assembly without requiring
local provisioning:

```sh
xcodebuild \
  -project TavernBlink.xcodeproj \
  -scheme TavernBlink \
  -configuration Debug \
  -derivedDataPath /tmp/TavernBlinkDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run unit tests with:

```sh
xcodebuild \
  -project TavernBlink.xcodeproj \
  -scheme TavernBlink \
  -configuration Debug \
  -derivedDataPath /tmp/TavernBlinkDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Installing or activating the extension requires a correctly signed build placed
in `/Applications`; an unsigned build cannot validate those runtime paths.

## Project map

```text
App/                 menu-bar UI and host-side services
Shared/              IPC contracts and shared models
ProxyExtension/      transparent proxy provider and relay boundaries
Tests/Unit/           pure unit tests
Tests/RelayHarness/   local TCP harness starting point
Tests/Manual/         physical-Mac/game test records
Config/               shared build settings and local signing example
scripts/              archive, notarization, and release verification
docs/                 architecture and Phase 0 gates
```

Start with [docs/phase-0-checklist.md](docs/phase-0-checklist.md). The core route
is not considered viable until entitlement activation, manager startup, source
identity, and real-game reconnect behavior all pass on physical Macs.

For a signed archive, `scripts/capture-phase0-evidence.sh` validates the
effective host/provider entitlements and Universal 2 bundle structure before
runtime testing begins.

## Safety and project status

TavernBlink is not affiliated with or endorsed by Blizzard. Disconnecting game
sessions to alter the client experience may violate Blizzard rules and may put
accounts at risk. Do not describe this software as undetectable, ban-safe, or
officially approved.

The app must not inspect payloads, collect Battle.net credentials, inject into
the game, or broaden matching when source identity is unavailable.
