# Session focus research

Verified 2026-09-10. Research only: no window, tab, or pane focus was changed.

## Herdr

The installed Herdr 0.9.0 CLI supports `herdr agent focus <target>`; target is a live agent name or its pane ID. Capture `HERDR_SOCKET_PATH` and `HERDR_PANE_ID` from the Claude process environment with each hook. This installation also exports `HERDR_BIN_PATH`, `HERDR_WORKSPACE_ID`, and `HERDR_TAB_ID`. Do not rely on whichever session happens to be focused.

The [local Herdr skill](/Users/oronb/.agents/skills/herdr/SKILL.md) says pane IDs are stable until closed or moved across workspaces. Cross-workspace moves change the public pane ID; inherited caller context can still resolve the old ID, but arbitrary external targeting cannot assume that behavior. A live agent name can follow the occupant, though it disappears on exit/replacement. Refresh mapping and validate that the destination still hosts the intended Claude session before focusing.

The CLI establishes internal pane focusing, not native macOS app activation. Herdr can run under a terminal host; bringing that host forward is a separate requirement. Persistent/detached clients, remote sessions, and pane moves need a prototype before promising exact click-to-session support. No local Herdr source checkout was located in the searched Developer folders.

Evidence: `herdr --help`, `herdr agent`, `herdr pane`, and `herdr api schema --json` (protocol 22). The environment check returned `HERDR_ENV=1`; all commands were read-only.

## Ghostty

Ghostty's AppleScript API supports individual terminals inside windows/tabs, stable terminal IDs, and `focus`, which brings the owning window forward. App-to-app Automation permission applies. AppleScript arrived in 1.3 and was marked preview, so capability detection is preferable to assuming identical APIs across versions. [Official API guide](https://ghostty.org/docs/features/applescript), [1.3 release notes](https://ghostty.org/docs/install/release-notes/1-3-0).

The installed `/Applications/Ghostty.app/Contents/Resources/Ghostty.sdef` exposes terminal `id`, `pid`, and `tty`, and a `focus` command. Its bundle version is `4dcb09ada`, not a normal release number. PID/TTY support was added upstream in [PR 11922](https://github.com/ghostty-org/ghostty/pull/11922); [current dictionary source](https://github.com/ghostty-org/ghostty/blob/main/macos/Ghostty.sdef) is the reference.

Proposed implementation: map the Claude process's terminal TTY to Ghostty's terminal TTY once, cache the stable terminal ID, then focus that ID on click. A Claude hook has no controlling terminal, so plain `tty` inside the hook is insufficient: recover the Claude ancestor's TTY or capture it in a launch wrapper. Do not match by directory/title alone when multiple sessions share a project. Herdr creates inner PTYs, so their TTYs will not directly match Ghostty's outer terminal; its host client needs a separate mapping. These mappings have not been exercised end-to-end.

No shipped `GHOSTTY_SURFACE_ID` environment contract was verified. Do not implement a proposed URL scheme from a discussion as if it were a supported API.

## Generic fallback and recommendation

[NSRunningApplication](https://developer.apple.com/documentation/appkit/nsrunningapplication) can attempt to activate an identified running terminal application; app activation does not identify its tab or split.

Keep the cute avatar UI. Store the originating session and a focus capability internally. Try an exact verified target; if unavailable, bring its known host app forward. Do not silently choose a different session by matching a shared working directory. Treat Herdr internal focus and native host activation as separate operations, and prototype both before committing to exact navigation for every host. No session dashboard is required by this design.
