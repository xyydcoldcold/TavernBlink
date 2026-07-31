# Release checklist

- [x] Phase 0 has a written Go decision.
- [ ] Unit tests and the full relay harness pass.
- [ ] Physical-Mac network and game matrices pass.
- [x] Host app and system extension are Universal 2.
- [x] Archive contains the extension under
      `Contents/Library/SystemExtensions`.
- [x] Actual entitlements match approved profiles.
- [x] A signed DMG contains TavernBlink.app and an Applications shortcut.
- [x] DMG is signed, notarized, and stapled.
- [x] `codesign`, `stapler`, and `spctl` verification pass.
- [ ] SHA-256 checksum is published.
- [ ] A second physical Mac completes install, approvals, disconnect, disable,
      and uninstall.
- [ ] Release notes repeat the unofficial-tool and account-risk warning.
- [ ] Privacy and diagnostic-export contents are documented.

Notarization verifies signing/integrity requirements; it is not Apple or Blizzard
approval of the software's purpose.
