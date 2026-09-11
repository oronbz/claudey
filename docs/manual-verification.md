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

## Herdr (issue 03)

Run `tools/demo-live-session.sh` from a pane inside Herdr; the Xcode console
logs each `Claudey activity:` event in a debug build.

- [x] Launching with Herdr running shows the current state without a hop:
      idle with agents at rest, concentration if one is already working.
- [x] The demo's first prompt plays concentration, then exactly one hop, then idle.
- [x] The demo's question plays the wave and holds the questioning pose until
      it is answered; answering resumes concentration and ends with one hop.
- [x] Closing the demo pane returns him to rest without a hop.
- [x] `herdr plugin action invoke claudey.connect` while he is running writes
      the connection file and leaves a single Claudey process.
- [x] A second copy launched while one is running quits itself immediately.
- [ ] Stopping the Herdr server puts him to rest; starting it again reconnects
      him within a few seconds without a hop.
- [ ] Typing in another app is undisturbed while a status change arrives.

## Silence

- [x] No sound, no notifications, no badges, no dashboards.
