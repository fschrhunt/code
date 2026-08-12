# Automation and coding agents

Workframe's automation interface is non-interactive and based on positive
ownership records. It does not inspect Conductor's private state or infer
ownership from a worktree path, so unmarked worktrees are never listed or
changed. See [Concepts](../concepts.md#ownership-and-conductor-boundary) for
that boundary.

## Create and work normally

Workframe creates and finds task directories; it does not replace Git or the
GitHub CLI. Use the ordinary commands agents and humans already know once the
new workspace is entered:

```bash
cd "$(workframe new repo task)"
git status --short --branch
git add <paths>
git commit -m "type: summary"
gh pr create
```

`new` prints only its workspace path, making it safe for command substitution.
A command cannot change its parent shell's directory.

## Discover and run work

Use machine-readable commands instead of formatted `list` output when working
from outside a task workspace:

```bash
workframe repos                         # one canonical repo per line
workframe worktrees                     # TSV: repo, city, path, task
workframe worktrees --json
workframe list --json
workframe path repo/task                # exactly one path
workframe run repo/task -- make check
```

Create a workspace only after selecting a canonical repository:

```bash
workframe clone owner/repo
workframe new repo task
```

## Lifecycle

```bash
workframe archive repo/task --yes
workframe restore repo task
workframe remove branch repo task --yes
```

`migrate` converts pre-2.0 agent-scoped stores. It is a dry run without
`--yes`, does not contact remotes, and rolls local Git changes back if a later
operation fails.

## Environment

| Variable | Purpose |
|---|---|
| `WORKFRAME_HOME` | Process-scoped store-root override |
| `WORKFRAME_COLOR=0` | Disable color (`NO_COLOR=1` also disables it) |

Supply every required argument in a non-interactive session. Exit status `3`
means Workframe refused a potentially destructive action and left work intact.
