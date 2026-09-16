# Claudey

A cute, quiet pixel-art desktop companion for coding agents in Herdr.

Claudey will live above ordinary macOS windows, react when agents work, finish, or need input, and take you back to the relevant Herdr pane when clicked.

## Status

The macOS companion runs locally: he floats above ordinary windows, breathes and
blinks, reacts to hovering, remembers where he is dragged, and quits from his
own right-click menu. Connected to Herdr, he concentrates while an agent works,
hops once when a response ends, and waves then holds a questioning pose while
an agent waits for you. Clicking him takes you to the Herdr pane behind his
reaction and brings its Ghostty terminal forward. His right-click menu holds
his only controls: connect to or disconnect from Herdr, launch at login (off
until you turn it on), and quit.

## Installing him

Prerequisites: macOS 26.6 or newer, Xcode 27, Herdr 0.8 or newer on `PATH`,
and Ghostty as the terminal hosting Herdr if you want clicks to bring the
terminal forward.

```bash
tools/install.sh
```

This builds a Release `Claudey.app` into `~/Applications`, links the Herdr
plugin from `plugin/`, and starts him. Re-running it rebuilds and replaces only
those pieces; Herdr's own configuration, other plugins and everything under
`~/.claude` are left alone. From then on the plugin's startup hook wakes him
with each Herdr session and the `Connect Claudey` action wakes him on demand.
Set `CLAUDEY_INSTALL_DIR` to install elsewhere.

```bash
tools/uninstall.sh
```

removes the app, its login item, the plugin link, and Claudey's preferences
and support files, and nothing else. See
[Herdr integration](docs/herdr-integration.md) for what the controls do, the
state mapping, protocol notes, limitations and the live demo script.

## Developing him

Open `Claudey/Claudey.xcodeproj` and run the `Claudey` scheme on `My Mac`. He
appears in the lower right of the screen, with no Dock icon and no menu-bar
icon; right-click him for his menu. `Claudey/Claudey/Resources` links the committed sprite sheet and
frame map from `assets/claudey`. A development launch yields to an installed
copy that is already running; quit that one first. Without the plugin he
watches Herdr's default socket.

Tests: `Claudey/ClaudeyTests` (Swift Testing) covers the frame map, animation
timing, reaction selection, drag-versus-click, position restoration, realistic
Herdr snapshots and events driving his reactions through a fake socket, and
his menu's connect, disconnect and launch-at-login controls. Window behavior
and the installed flow are checked by hand — see
[manual verification](docs/manual-verification.md).

## Project docs

- [Design](docs/design.md)
- [Domain glossary](CONTEXT.md)
- [Architecture decision](docs/adr/0002-package-as-a-herdr-plugin-and-companion.md)
- [Herdr integration](docs/herdr-integration.md)
