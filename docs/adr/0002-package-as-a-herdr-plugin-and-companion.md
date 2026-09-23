# Package Shepherd as a Herdr plugin and macOS companion

Shepherd v1 is a Herdr plugin paired with a small native floating macOS app, since Herdr's plugin API does not provide native non-terminal UI. Reusing Herdr's agent states and pane targeting reduces integration work and fits the owner's workflow while preserving a minimal avatar experience. This supersedes direct Claude Code hook integration: sessions outside Herdr are out of scope for v1, and detection reliability depends on Herdr's classifications, including its screen-based Claude Code detection.

Keep character animation independent of the Herdr adapter so a standalone integration can be added later. The companion manages its own lifecycle because plugin startup hooks are one-shot commands rather than supervised daemons.
