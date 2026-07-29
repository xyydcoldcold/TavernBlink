# Phase 0 checklist

Do not proceed to product polish until all four gates below pass on a physical
Mac. Store command outputs and test records as release evidence without
capturing payloads, credentials, account names, private addresses, or full user
paths.

## 1. Entitlements and activation

- [ ] Register explicit host, extension, and App Group identifiers.
- [ ] Obtain matching development and Developer ID profiles.
- [ ] Build a signed Debug app in `/Applications`.
- [ ] Activate the extension and handle approval, replacement, failure, and
      reboot-required results.
- [ ] Confirm the extension appears enabled in `systemextensionsctl list`.
- [ ] Archive Release and save actual entitlements from both products:

```sh
codesign -d --entitlements :- /path/to/TavernBlink.app
codesign -d --entitlements :- \
  /path/to/TavernBlink.app/Contents/Library/SystemExtensions/TavernBlinkProxy.systemextension
```

Gate: both archived products retain the approved
`app-proxy-provider-systemextension` and App Group values; the host also retains
the system-extension installation entitlement.

## 2. Transparent proxy manager

- [ ] Create or reuse exactly one manager with the TavernBlink description.
- [ ] Save, reload, enable, and start it.
- [ ] Observe real `NEVPNStatus` changes rather than fixed delays.
- [ ] Stop and disable it, then confirm the UI reflects system state.
- [ ] Repeat enable/disable and app relaunch without duplicate configurations.

Gate: install/start/stop is repeatable and recoverable.

## 3. Source identity

- [ ] Select the installed Hearthstone app.
- [ ] Validate its static signature and record the expected signing identifier.
- [ ] Start Hearthstone after the proxy is active.
- [ ] Record the actual `sourceAppSigningIdentifier` seen by the provider.
- [ ] Confirm Battle.net and unrelated apps do not match.
- [ ] Repeat after a game update.

Gate: the expected and actual identifiers are stable and distinguish the game.
If metadata is empty, keep flows fail-open and investigate a verified audit-token
fallback.

## 4. Disconnect/reconnect viability

This gate begins only after the echo harness passes and the relay is enabled.

- [ ] Confirm a target flow is fully relaying before exposing Disconnect Now.
- [ ] On command, close both flow directions and cancel the upstream connection.
- [ ] Record provider-message and close latency using a monotonic clock.
- [ ] Run 20 real-match trials and fill in
      `Tests/Manual/phase-0-results.csv`.
- [ ] Confirm a replacement flow and game recovery.
- [ ] Run Safari/download/call traffic in parallel and confirm no impact.

Gate: the game reconnects quickly enough for the intended use. If it does not,
stop this implementation route instead of adding UI or retry loops.

## Phase 0 deliverables

- [ ] Development build
- [ ] Twenty-trial result table
- [ ] Archived entitlement snapshots
- [ ] One-page Go/No-Go decision
