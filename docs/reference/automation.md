# Automation and coding agents

Workframe is safe for agents because its interface is non-interactive and it
uses positive ownership records. Set `WORKFRAME_COLOR=0` or `NO_COLOR=1` if a
caller needs plain diagnostic output.

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

Lifecycle is explicit:

```bash
workframe archive repo/task --yes
workframe restore repo task
workframe remove branch repo task --yes
```

`migrate` converts pre-2.0 agent-scoped stores. It is a dry run without
`--yes`, does not contact remotes, and rolls local Git changes back if a later
operation fails.

Workframe marks its branches in `refs/workframe/managed/*`. It does not read
Conductor's private application state and never infers ownership from a
worktree path. Therefore unmarked worktrees—including Conductor worktrees—are
not listed or changed.

## Environment

| Variable | Purpose |
|---|---|
| `WORKFRAME_HOME` | Process-scoped store root override |
| `WORKFRAME_COLOR` | `0` disables color; `1` forces it |
