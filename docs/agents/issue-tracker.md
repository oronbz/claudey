# Issue tracker: Local Markdown

Issues and specs live in local Markdown under `.scratch/`. The public GitHub repository hosts code; its existence does not change the tracker choice.

- Each feature lives in `.scratch/<feature-slug>/`.
- Its canonical spec is `spec.md` within that directory.
- Implementation tickets live in `issues/<NN>-<slug>.md`, numbered from 01, with one ticket per file.
- Record triage state with a `Status:` line near the top. Use the vocabulary in `triage-labels.md`.
- Record ticket dependencies in a `Blocked by:` field using local ticket numbers and titles.
- Append discussion under `## Comments`.

Publishing means creating or updating the corresponding local file. Fetch tickets by their referenced path or feature and ticket number.

Claudey's authoritative spec lives at `.scratch/claudey/spec.md`.
