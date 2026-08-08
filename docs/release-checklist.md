# Release checklist

- [x] Phase 0 has a written Go decision.
- [ ] Unit tests and the full relay harness pass.
- [ ] Physical-Mac network and game matrices pass.
- [ ] The floating Disconnect panel remains clickable over full-screen
      Hearthstone without taking keyboard focus from the game.
- [ ] The floating control remains visually centered at its fixed size after
      upgrading from a build that saved a different panel size.
- [ ] The ready state is visibly distinct from the disabled waiting state in
      both light and dark backgrounds.
- [ ] After one successful disconnect and reconnect, the floating button
      automatically becomes available and a second disconnect also succeeds.
- [ ] Port `443`-only target traffic never enables Disconnect and is never
      selected as a fallback.
- [ ] Both current port `1119` and legacy port `3724` gameplay flows enable
      Disconnect after the stability delay.
- [ ] Rapid repeated clicks result in exactly one flow close during the
      two-second cooldown; the replacement flow remains connected.
- [ ] Settings switches the menu-bar panel, floating control, and setup window
      between English and Simplified Chinese, including after relaunch.
- [x] Host app and system extension are Universal 2.
- [x] Archive contains the extension under
      `Contents/Library/SystemExtensions`.
- [x] Actual entitlements match approved profiles.
- [x] A signed DMG contains TavernBlink.app and an Applications shortcut.
- [x] DMG is signed, notarized, and stapled.
- [x] `codesign`, `stapler`, and `spctl` verification pass.
- [ ] SHA-256 checksum is published.
- [ ] A second physical Mac completes install, approvals, disconnect, safe
      automatic disable on Quit, and uninstall.
- [ ] Release notes repeat the unofficial-tool and account-risk warning.
- [ ] Privacy and diagnostic-export contents are documented.

Notarization verifies signing/integrity requirements; it is not Apple or Blizzard
approval of the software's purpose.
