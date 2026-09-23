# Herdr integration

Shepherd reads agent activity from a running Herdr server and shows it through
one character. Herdr is the only state authority: the companion never parses
terminal screens and never touches Claude Code hooks or configuration.

Verified against Herdr 0.8.2, socket protocol 20, on 2026-09-11.

## Pieces

- `plugin/` is the Herdr plugin. Its startup hook and its `Connect Shepherd`
  action both run `shepherd-connect.sh`, which writes the current
  `HERDR_SOCKET_PATH` to `~/Library/Application Support/Shepherd/herdr-connection.json`
  and then runs `open -g` on the app. `open` starts the app if it is not
  running and only delivers a reopen when it is, so repeated activation never
  produces a second Shepherd. The hook exits immediately; the app owns its
  lifecycle. The action alone passes `--connect`, which also leaves a
  `connect-request` marker next to the context file; the app consumes it to
  override a disconnect the owner chose (see Controls).
- The plugin's one build step runs `shepherd-install-app.sh` during
  `herdr plugin install`. It finds `brew` on `PATH`, then at
  `/opt/homebrew/bin/brew` and `/usr/local/bin/brew`, and installs the
  `oronbz/tap/shepherd` cask or upgrades it when already installed. A missing
  Homebrew or any `brew` failure exits non-zero, so Herdr aborts the install
  and never registers the plugin without the app. Build steps get no Herdr
  environment and must not change the manifest, so the script relies on
  neither. `SHEPHERD_BREW_FALLBACKS` (colon-separated `brew` paths) replaces
  the standard prefixes for `tools/test-plugin.sh`.
- `Shepherd/Herdr/` is the adapter: newline-delimited JSON over a plain BSD
  Unix socket, `session.snapshot` for the baseline, `events.subscribe` for
  changes, quiet reconnection with backoff up to 30 s.
- `Shepherd/Activity/` is Herdr-independent: session records, the aggregate
  state, the director that decides what Shepherd shows, and the click navigator
  that turns an intentional click into one navigation request.
- `Shepherd/Navigation/` is the native side of a click: Herdr's `pane.focus`
  for the exact pane, then Ghostty's AppleScript `focus` for the terminal that
  hosts the Herdr client.

`tools/install.sh` builds the app, copies it to `~/Applications`, links the
plugin and writes the app's path into `$(herdr plugin config-dir shepherd)/app-path`,
which the launcher prefers; `SHEPHERD_APP=/path/to/Shepherd.app` overrides it
and `open -g -b com.oronbz.Shepherd` is the last resort. `tools/uninstall.sh`
reverses exactly that. Without the plugin, a developer launch falls back to
`HERDR_SOCKET_PATH` and then `~/.config/herdr/herdr.sock`. A Homebrew install
writes no `app-path`, so the launcher reaches the app in `/Applications`
through that last resort.

## Controls

Shepherd's right-click menu is his whole interface: hide/show was dropped in
issue 02 (a hidden avatar has nothing to right-click), so presence is quit.

