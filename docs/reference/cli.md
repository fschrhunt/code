# CLI reference

```text
workspaces setup [--root <path>]
workspaces clone <owner/repo | url | path>
workspaces new <repo> <task>
workspaces list
workspaces remove <repo/task | path> [--force]
workspaces root
workspaces doctor
workspaces version
workspaces help
```

## `setup`

Creates the collection and its `README.md`. `--root` remembers a custom absolute
path. Existing README content is never replaced. Setup is optional for the
default `~/workspaces` root.

## `clone`

Creates a normal checkout directly at `<root>/<repo>`. It accepts a GitHub
`owner/repo`, Git URL, or local path. Clone progress is written to stderr and the
resulting path to stdout.

## `new`

Creates `<root>/<repo>-<task>` from the repository checkout's current `HEAD`.
If that sibling name is occupied, a numeric suffix keeps the new path distinct.
If the local branch exists and is inactive, it is reattached. If it is already
active, `new` returns the existing managed sibling or refuses a checkout outside
the managed layout. Task names are single path-safe components.

## `list`

Shows normal repository checkouts followed by active task worktrees. Dirty
checkouts are labeled. Unmanaged worktrees are omitted.

## `remove`

Removes an exact managed task worktree while retaining its branch. Select by
`repo/branch` or exact path. Dirty work returns status `3`; `--force` explicitly
discards those uncommitted changes.

## `root`

Prints the selected collection root.

## `doctor`

Checks Git availability, repository object integrity, and stale worktree
metadata without changing anything.

## Environment

| Variable | Purpose |
|---|---|
| `WORKSPACES_ROOT` | Override the collection root for one process |
| `XDG_CONFIG_HOME` | Relocate the saved root pointer |
