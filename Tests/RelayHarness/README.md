# Relay harness

The XCTest relay harness is runnable without Hearthstone and covers:

- 1–256 byte bidirectional messages;
- a continuous 500 MB transfer;
- 100–500 ms delayed reads/writes;
- EOF from either direction;
- a user-requested close during transfer;
- 20 concurrent flows;
- repeated close requests;
- bounded memory with one in-flight block per direction.

Run the complete harness with:

```sh
xcodebuild \
  -project TavernBlink.xcodeproj \
  -scheme TavernBlink \
  -configuration Debug \
  -derivedDataPath /tmp/TavernBlinkDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```