- **Disconnect from Herdr / Connect to Herdr.** Disconnecting stops watching
  Herdr at once, puts him to rest and cancels retry; the choice is stored in
  his preferences (`herdrConnectionEnabled`) and survives relaunches and the
  plugin's startup hook, which only refreshes a connection the owner still
  wants. Connecting again, from the menu or through the plugin's `Connect
  Shepherd` action (which `tools/install.sh` also uses to start him), reads a
  fresh snapshot: current activity is shown and nothing that happened while
  disconnected is celebrated. `HerdrLink` holds this rule.
- **Quit Shepherd.** Stops the app. Nothing relaunches it: the plugin's hook is
  a one-shot `open`, there is no launch agent, and retry lives inside the
  process that just ended. The next Herdr session or the Connect action
  starts him again.

He has no launch-at-login option: he only reacts to sessions in Herdr, and the
plugin's startup hook and `Connect Shepherd` action already start him when
there is something to watch.

## Translation

| Herdr `agent_status` | Session status | Shepherd |
| --- | --- | --- |
| `working` | working | concentration |
| `blocked` | needs you | wave, then held questioning pose |
| `idle`, `done` | ready | idle breathing when nothing else is happening |
| `unknown` | uncertain | resting pose, unless another session is working or needs you |

The aggregate state is needs-you over working over idle. With no agent
sessions, or with no Herdr connection, Shepherd rests.

Finished is a live transition from working to ready on the same occupant, and
plays one hop that yields to a held needs-you pose. It means the response
ended, not that the task succeeded. These never celebrate: the initial
snapshot, the snapshot after a reconnect, `done` settling to `idle` when a tab
is viewed, a dismissed question, an uncertain or removed session, or a replaced
occupant in the same pane.

## Click to session

Only a click navigates. Hover, drag, activity events and reconnects never
request focus. The target is resolved when the click lands, against the
sessions Herdr currently reports:

1. a session that needs you. The questioning pose pins the session that
   started it, so a second question arriving mid-pose does not move the click;
   once the pinned session is answered or gone, the most recently changed
   session still waiting takes over and the pose carries on without a new wave;
2. the session whose completion hop is still playing, provided the same
   occupant (pane, agent and `agent_session`) is still there;
3. otherwise the most recently active session.

Navigation is two separate effects. Herdr's `pane.focus` selects the exact
pane, switching workspace and tab; Herdr validates the pane itself and answers
`pane_not_found` for a closed one, so nothing else is ever focused in its
place. Then Ghostty brings its terminal forward: the Herdr client is a `herdr`
process with a controlling tty whose ancestry reaches the Ghostty app process,
and Ghostty's AppleScript dictionary exposes each terminal's foreground `pid`
and `tty`, so the matching terminal is focused by its stable id.

Fallbacks are quiet. A vanished or replaced target, a `pane_not_found`, or a
click with no session at all activates the known host instead. Without
Automation permission for Ghostty, Shepherd activates the app without picking
a terminal, and remembers the refusal for the rest of the run so macOS is not
asked twice. With no Herdr client inside Ghostty at all, he plays his happy
reaction once and does nothing else: no popup, no panel.

The usage string macOS shows on the first permission prompt is
`NSAppleEventsUsageDescription` in the app target's build settings.

## Several sessions at once

Every agent pane Herdr reports feeds the same character. Needs-you outranks
working, working outranks idle, and an uncertain session never hides a sibling
whose state is known. Each completion plays one hop with its own click target;
a hop that starts while another is in the air replaces it rather than queueing
behind it, and a completion that lands behind a held questioning pose is not
saved up to play later. Sessions in one project stay distinct because identity
is the pane, never the directory or title.

Losing Herdr puts him to rest at once and drops every session and target;
reconnection is automatic with backoff up to 30 s. The snapshot taken after a
reconnect is a new baseline: whatever finished, was interrupted or vanished
while the connection was down is shown as its current state and never
celebrated. Lines that still arrive from a subscription of the lost connection
are ignored.

## Protocol facts the adapter relies on

- Herdr answers one request per connection and then closes it. Subscriptions
  keep their connection open.
- `pane.updated` does not fire for status-only changes, and its embedded agent
  record can flip between transient re-detections while a tool runs. Status
  comes from a per-pane `pane.agent_status_changed` subscription instead; those
  events arrive under the dotted name `pane.agent_status_changed`, while
  lifecycle events use underscores such as `pane_closed`.
- A new subscription replays a backlog of recent events. Every subscription is
  ignored until 300 ms after its acknowledgement, and the baseline snapshot is
  taken after that. A one-second, coalesced reconcile snapshot runs whenever a
  subscription arms, an agent is detected in an unknown pane, or a pane moves.
- `pane_agent_detected` toggles `released` at roughly 10 Hz while an agent runs
  a subprocess. A first sighting opens a status subscription; a release on a
  known pane only schedules the coalesced reconcile, which is also how an agent
  that exits and leaves its shell behind is forgotten.
- `done` is reported when a background tab finishes unseen; focusing the tab
  turns it into `idle` without another transition of interest.

## Limitations

- Needs-you is Herdr's screen-based `blocked` classification. Prompts Herdr's
  Claude Code manifest does not recognise show as idle, so Shepherd may miss a
  question; he never invents one.
- The socket is a BSD socket on purpose. Network.framework connections to
  the same path intermittently fail with POSIX 50 "Network is down" on the
  owner's Mac, which runs Netskope's app-proxy and CrowdStrike network
  extensions: almost every one-shot request from Shepherd, about one in forty
  from a bare CLI, while raw sockets never fail. A snapshot that still fails
  is logged as `Shepherd could not read Herdr's … snapshot:` with the error.
- Herdr reports an interrupted turn (Escape in Claude Code) as working → idle,
  the same transition as a finished response, so an interruption hops. That
  is consistent with what finished means here: the response ended, nothing
  about the outcome. Shepherd has no way to tell the two apart without parsing
  the screen, which he does not do.
- Several Herdr servers, remote or detached clients: sessions are read from
  the one socket the plugin names, and navigation is only for panes of that
  server inside a local Ghostty.
- A status change that happens inside the 300 ms arming window of a fresh
  subscription is caught by the reconcile snapshot about a second later.
- A status event naming a different agent than the pane's known occupant is
  not applied; it triggers a reconcile, so a replacement never inherits a hop.
- Herdr's `agent_session` can briefly point at a different Claude session file
  while a tool subprocess runs. A reconcile at that instant resets the pane's
  baseline, which can swallow one hop but never adds a false one.
- One Herdr server at a time. A plugin activation from a different named
  session moves Shepherd to that socket.
- Host activation finds the Herdr client by process ancestry under Ghostty.
  Several clients in Ghostty (for example a named session next to the default
  one) are not told apart by socket; the first match wins. Remote and detached
  clients, and Herdr hosted by another terminal app, fall back to the playful
  reaction.
- The Herdr client is the oldest `herdr` process with a tty under Ghostty, so
  a `herdr` CLI call running briefly in another Ghostty shell does not win.
- AppleScript runs on a private serial queue rather than the main thread so a
  permission dialog cannot freeze the animation; NSAppleScript is used from
  that one queue only.
- Two occupants of one pane that both lack an `agent_session` look identical
  to Shepherd, at the adapter as well as at click time.
- The completion hop keeps its target for the one second it plays. A click
  after that follows the most-recently-active rule, which usually still names
  the same session.
- The app is ad-hoc signed, both from `tools/install.sh` and in the Homebrew
  cask (see [releasing](releasing.md)); there is no notarisation or App Store
  delivery. Ghostty's Automation permission is granted to this bundle id and
  is reset by `tools/uninstall.sh`, not by the cask's zap.

## Live demo

With Shepherd running, from a pane inside Herdr:

```bash
tools/demo-live-session.sh
```

It splits the current tab, starts Claude Code, sends a prompt that finishes
(concentration, then one hop), then a prompt that asks a question through
`AskUserQuestion` (wave, then the held pose). Answer in the demo pane to see
work resume and a final hop, then close the pane with the printed command. In a
debug build every activity event is logged as `Shepherd activity:` and every
click's result as `Shepherd navigation:` in the Xcode console, and
`kill -USR1 $(pgrep -x Shepherd)` performs the same navigation as a click so
the path can be driven from a script; `kill -USR2` toggles his connect/
disconnect menu item the same way.
`tools/install.sh` accepts `SHEPHERD_CONFIGURATION=Debug` for such runs.
