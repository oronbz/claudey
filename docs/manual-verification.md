# Manual verification: the desktop companion

Shepherd's window behavior cannot be observed from a test bundle, so these checks
are run by hand on the owner's Mac. Everything above the window boundary —
animation selection, frame timing, drag-versus-click, remembered position — is
covered by `ShepherdTests`.

Build and run from Xcode (scheme `Shepherd`, destination `My Mac`). The app has no
Dock icon and no menu-bar icon: Shepherd himself is the whole interface, and
right-clicking him opens his menu.

## Presentation

- [x] Shepherd stands at his 128 px size with clean transparency and crisp pixels.
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
- [x] Dragging moves him; a click at the end of a drag navigates nowhere. A
      plain click navigates (see Click to session below).
- [x] Quitting and relaunching restores his dragged position.
- [ ] Disconnecting a display that held him brings him back into view.

## His menu

- [x] Right-clicking him opens the menu without disturbing keyboard focus.
- [x] The development-only Reaction submenu plays each of the six reactions:
      idle, working, finished, needs-you, resting, hover.
- [x] Quit stops the app cleanly and leaves nothing behind.

## Herdr (issue 03)

Run `tools/demo-live-session.sh` from a pane inside Herdr; the Xcode console
logs each `Shepherd activity:` event in a debug build.

- [x] Launching with Herdr running shows the current state without a hop:
      idle with agents at rest, concentration if one is already working.
- [x] The demo's first prompt plays concentration, then exactly one hop, then idle.
- [x] The demo's question plays the wave and holds the questioning pose until
      it is answered; answering resumes concentration and ends with one hop.
- [x] Closing the demo pane returns him to rest without a hop.
- [x] `herdr plugin action invoke shepherd.connect` while he is running writes
      the connection file and leaves a single Shepherd process.
- [x] A second copy launched while one is running quits itself immediately.
- [ ] Stopping the Herdr server puts him to rest; starting it again reconnects
      him within a few seconds without a hop.
- [x] Typing in another app is undisturbed while a status change arrives.

## Click to session (issue 04)

Verified 2026-09-14 in Ghostty 1.3.2 + Herdr 0.8.2 with a Claude Code session
in a split pane, the click delivered through the real event path; the Xcode
console logs each result as `Shepherd navigation:`.

- [x] An ordinary click while one session works moves Herdr's focus to that
      pane from another workspace; the log reads `focusedPane("w2H:p7")`.
- [x] With Chrome in front and a session needing you in another workspace,
      clicking him selects exactly that pane and brings Ghostty forward; the
      log names the Ghostty terminal (pid of the Herdr client, its tty) and
      `focused: true`.
- [x] Closing the demo pane afterwards returns him to the aggregate state; no
      focus change happens without a click.
- [x] A pane that closes before the click cannot be staged by hand: Herdr's
      `pane_closed` reaches Shepherd within milliseconds. Its safe failure is
      Herdr's own `pane_not_found` answer (probed live against the socket) plus
      the fixture test that turns it into host activation only.
- [ ] Hover, drag and status changes never move focus (covered by tests; watch
      the log for an absent `Shepherd navigation:` while hovering and dragging).
- [ ] Clicking during the completion hop opens the session that just
      finished, even while another one keeps working.
- [ ] With Ghostty's Automation permission revoked for Shepherd (System
      Settings → Privacy & Security → Automation), a click still moves Herdr's
      focus and brings Ghostty forward, animations keep running, and the
      prompt does not reappear during the run.
- [ ] With no Herdr client inside Ghostty, a click plays the happy reaction
      once and nothing else.

## Concurrent sessions and recovery (issue 05)

Run `tools/demo-concurrent-sessions.sh` from a pane inside Herdr while other
sessions may be running; it starts two Claude Code sessions in split panes and
prints what to expect at each step.

Driven on 2026-09-14 with the event log as evidence (see issue 05's
comments); the sprite was not watched, so the visual checks stay open.

- [ ] Step 1: both work; one hop when the short session answers while the long
      one keeps working, then concentration again; a second hop when the long
      one finishes.
- [ ] Step 2: the wave and held pose while the other session works; the other
      session finishing behind the pose plays no hop; answering resumes work
      and ends with one hop.
- [ ] Step 3: two overlapping questions play one wave and one held pose;
      clicking during it opens the first asker; after that one is answered the
      pose stays and a click opens the second.
- [ ] Step 4: closing both panes returns him to the remaining sessions' state
      without a hop.
- [ ] No badge, panel, sound or focus change appears at any point unless he is
      clicked.
- [ ] Stopping the Herdr server puts him to rest; starting it again reconnects
      him and shows the sessions' current state without a hop (same check as
      issue 03; it ends every Herdr session on the machine, so run it by hand).

## Installation and everyday controls (issue 06)

Run `tools/install.sh` (with `SHEPHERD_CONFIGURATION=Debug` to drive the menu
through signals: `-USR1` clicks, `-USR2` connects/disconnects). Driven on
2026-09-16 on the owner's Mac (macOS 26.6.1, Xcode 27.0, Herdr 0.8.2, Ghostty
1.3.2) with the installed app's log as evidence; the sprite was not watched, so visual checks stay open.

- [x] `tools/install.sh` builds, installs `~/Applications/Shepherd.app`, links
      the plugin, writes `app-path`, and starts exactly one Shepherd from the
      installed bundle. Running it again replaces the app and relinks without
      touching `~/.config/herdr/config.toml`, other plugins or `~/.claude`.
- [x] `herdr plugin action invoke connect --plugin shepherd` and the startup
      hook against a running copy leave one process and no `connect-request`.
- [x] A second launch of the installed binary quits itself at once.
- [x] Disconnect rests him and is remembered (`herdrConnectionEnabled = 0`);
      the startup hook (`shepherd-connect.sh` without `--connect`) leaves him
      disconnected; the Connect action reconnects and the marker is consumed.
- [x] Reconnect after a disconnect logs `disconnected` then one `connected`
      snapshot with the sessions' current states and no hop.
- [x] Quit stops the process; nothing relaunches it within ten seconds; the
      startup hook starts a fresh copy afterwards.
- [x] The installed flow end to end with `tools/demo-live-session.sh`: fresh
      session appears ready with no hop, working → ready (hop), working →
      needs-you, a click during the pose focuses that pane and its Ghostty
      terminal (`focusedPane("w2H:pH")`, `focused: true`), closing the pane
      removes the session without a hop.
- [x] `tools/uninstall.sh`: quits him, unlinks the plugin, removes the app,
      preferences, support files and the plugin config dir; Herdr's config,
      the `annotate` plugin and `~/.claude/settings.json` are untouched
      afterwards.
- [ ] `tools/uninstall.sh` does the same without launching the app (issue 4
      removed its launch-at-login step; not yet run by hand).
- [ ] The menu itself, by pointer: Disconnect from Herdr / Connect to Herdr
      swap titles, and the menu offers only Avatar, the connection item and
      Quit Shepherd.
- [ ] Right-clicking him and choosing any item leaves keyboard focus where it
      was.
- [ ] Dragging the installed copy and relaunching restores his position;
      desktop spaces and full-screen exclusion behave as in Presentation above
      (the space-switch and display-disconnect checks there are still open).

## Silence

- [x] No sound, no notifications, no badges, no dashboards.
