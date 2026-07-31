# TavernBlink

TavernBlink is an experimental macOS 13+ menu-bar app that uses a Network
System Extension to identify Hearthstone TCP flows and close the currently
matched flows when the user clicks **Disconnect Now**.

，

## Download and install

1. Download the latest `TavernBlink-*.dmg` from the
   [Releases page](https://github.com/xyydcoldcold/TavernBlink/releases).
2. If a SHA-256 checksum is published with the release, verify the download:

   ```sh
   shasum -a 256 ~/Downloads/TavernBlink-*.dmg
   ```

   The result must exactly match the checksum in that release.
3. Open the DMG and drag **TavernBlink.app** onto the **Applications** shortcut.
4. Eject the DMG. Do not run TavernBlink directly from the mounted DMG because
   its System Extension must be installed from `/Applications/TavernBlink.app`.
5. Open **Applications**, then open **TavernBlink**.

TavernBlink is a menu-bar app. It does not open a normal Dock window. Look for
the TavernBlink network icon near the right side of the macOS menu bar.

The official release is Developer ID signed, notarized by Apple, and carries a
stapled notarization ticket. If macOS says the app is damaged or cannot verify
its developer, do not bypass Gatekeeper. Delete that copy, download it again
from the Releases page, and verify its checksum.

## First-time setup

Perform these steps in order:

1. Open the TavernBlink menu-bar panel and click
   **Install Network Component**.
2. Approve the Network System Extension when macOS asks:

   - On macOS 15 or newer, open **System Settings → General → Login Items &
     Extensions → Network Extensions**, then enable TavernBlink.
   - On macOS 13 or 14, open **System Settings → Privacy & Security**, find the
     system-software approval message, and click **Allow**.

   Enter an administrator password if macOS requests it. Restart the Mac only
   if macOS or TavernBlink explicitly says a restart is required.
3. Return to TavernBlink and click **Refresh**. Once approval is recognized,
   the status should change to **Transparent proxy is not configured**. This is
   expected at this stage.
4. Click **Choose Hearthstone…** and select the actual `Hearthstone.app`, not
   the Battle.net launcher. A typical installation is:

   ```text
   /Applications/Hearthstone/Hearthstone.app
   ```

   TavernBlink accepts only the expected Blizzard Team ID and Hearthstone
   signing identifier. Stop if the app reports an identity mismatch.
5. Click **Configure and Start Proxy** and approve any additional macOS prompt
   to add or enable the network configuration.
6. Wait for **Ready; waiting for a target flow**. Then launch Hearthstone. If
   Hearthstone was already open, quit and reopen it so new connections can
   reach the provider.
7. Enter the game mode or match you intend to test. When TavernBlink shows
   **Ready with N target flows**, **Disconnect Now** becomes available.
8. Click **Disconnect Now** once. TavernBlink closes only the currently matched
   Hearthstone TCP flows; Hearthstone is responsible for reconnecting them.

Do not repeatedly click **Disconnect Now** if Hearthstone exits or does not
recover. Disable TavernBlink, record what happened, and restart Hearthstone
normally.

## Normal use

- Start TavernBlink from `/Applications`; use its menu-bar icon to open it.
- If the status is **Transparent proxy is not configured**, choose Hearthstone
  if necessary and click **Configure and Start Proxy**.
- **Ready; waiting for a target flow** means the proxy is running but no active
  Hearthstone connection currently matches.
- **Disconnect Now** remains disabled until the proxy is connected and at least
  one target flow is active.
- Click **Refresh** after approving an extension or changing game state if the
  displayed status has not updated.
- A **Disable** request is intentionally blocked while target flows are active,
  because macOS cannot hand an already claimed TCP connection back to the
  system without interrupting it. Exit Hearthstone or wait for the target flows
  to close before disabling the proxy.
- Quitting TavernBlink closes only its menu-bar UI. Once no target flows are
  active, use **Disable** first when you want the proxy turned off.

## Uninstall

1. Open TavernBlink and click **Disable**.
2. Click **Quit TavernBlink**.
3. Move `/Applications/TavernBlink.app` to the Trash.
4. Open **System Settings → General → Login Items & Extensions → Network
   Extensions** and confirm TavernBlink is no longer enabled. On macOS 13 or 14,
   check **Privacy & Security** instead.
5. Restart the Mac if macOS requests it.

Do not manually delete files from `/Library/SystemExtensions`.

## Troubleshooting

### TavernBlink has no normal app window

This is expected. TavernBlink runs in the menu bar. Reopen it from Applications
if its menu-bar icon is missing.

### “Approve TavernBlink in System Settings”

Complete the approval described under
[First-time setup](#first-time-setup), return to TavernBlink, and click
**Refresh**. If macOS explicitly requests a restart, restart before continuing.

### “Transparent proxy is not configured”

This does not mean installation failed. It means the System Extension is
available but the network configuration has not been started. Select
Hearthstone and click **Configure and Start Proxy**.

### “Ready; waiting for a target flow”

The provider is running correctly but has not observed an active Hearthstone
flow. Launch or restart Hearthstone, enter a networked game mode, and click
**Refresh**.

### “Disconnect Now” is disabled

The button is enabled only while the provider is connected and at least one
verified Hearthstone target flow is active. Wait for **Ready with N target
flows**.

### Orange Blizzard verification warning

Some current Battle.net installations have bundle resources that cannot be
fully validated even though Blizzard code signatures are valid. TavernBlink may
show a reduced-verification warning while still enforcing the fixed Blizzard
Team ID and Hearthstone signing identifier. Do not continue if the message is
red or reports an identity mismatch.

## Security and privacy boundaries

TavernBlink identifies the target by its code-signing identity. It does not ask
for or collect Battle.net credentials, inject code into Hearthstone, or parse
game payloads. Non-target and unidentifiable flows are not claimed by the
provider.

## Project status

Phase 0 received a GO decision after 20/20 real-game recovery trials completed
within five seconds, with no provider crashes, secondary disconnects, or
non-target traffic incidents. The Developer ID Universal 2 DMG packaging,
notarization, stapling, and Gatekeeper verification path has also passed.

Public release still depends on the remaining items in
[docs/release-checklist.md](docs/release-checklist.md), including clean
installation and uninstall testing on a second physical Mac, release notes, and
privacy/diagnostic documentation.

## Developer requirements

- Xcode 26 or a compatible recent Xcode
- Apple Developer Program membership
- Explicit host and System Extension App IDs
- A shared App Group
- Matching development and Developer ID provisioning profiles

## Configure signing

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. Replace every `com.example` identifier and set `DEVELOPMENT_TEAM`.
3. Register the host App ID, System Extension App ID, and App Group in the Apple
   Developer portal.
4. Create development and Developer ID provisioning profiles carrying the
   `app-proxy-provider-systemextension` entitlement.
5. Open `TavernBlink.xcodeproj`, select the `TavernBlink` scheme, and verify both
   targets use the intended team and profiles.

`Config/Local.xcconfig` is ignored so developer-specific identifiers are not
committed.

## Build and test

Build or test without local signing:

```sh
xcodebuild \
  -project TavernBlink.xcodeproj \
  -scheme TavernBlink \
  -configuration Debug \
  -derivedDataPath /tmp/TavernBlinkDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Installing or activating the extension requires a correctly signed app placed
in `/Applications`; an unsigned build cannot exercise those runtime paths.

Create a Developer ID Universal 2 archive:

```sh
scripts/archive.sh
```

Package the archived app as a signed DMG:

```sh
scripts/package-dmg.sh \
  build/TavernBlink.xcarchive/Products/Applications/TavernBlink.app \
  build/TavernBlink.dmg
```

Submit, staple, and validate the DMG using credentials stored in Keychain:

```sh
scripts/notarize.sh build/TavernBlink.dmg TavernBlink-Notary
```

Run the final release checks:

```sh
scripts/verify-release.sh \
  build/TavernBlink.xcarchive/Products/Applications/TavernBlink.app \
  build/TavernBlink.dmg
```

## Project map

```text
App/                 menu-bar UI and host-side services
Shared/              IPC contracts and shared models
ProxyExtension/      transparent proxy provider and relay boundaries
Tests/Unit/           pure unit tests
Tests/RelayHarness/   local TCP harness
Tests/Manual/         physical-Mac/game test records
Config/               shared build settings and local signing example
scripts/              archive, DMG, notarization, and verification tools
docs/                 architecture, Phase 0 gates, and release checklist
```
