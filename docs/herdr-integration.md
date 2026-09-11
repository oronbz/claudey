# Herdr integration

Claudey reads agent activity from a running Herdr server and shows it through
one character. Herdr is the only state authority: the companion never parses
terminal screens and never touches Claude Code hooks or configuration.

Verified against Herdr 0.8.2, socket protocol 20, on 2026-09-11.

## Pieces

- `plugin/` is the Herdr plugin. Its startup hook and its `Connect Claudey`
  action both run `claudey-connect.sh`, which writes the current
  `HERDR_SOCKET_PATH` to `~/Library/Application Support/Claudey/herdr-connection.json`
  and then runs `open -g` on the app. `open` starts the app if it is not
  running and only delivers a reopen when it is, so repeated activation never
  produces a second Claudey. The hook exits immediately; the app owns its
  lifecycle.
- `Claudey/Herdr/` is the adapter: newline-delimited JSON over the Unix socket,
  `session.snapshot` for the baseline, `events.subscribe` for changes, quiet
  reconnection with backoff up to 30 s.
- `Claudey/Activity/` is Herdr-independent: session records, the aggregate
  state, and the director that decides what Claudey shows.

Link the plugin from a checkout with `herdr plugin link "$PWD/plugin"`. Set
`CLAUDEY_APP=/path/to/Claudey.app` or write that path into
`$(herdr plugin config-dir claudey)/app-path` when the app is not registered
with Launch Services; otherwise `open -g -b com.oronbz.Claudey` is used.
Without the plugin, a developer launch falls back to `HERDR_SOCKET_PATH` and
then `~/.config/herdr/herdr.sock`.

## Translation

| Herdr `agent_status` | Session status | Claudey |
| --- | --- | --- |
| `working` | working | concentration |
| `blocked` | needs you | wave, then held questioning pose |
| `idle`, `done` | ready | idle breathing when nothing else is happening |
| `unknown` | uncertain | resting pose, unless another session is working or needs you |

The aggregate state is needs-you over working over idle. With no agent
sessions, or with no Herdr connection, Claudey rests.

Finished is a live transition from working to ready on the same occupant, and
plays one hop that yields to a held needs-you pose. It means the response
ended, not that the task succeeded. These never celebrate: the initial
snapshot, the snapshot after a reconnect, `done` settling to `idle` when a tab
is viewed, a dismissed question, an uncertain or removed session, or a replaced
occupant in the same pane.

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
  Claude Code manifest does not recognise show as idle, so Claudey may miss a
  question; he never invents one.
- A status change that happens inside the 300 ms arming window of a fresh
  subscription is caught by the reconcile snapshot about a second later.
- A status event naming a different agent than the pane's known occupant is
  not applied; it triggers a reconcile, so a replacement never inherits a hop.
- Herdr's `agent_session` can briefly point at a different Claude session file
  while a tool subprocess runs. A reconcile at that instant resets the pane's
  baseline, which can swallow one hop but never adds a false one.
- One Herdr server at a time. A plugin activation from a different named
  session moves Claudey to that socket.
- Navigation on click is issue 04; activity never requests focus.

## Live demo

With Claudey running, from a pane inside Herdr:

```bash
tools/demo-live-session.sh
```

It splits the current tab, starts Claude Code, sends a prompt that finishes
(concentration, then one hop), then a prompt that asks a question through
`AskUserQuestion` (wave, then the held pose). Answer in the demo pane to see
work resume and a final hop, then close the pane with the printed command. In a
debug build every activity event is logged as `Claudey activity:` in the Xcode
console.
