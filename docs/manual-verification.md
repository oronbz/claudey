# Manual verification

Checks the GitHub issues ask for that no test can reach, run by hand on the
owner's Mac. Everything a test process can observe is covered by
`ShepherdTests`.

Build and run from Xcode (scheme `Shepherd`, destination `My Mac`), or install
with `tools/install.sh`. The app has no Dock icon and no menu-bar icon:
Shepherd himself is the whole interface, and right-clicking him opens his menu.

## Homebrew cask (#5)

- [ ] `tools/release.sh` refuses to run when the app's version and the plugin
      manifest's differ, and otherwise prints the zip path and its sha256.
- [ ] `brew style` and `brew audit --cask --online oronbz/tap/shepherd` pass.
- [ ] With no developer install present, `brew install --cask
      oronbz/tap/shepherd` puts `Shepherd.app` in `/Applications`, and he
      launches after approving him once under Privacy & Security.
- [ ] `brew info --cask shepherd` shows the released version.
- [ ] With him running, `brew uninstall --cask shepherd` quits him before the
      app is removed.
- [ ] After reinstalling and launching him, `brew uninstall --zap --cask
      shepherd` leaves no `/Applications/Shepherd.app`, no
      `~/Library/Application Support/Shepherd` and no
      `~/Library/Preferences/com.oronbz.Shepherd.plist`
      (`defaults read com.oronbz.Shepherd` fails).

## Remove launch at login (#4)

Verified by the owner on 2026-09-23.

- [x] Right-clicking him offers only Avatar, Disconnect from Herdr / Connect
      to Herdr and Quit Shepherd, and the connection item swaps its title when
      chosen. A Debug build also shows the development-only Reaction submenu.
- [x] `tools/uninstall.sh` quits him, unlinks the plugin, and removes the app,
      preferences, support files and the plugin config dir without launching
      the app; Herdr's config, other plugins and `~/.claude` are untouched.
