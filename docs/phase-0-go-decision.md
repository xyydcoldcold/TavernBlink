# Phase 0 Go Decision

## Decision

**GO**

The Phase 0 implementation route is viable. TavernBlink Build 7 with Proxy
Extension Build 6 consistently closed one selected Hearthstone gameplay flow,
triggered a replacement flow, and recovered the game without an observed
provider crash, secondary disconnect, or non-target traffic incident.

This decision authorizes work on release packaging and second-Mac validation.
It does not by itself declare the app ready for public distribution.

## Test baseline

- Decision date: 2026-07-30
- Source commit: `0e62532` (`fix: disconnect only one preferred Hearthstone flow`)
- Host app: TavernBlink Build 7
- System extension: TavernBlinkProxy Build 6
- macOS: 26.5.2 (25F84)
- Mac architecture: arm64
- Hearthstone build: 36.0.246003
- Expected signing identifier:
  `unity.Blizzard Entertainment.Hearthstone`
- Actual signing identifier:
  `unity.Blizzard Entertainment.Hearthstone`
- Expected Blizzard Team ID: `G847MC6JZ5`

## Results

| Measure | Result |
| --- | ---: |
| Trials reported | 20 |
| Recovered within 5 seconds | 20/20 |
| Eventually recovered | 20/20 |
| Provider crashes | 0 |
| Secondary disconnects | 0 |
| Non-target traffic incidents | 0 |

## Retained technical evidence

The macOS unified log retained 14 corresponding Build 6 disconnect events:

- 14/14 commands closed exactly one flow.
- 14/14 selected remote port 3724.
- Provider-reported flow-close duration was 0 ms for all 14 events.
- A replacement port 3724 flow appeared 13–215 ms after the recorded close.
- The 14-sample nearest-rank p95 replacement-flow time was 215 ms.

The operator visually confirmed game recovery within 5 seconds for all 20
trials. Exact per-trial game-recovery timestamps and monotonic click timestamps
were not recorded, so those CSV cells remain empty rather than containing
estimated values. Six trials are represented by the operator's aggregate report
without a retained matching unified-log timestamp.

Detailed rows are stored in
[`Tests/Manual/phase-0-results.csv`](../Tests/Manual/phase-0-results.csv).

## Release implications

Proceed with:

1. a Developer ID-signed Universal 2 Release archive;
2. archive entitlement and signature evidence capture;
3. DMG creation, notarization, stapling, and Gatekeeper verification;
4. a clean install, approval, disconnect, disable, and uninstall test on a
   second physical Mac;
5. release notes covering unofficial-tool and account-risk warnings.

Public release remains blocked until the release checklist is complete.
