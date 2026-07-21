# Linear ↔ GitHub

Workspace: [intuitum](https://linear.app/intuitum) · Team: **Engineering** (`DEV-*`)

| Repo | Linear project |
| --- | --- |
| [argus.core](https://github.com/intuitumxyz/argus.core) | [argus.core](https://linear.app/intuitum/project/arguscore-8c2e62251b42) |
| [solo](https://github.com/intuitumxyz/solo) | [solo](https://linear.app/intuitum/project/solo-2b2495b70d32) |
| [leo](https://github.com/intuitumxyz/leo) | [leo](https://linear.app/intuitum/project/leo-9ea619a6611a) |
| [wt](https://github.com/intuitumxyz/wt) | [wt](https://linear.app/intuitum/project/wt-03565bb5855d) |
| [websites](https://github.com/intuitumxyz/websites) | [websites](https://linear.app/intuitum/project/websites-7ebcc8146737) |

## Linking PRs to issues

1. Prefer Linear first for planned work (create/find `DEV-XXX`).
2. Copy the git branch name from Linear (`⌘⇧.`), or include `DEV-XXX` in the branch.
3. In the PR title or body, use a magic word: `Fixes DEV-123` (closes on merge) or `Contributes to DEV-123` (links without closing).
4. GitHub autolink: typing `DEV-123` in issues/PRs/comments links to Linear.

## Status automation (expected)

| GitHub event | Linear status |
| --- | --- |
| PR opened / draft | In Progress |
| PR ready to merge | keep In Progress (or Ready for merge if configured) |
| PR merged | Done |
| PR closed without merge | no auto-cancel (re-triage manually) |

Renovate / dependency-dashboard PRs: **no Linear issue**.

## Labels (Linear)

- Workspace `Type/` + `Product/`
- Team `Surface/` (one) + `Needs/` for triage
