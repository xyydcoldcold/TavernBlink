# Relay harness

This directory is reserved for the Phase 3 local TCP relay harness. The harness
must be runnable without Hearthstone and cover:

- 1–256 byte bidirectional messages;
- a continuous 500 MB transfer;
- 100–500 ms delayed reads/writes;
- EOF from either direction;
- a user-requested close during transfer;
- 20 concurrent flows;
- repeated close requests;
- bounded memory with one in-flight block per direction.

Do not connect `TCPFlowRelay` from `handleNewFlow` until this matrix passes and
all terminal paths converge on one idempotent close operation.
