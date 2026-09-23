---
status: superseded by ADR-0002
---

# Observe Claude Code through hooks

Shepherd observes Claude Code through hooks so the companion works independently of the user's terminal, including their Ghostty and Herdr workflow. This avoids coupling activity detection to terminal-specific interfaces or screen content. Approval requests and structured questions can produce a needs-you state; ordinary conversational questions are treated as finished responses in the first version, accepting limited question detection in exchange for a terminal-independent integration.
