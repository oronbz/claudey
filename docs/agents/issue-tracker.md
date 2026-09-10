# Issue tracker: GitHub

Issues and specs live in GitHub Issues for `oronbz/claudey`. Use `gh` with `--repo oronbz/claudey` or infer the repository from the origin remote.

- Publishing means creating a GitHub issue. Pass multiline content through `--body-file`.
- Read tickets with `gh issue view <number> --comments` and fetch their labels.
- List issues with `gh issue list`, using state and label filters as appropriate.
- Apply or remove triage labels with `gh issue edit` using the vocabulary in `triage-labels.md`.
- Append discussion as issue comments; close resolved issues through the tracker.

PRs as a request surface: no.

GitHub issues are the canonical feature specs; local design and research documents provide supporting context.
