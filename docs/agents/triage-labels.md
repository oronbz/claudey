# Triage labels

Canonical roles map directly to these GitHub labels, which already exist on `oronbz/shepherd`:

| Role              | GitHub label      | Meaning                            |
| ----------------- | ----------------- | ---------------------------------- |
| `needs-triage`    | `needs-triage`    | Awaiting evaluation                |
| `needs-info`      | `needs-info`      | Awaiting additional information    |
| `ready-for-agent` | `ready-for-agent` | Specified for agent implementation |
| `ready-for-human` | `ready-for-human` | Requires human implementation      |
| `wontfix`         | `wontfix`         | Will not be actioned               |

When a skill mentions a role, apply the corresponding label with `gh issue edit <number> --add-label "<label>"`.
