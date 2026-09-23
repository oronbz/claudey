# Shepherd design

## Agreed direction

- First release targets the owner's Mac, with a small always-on-top desktop companion.
- Distribute v1 as a Herdr plugin plus a small native macOS companion app. Observe agents running inside Herdr; Claude Code in the owner's Ghostty + Herdr workflow is the first validation target. Standalone Claude Code integration is deferred.
- Express working, finished, and needs-you states through the character.
- Include idle animations and playful click reactions, with no pet-care chores or progression.
- Create an original pixel-art creature with a clear face and silhouette that reads at a small desktop size.
- Voice is not required.
- Consume Herdr agent states and lifecycle events. Needs-you reflects Herdr's blocked classification; it is not a guarantee that every question or approval is detected. Herdr currently derives Claude Code status from screen patterns.
- One companion represents all sessions. Needs-you takes priority over working. Individual completions receive a brief reaction.
- Clicking returns to the associated Herdr pane where feasible. Native host activation is separate and needs an end-to-end prototype. No session panel.
- Click targets the session behind the current reaction: a session needing input first, the just-finished session during its celebration, otherwise the most recently active session. No session picker.
- Keep the experience focused on a cute avatar, with minimal UI. Do not add stale-session management controls or a power-user dashboard. Recovery should happen quietly.
- Interrupted, disappeared, or uncertain sessions quietly return Shepherd to rest through automatic recovery. No warning, badge, or cleanup UI; reserve the questioning pose for confirmed requests for input.
- Shepherd is draggable, remembers his position, follows desktop spaces, and stays out of full-screen apps. Movement remains local to his position.
- Silent by default. Needs-you triggers a brief wave followed by a persistent questioning pose; completion triggers a brief celebration. Never steal keyboard focus.
- Character: a tiny warm orange fluffy creature with stubby feet, expressive dark eyes, and one distinctive tuft.
- Animations: idle breathing/blinking, working concentration, completion hop, questioning wave, uncertain/resting pose, and happy hover reaction.
- No sound or voice in the first version.
- The Herdr plugin starts or connects to the companion and supplies connection context, replacing direct Claude Code hook setup. Do not alter the user's Claude hooks. Provide disconnect; menu-bar controls offer hide/show and quit. Launch at login is available, initially off.

## Implementation plan for final review

- Use Swift and AppKit for the floating macOS companion; bundle the Herdr manifest and minimal launcher alongside it. Local installation first, with public distribution deferred.
- Read an initial Herdr snapshot, subscribe to status and pane lifecycle events, and reconnect quietly. The app owns its lifecycle; plugin startup hooks are not daemon supervisors.
- Keep animation and interaction independent of the Herdr adapter.
- Prototype Herdr pane focus plus Ghostty host activation before treating click-to-session as verified. Proposed fallback: activate a known host if exact targeting fails; otherwise react playfully without extra UI.
- Generate the agreed orange pixel-art character and sprite poses using imagegen, then integrate assets into the workspace.
- Verify state priority with simultaneous sessions, quiet disconnect/reconnect, focus targeting, dragging, spaces, full-screen exclusion, and non-activating presentation.

Implementation has not begun. Herdr-first scope is accepted; the consolidated design and implementation defaults await the final shared-understanding check.
