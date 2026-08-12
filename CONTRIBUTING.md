# Contributing to Workframe

Workframe is a small local Git-worktree CLI. Keep contributions focused on its
core contract: allocate an owned task workspace, find it, archive it, and
restore it safely.

## Development

```bash
make check
bin/workframe help
```

`make check` runs ShellCheck and hermetic Bats tests. Tests use a temporary
local Git origin through `test/helper.bash`; they must not require a network,
terminal, mount, editor, or external service.

## Design constraints

- A task identity is `repo/task`; city labels are directory implementation
  details, not selectors.
- Workframe ownership is explicit in `refs/workframe/managed/*`. Never infer
  ownership from a path, branch pattern, or Conductor configuration.
- Conductor worktrees are unmarked and out of scope. Do not inspect or write
  Conductor's private application state.
- Keep the command surface small. Do not add SSH, shared stores, editor launch,
  shell hooks, dashboards, or self-update behavior.
- Update focused tests, help, and documentation with behavior changes.

Please open a focused PR and preserve unrelated work.
