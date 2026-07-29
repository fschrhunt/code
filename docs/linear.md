# Linear and GitHub workflow

Workframe uses Linear Engineering issues (`DEV-*`) and GitHub pull requests as
the public work contract.

- Workspace: [intuitum](https://linear.app/intuitum)
- Team: Engineering
- Project: [Workframe](https://linear.app/intuitum/project/workframe-03565bb5855d)
- Repository: [fschrhunt/workframe](https://github.com/fschrhunt/workframe)

## Before implementation

Every material change needs an issue in Todo or In Progress with:

- A clear Why
- Testable Acceptance criteria
- Fischer as assignee
- The implementing agent recorded as delegate when available
- Workframe project and labels

Agents do not silently become owners.

## Branches and pull requests

Normal branches include the `DEV-*` identifier and follow the configured agent
prefix. A PR body must contain one of:

```text
Fixes DEV-123
Contributes to DEV-123
```

Use `Fixes` when the PR completes acceptance. Use `Contributes to` for an
explicit partial slice.

## Status meaning

| Status | Agent action |
|---|---|
| Triage | Do not start |
| Backlog | Do not start |
| Todo | May start when assigned/delegated |
| In Progress | Active implementation |
| Done | Acceptance completed and merged |

## Review contract

1. Run `make check` locally.
2. Open a focused PR against `main`.
3. Let CI rerun ShellCheck and Bats on macOS and Linux.
4. Address substantive review feedback.
5. Do not merge or deploy unless explicitly authorized.

Durable follow-up work taking more than a small review fix belongs in a new
Linear issue with enough context to execute later.

## Active release

[DEV-275](https://linear.app/intuitum/issue/DEV-275) tracks the Workframe 1.5.0
clean-cut product launch and documentation rebuild.

Repository-specific agent rules remain in [`AGENTS.md`](../AGENTS.md).
