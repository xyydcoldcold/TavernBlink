# Release checklist

- [ ] Phase 0 has a written Go decision.
- [ ] Unit tests and the full relay harness pass.
- [ ] Physical-Mac network and game matrices pass.
- [ ] Host app and system extension are Universal 2.
- [ ] Archive contains the extension under
      `Contents/Library/SystemExtensions`.
- [ ] Actual entitlements match approved profiles.
- [ ] DMG is signed, notarized, and stapled.
- [ ] `codesign`, `stapler`, and `spctl` verification pass.
- [ ] SHA-256 checksum is published.
- [ ] A second physical Mac completes install, approvals, disconnect, disable,
      and uninstall.
- [ ] Release notes repeat the unofficial-tool and account-risk warning.
- [ ] Privacy and diagnostic-export contents are documented.

Notarization verifies signing/integrity requirements; it is not Apple or Blizzard
approval of the software's purpose.
