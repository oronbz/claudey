# Claudey

A cute, quiet pixel-art desktop companion for coding agents in Herdr.

Claudey will live above ordinary macOS windows, react when agents work, finish, or need input, and take you back to the relevant Herdr pane when clicked.

## Status

The macOS companion runs locally: he floats above ordinary windows, breathes and
blinks, reacts to hovering, remembers where he is dragged, and quits from his
own right-click menu. Connected to Herdr, he concentrates while an agent works,
hops once when a response ends, and waves then holds a questioning pose while
an agent waits for you. Clicking him takes you to the Herdr pane behind his
reaction and brings its Ghostty terminal forward.

## Running him

Open `Claudey/Claudey.xcodeproj` and run the `Claudey` scheme on `My Mac`. He
appears in the lower right of the screen, with no Dock icon and no menu-bar
icon; right-click him for his menu. `Claudey/Claudey/Resources` links the committed sprite sheet and
frame map from `assets/claudey`.

Link the Herdr plugin with `herdr plugin link "$PWD/plugin"`; its startup hook
and `Connect Claudey` action start or reconnect him. Without it he watches
Herdr's default socket. See [Herdr integration](docs/herdr-integration.md) for
the state mapping, protocol notes, limitations and the live demo script.

Tests: `Claudey/ClaudeyTests` (Swift Testing) covers the frame map, animation
timing, reaction selection, drag-versus-click, position restoration, and
realistic Herdr snapshots and events driving his reactions through a fake
socket. Window behavior is checked by hand — see
[manual verification](docs/manual-verification.md).

## Project docs

- [Design](docs/design.md)
- [Domain glossary](CONTEXT.md)
- [Architecture decision](docs/adr/0002-package-as-a-herdr-plugin-and-companion.md)
- [Herdr integration](docs/herdr-integration.md)
