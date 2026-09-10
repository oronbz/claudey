# Manual verification: the desktop companion

Claudey's window behavior cannot be observed from a test bundle, so these checks
are run by hand on the owner's Mac. Everything above the window boundary —
animation selection, frame timing, drag-versus-click, remembered position — is
covered by `ClaudeyTests`.

Build and run from Xcode (scheme `Claudey`, destination `My Mac`). The app has no
Dock icon and no menu-bar icon: Claudey himself is the whole interface, and
right-clicking him opens his menu.

## Presentation

- [x] Claudey stands at his 128 px size with clean transparency and crisp pixels.
- [x] Idle breathing and blinking play continuously.
- [x] He floats above ordinary windows of other apps.
- [ ] Switching to another desktop space brings him along, rather than
      leaving him behind or showing a second copy.
- [x] Entering a full-screen app leaves him hidden behind it.
- [x] Typing in another app continues uninterrupted while he appears and animates.

## Interaction

- [x] Hovering plays the happy reaction; leaving restores the previous reaction.
      A completion hop caught mid-air by a hover resumes instead of being lost.
- [x] He keeps animating while being dragged and while his menu is open.
- [x] Dragging moves him; a click at the end of a drag logs nothing. A plain
      click logs "Claudey was clicked" in a debug build — navigation is issue 04.
- [x] Quitting and relaunching restores his dragged position.
- [ ] Disconnecting a display that held him brings him back into view.

## His menu

- [x] Right-clicking him opens the menu without disturbing keyboard focus.
- [x] The development-only Reaction submenu plays each of the six reactions:
      idle, working, finished, needs-you, resting, hover.
- [x] Quit stops the app cleanly and leaves nothing behind.

## Silence

- [x] No sound, no notifications, no badges, no dashboards.
