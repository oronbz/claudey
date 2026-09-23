# Shepherd

A cute, quiet hand-drawn desktop companion for coding agents in Herdr.

Shepherd will live above ordinary macOS windows, react when agents work, finish, or need input, and take you back to the relevant Herdr pane when clicked.

## Status

The macOS companion runs locally: he floats above ordinary windows, breathes and
blinks, reacts to hovering, remembers where he is dragged, and quits from his
own right-click menu. Connected to Herdr, he concentrates while an agent works,
hops once when a response ends, and waves then holds a questioning pose while
an agent waits for you. Clicking him takes you to the Herdr pane behind his
reaction and brings its Ghostty terminal forward. His right-click menu holds
his only controls: pick his avatar (Block, Soft Spark, Ram or Catpuccino), connect to or
disconnect from Herdr, and quit. He never starts at login: the plugin's
startup hook or `Connect Shepherd` action starts him, or you launch him by
hand.

## Installing him

Prerequisites: macOS 26.6 or newer, Xcode 27, Herdr 0.8 or newer on `PATH`,
and Ghostty as the terminal hosting Herdr if you want clicks to bring the
terminal forward.

```bash
tools/install.sh
```

This builds a Release `Shepherd.app` into `~/Applications`, links the Herdr
plugin from `plugin/`, and starts him. Re-running it rebuilds and replaces only
those pieces; Herdr's own configuration, other plugins and everything under
`~/.claude` are left alone. From then on the plugin's startup hook wakes him
with each Herdr session and the `Connect Shepherd` action wakes him on demand.
Set `SHEPHERD_INSTALL_DIR` to install elsewhere.

```bash
tools/uninstall.sh
```

removes the app, the plugin link, and Shepherd's preferences and support
files, and nothing else. See
[Herdr integration](docs/herdr-integration.md) for what the controls do, the
state mapping, protocol notes, limitations and the live demo script.

## Developing him

Open `Shepherd/Shepherd.xcodeproj` and run the `Shepherd` scheme on `My Mac`. He
appears in the lower right of the screen, with no Dock icon and no menu-bar
icon; right-click him for his menu. `Shepherd/Shepherd/Resources/Avatars` links
the committed avatar packs in `assets/avatars`, which are drawn in code; see
[the avatar README](assets/avatars/README.md). A development launch yields to an installed
copy that is already running; quit that one first. Without the plugin he
watches Herdr's default socket.

Tests: `Shepherd/ShepherdTests` (Swift Testing) covers every avatar's frame map, animation
timing, reaction selection, drag-versus-click, position restoration, realistic
Herdr snapshots and events driving his reactions through a fake socket, and
his menu's avatar, connect, disconnect and quit controls. Checks the issues
ask for that no test can reach are listed in
[manual verification](docs/manual-verification.md).

## Project docs

- [Domain glossary](CONTEXT.md)
- [Architecture decision](docs/adr/0002-package-as-a-herdr-plugin-and-companion.md)
- [Herdr integration](docs/herdr-integration.md)
