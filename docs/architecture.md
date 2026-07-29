# Architecture

TavernBlink has a small control plane and a provider-owned data plane.

```text
Menu-bar App
  ├─ SystemExtensionController ── OSSystemExtensionRequest
  ├─ ProxyManagerController ───── NETransparentProxyManager
  ├─ ProviderMessenger ────────── sendProviderMessage
  └─ TargetAppIdentityResolver ── Security.framework
                                      │
                                      ▼
TransparentProxyProvider
  ├─ FlowMatcher ─────────────── exact source signing identifier
  ├─ FlowRegistry ────────────── atomic relay ownership/close
  └─ TCPFlowRelay ────────────── NEAppProxyTCPFlow ⇄ NWConnection
```

The IPC contract is versioned and request-ID based. Duplicate request IDs must
return the original result. Persistent shared state is limited to the verified
target signing identity and small diagnostic summaries.

## Current safety boundary

The provider applies one outbound TCP rule but returns `false` from
`handleNewFlow` even when the signing identifier matches. Transparent-proxy flow
copying therefore leaves traffic with the system. This is intentional: the
provider must not return `true` until the TCP relay owns the flow, has bounded
backpressure, and can close every terminal path exactly once.

Missing source signing identity never broadens matching. An audit-token fallback
may be added only after independent code-signature verification is implemented.

## Runtime states

The host models install/approval, configuration, startup, readiness with or
without target flows, disconnect progress, success, and explicit errors.
Provider startup always begins with an empty registry. Provider stop snapshots
and closes the registry, then invokes the stop completion once.

## Out of scope for the skeleton

- payload parsing or TLS interception;
- UDP relaying;
- automatic battle detection;
- global shortcuts;
- telemetry or a cloud service;
- process injection, memory access, or anti-cheat evasion;
- automatic update machinery.
