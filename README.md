# Claudey

A cute, quiet pixel-art desktop companion for coding agents in Herdr.

Claudey will live above ordinary macOS windows, react when agents work, finish, or need input, and take you back to the relevant Herdr pane when clicked.

## Status

The macOS companion runs locally: he floats above ordinary windows, breathes and
blinks, reacts to hovering, remembers where he is dragged, and offers hide/show
and quit from the menu bar. Herdr integration is not implemented yet, so his
reactions are exercised from the development-only Reaction menu.

## Running him

Open `Claudey/Claudey.xcodeproj` and run the `Claudey` scheme on `My Mac`. He
appears in the lower right of the screen and as a paw in the menu bar; there is
no Dock icon. `Claudey/Claudey/Resources` links the committed sprite sheet and
frame map from `assets/claudey`.

Tests: `Claudey/ClaudeyTests` (Swift Testing) covers the frame map, animation
timing, reaction selection, drag-versus-click and position restoration. Window
behavior is checked by hand — see [manual verification](docs/manual-verification.md).

## Project docs

- [Design](docs/design.md)
- [Domain glossary](CONTEXT.md)
- [Architecture decision](docs/adr/0002-package-as-a-herdr-plugin-and-companion.md)
