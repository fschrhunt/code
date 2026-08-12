# Workframe contributor guide

Workframe is a small local Git-worktree CLI. Its product boundary is narrow:
create an owned task workspace, find it, archive it, and restore it. `workframe
setup` is the one interactive setup wizard; automation supplies `--root`. Do not add
remote-store, SSH, mount, editor, shell-hook, dashboard, or package-management
features.

## Safety contract

- Work only in an isolated Git worktree, never a live installed command.
- Workframe owns only branches recorded in `refs/workframe/managed/*`.
  Layout, names, and Conductor metadata are not ownership proof.
- Never make lifecycle commands act on unmarked worktrees or branches.
- Do not inspect or modify Conductor's private application state.
- Keep all destructive behavior explicit and covered by a focused Bats test.

## Validate

```bash
make check
bin/workframe help
```

Tests must be hermetic: use `WORKFRAME_BACKEND=1` and `WORKFRAME_HOME=<tmp>`
with helpers from `test/helper.bash`. They must not require a network, remote
store, mount, or terminal.

## Layout

```text
bin/workframe       command dispatch
lib/config.sh       local-root configuration
lib/backend.sh      Git operations and ownership records
lib/frontend.sh     public local CLI formatting and resolution
lib/WORKFRAME.md    installed-store agent contract
test/               Bats tests
```

When changing a command, update the help golden fixture and the matching docs.
