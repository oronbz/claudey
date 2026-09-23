# Manual verification

Checks the GitHub issues ask for that no test can reach, run by hand on the
owner's Mac. Everything a test process can observe is covered by
`ShepherdTests`.

Build and run from Xcode (scheme `Shepherd`, destination `My Mac`), or install
with `tools/install.sh`. The app has no Dock icon and no menu-bar icon:
Shepherd himself is the whole interface, and right-clicking him opens his menu.

## Install through the Herdr plugin (#6)

Start with no developer install (`tools/uninstall.sh`) and no cask
(`brew uninstall --zap --cask shepherd`). `tools/test-plugin.sh` passes.

- [ ] `herdr plugin install oronbz/shepherd/plugin` shows a preview that lists
      the `bash shepherd-install-app.sh` build step.
- [ ] Confirming it installs the `shepherd` cask into `/Applications`
      (`brew list --cask shepherd` succeeds) and registers the plugin
      (`herdr plugin list` shows `shepherd`).
- [ ] The install starts him right away (after approving his first launch
      under Privacy & Security and running `Connect Shepherd`), watching the
      default Herdr session.
- [ ] A new Herdr server (`herdr --session shepherd-check`) starts him from the
      startup hook, and `Connect Shepherd` wakes him when he has been quit.
- [ ] With an older cask installed (`brew info --cask shepherd` shows it
      outdated), running the same `herdr plugin install` again upgrades it to
      the latest release rather than failing, and he is running again when it
      finishes.
- [ ] With an older cask installed (`brew info --cask shepherd` shows it
      outdated), `brew upgrade --cask shepherd` upgrades him.

## Homebrew cask (#5)

Verified by the owner on 2026-09-23 with v0.1.0.

- [x] `tools/release.sh` refuses to run when the app's version and the plugin
      manifest's differ, and otherwise prints the zip path and its sha256.
- [x] `brew style` and `brew audit --cask --online oronbz/tap/shepherd` pass.
- [x] With no developer install present, `brew install --cask
      oronbz/tap/shepherd` puts `Shepherd.app` in `/Applications`, and he
      launches after approving him once under Privacy & Security. The owner's
      Mac has Gatekeeper assessments disabled (`spctl --status`), so he
      launched with no prompt and the approval step is still unobserved.
- [x] `brew info --cask shepherd` shows the released version.
- [x] With him running, `brew uninstall --cask shepherd` quits him before the
      app is removed.
- [x] After reinstalling and launching him, `brew uninstall --zap --cask
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
