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
disconnect from Herdr, and quit. He never starts at login: installing the
plugin, its startup hook or its `Connect Shepherd` action starts him, or you
launch him by hand.

## Installing him

Prerequisites: macOS 26.6 or newer, [Homebrew](https://brew.sh), Herdr 0.8 or
newer, and Ghostty as the terminal hosting Herdr if you want clicks to bring
the terminal forward.

```bash
herdr plugin install oronbz/shepherd/plugin
```

Herdr's preview lists the plugin's one build step, which installs the
`shepherd` cask from [oronbz/tap](https://github.com/oronbz/homebrew-tap) into
`/Applications`, or upgrades it when he is already installed. Without Homebrew
the install stops and points to it; if Homebrew fails, the install fails with
its output and the plugin is not registered. Once Homebrew is done the build
step starts him, watching Herdr's default session; in a named session, run
`Connect Shepherd` to point him at it. From then on the plugin's startup hook
wakes him with each Herdr server start and the `Connect Shepherd` action wakes
him on demand. No Xcode is needed.

He is ad-hoc signed, so macOS blocks his first launch. Open System Settings >
Privacy & Security, choose Open Anyway next to Shepherd, then run
`Connect Shepherd`. Clicking him asks once for
permission to control Ghostty; that prompt can come back after an upgrade,
because each build carries a new signature.

To update him, reinstall the plugin with the same command, which also
restarts him, or run `brew upgrade --cask shepherd` and then
`Connect Shepherd`. To remove him, run
`brew uninstall --zap --cask shepherd`, then `herdr plugin uninstall shepherd`.

### From a checkout

Developer builds need Xcode 27 and `herdr` on `PATH`.

```bash
tools/install.sh
```

This builds a Release `Shepherd.app` into `~/Applications`, links the Herdr
plugin from `plugin/`, and starts him. Re-running it rebuilds and replaces only
those pieces; Herdr's own configuration, other plugins and everything under
`~/.claude` are left alone. Linking skips the plugin's build step, so Homebrew
is not involved. Set `SHEPHERD_INSTALL_DIR` to install elsewhere.

```bash
tools/uninstall.sh
```

removes the app, the plugin link, and Shepherd's preferences and support
files, and nothing else. See
[Herdr integration](docs/herdr-integration.md) for what the controls do, the
state mapping, protocol notes, limitations and the live demo script.

A developer install and a Homebrew install of Shepherd must not coexist: both
share one bundle id, and Herdr refuses to install the plugin over a linked
one. Remove one before installing the other; see
[releasing](docs/releasing.md).

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
his menu's avatar, connect, disconnect and quit controls. `tools/test-plugin.sh`
runs the plugin's Homebrew build step against a fake `brew`. Checks the issues
ask for that no test can reach are listed in
[manual verification](docs/manual-verification.md).

## Project docs

- [Domain glossary](CONTEXT.md)
- [Architecture decision](docs/adr/0002-package-as-a-herdr-plugin-and-companion.md)
- [Herdr integration](docs/herdr-integration.md)
- [Releasing](docs/releasing.md)
