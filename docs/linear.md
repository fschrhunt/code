# Linear ↔ GitHub

Workspace: [intuitum](https://linear.app/intuitum) · Team: **Engineering** (`DEV-*`)

| Repo | Linear project |
| --- | --- |
| [argus.core](https://github.com/intuitumxyz/argus.core) | [argus.core](https://linear.app/intuitum/project/arguscore-8c2e62251b42) |
| [solo](https://github.com/intuitumxyz/solo) | [solo](https://linear.app/intuitum/project/solo-2b2495b70d32) |
| [leo](https://github.com/intuitumxyz/leo) | [leo](https://linear.app/intuitum/project/leo-9ea619a6611a) |
| [wt](https://github.com/intuitumxyz/wt) | [wt](https://linear.app/intuitum/project/wt-03565bb5855d) |
| [websites](https://github.com/intuitumxyz/websites) | [websites](https://linear.app/intuitum/project/websites-7ebcc8146737) |

Process source of truth (Engineering team docs):

- [Agent Contract](https://linear.app/intuitum/document/agent-contract-5cca5188b456)
- [Triage Ritual](https://linear.app/intuitum/document/triage-ritual-806f09954c6c)
- [Week-1 Focus](https://linear.app/intuitum/document/week-1-focus-3083713a8662)

Also mirrored for coding agents in [../AGENTS.md](../AGENTS.md) (`## Linear + multi-agent loop`).

## Agent contract (wt)

1. **No real implementation without a `DEV-*`** — except tiny drive-bys and Renovate.
2. **Fischer stays assignee.** Cursor / Claude / Codex / Leo / Devin are **delegates**, never silent owners.
3. **Why + Acceptance required** before coding. If missing, stop and clarify (Needs/Clarification) — do not invent scope.
4. **One agent per issue** unless Fischer creates sub-issues. Use `wt` when paralleling on the same repo.
5. **Branch from Linear** (`⌘⇧.` or include `DEV-XXX` in the branch name).
6. **PR body** must include `Fixes DEV-XXX` (closes on merge) or `Contributes to DEV-XXX` (links without closing).
7. **Greptile** reviews the PR. Do not open Linear issues for review nits unless the follow-up is durable (>~30 min).

### Status meanings for agents

| Status | Meaning |
| --- | --- |
| Triage | Human inbox — **do not start** |
| Backlog | Scoped later — **do not start** |
| Todo | Ready this cycle — pick up OK |
| In Progress | Active; link the PR |
| Done | Merged / shipped |

### wt milestones (project [wt](https://linear.app/intuitum/project/wt-03565bb5855d))

| Milestone | Issue | Notes |
| --- | --- | --- |
| M0 foundation | shipped | Shared/SSH + in-repo CLI |
| M1 profiles | [DEV-175](https://linear.app/intuitum/issue/DEV-175) | Configurable profiles |
| M2 local `~/.wt` | [DEV-181](https://linear.app/intuitum/issue/DEV-181) | Local as documented default |

## Linking PRs to issues

1. Prefer Linear first for planned work (create/find `DEV-XXX`).
2. Copy the git branch name from Linear (`⌘⇧.`), or include `DEV-XXX` in the branch.
3. In the PR title or body, use a magic word: `Fixes DEV-123` or `Contributes to DEV-123`.
4. GitHub autolink: typing `DEV-123` in issues/PRs/comments links to Linear.
5. Tiny drive-by / docs-only / Renovate: omit Linear only when the contract allows; say so in the PR.

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
