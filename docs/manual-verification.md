# Manual verification

Checks the GitHub issues ask for that no test can reach, run by hand on the
owner's Mac. Everything a test process can observe is covered by
`ShepherdTests`.

Build and run from Xcode (scheme `Shepherd`, destination `My Mac`), or install
with `tools/install.sh`. The app has no Dock icon and no menu-bar icon:
Shepherd himself is the whole interface, and right-clicking him opens his menu.

## Remove launch at login (#4)

- [ ] Right-clicking him offers only Avatar, Disconnect from Herdr / Connect
      to Herdr and Quit Shepherd, and the connection item swaps its title when
      chosen.
- [ ] `tools/uninstall.sh` quits him, unlinks the plugin, and removes the app,
      preferences, support files and the plugin config dir without launching
      the app; Herdr's config, other plugins and `~/.claude` are untouched.
