# CLI reference

```text
workspaces setup [--root <path>] [--yes]
workspaces clone <owner/repo | url | path>
workspaces new [<repo> [task]]
workspaces list
workspaces remove <repo/task | path> [--force]
workspaces root
workspaces doctor
workspaces version
workspaces help
```

The `workspaces` executable is the only installed command.

## `setup`

In a terminal, opens a short wizard to choose the collection root and confirm a
preview of `README.md`, `repos/`, and `worktrees/`. Prompts use stderr, so stdout
remains the resolved root path. `--root` supplies and remembers the path;
`-y`/`--yes` accepts defaults and skips every prompt. Non-terminal use remains
noninteractive.

When pre-4.0 repositories exist directly beneath the root, setup preflights all
destinations, moves each base checkout into `repos/`, and repairs its live
linked worktrees. Dirty files and branches are preserved. A repair failure rolls
completed moves back. Generated collection guides are refreshed; custom README
content is never replaced.

## `clone`

Creates a normal checkout at `<root>/repos/<repo>`. It accepts a GitHub
`owner/repo`, Git URL, or local path. Clone progress is written to stderr and the
resulting path to stdout.

## `new`

Creates a task worktree from the repository checkout's current `HEAD`. With no
arguments, it discovers the base checkout containing the current directory;
that checkout must be directly beneath `<root>/repos/`. This includes normal
checkouts placed there with ordinary `git clone`; no repository index is used.

If a freshly cloned repository has no commits, `new` creates an unborn task
branch so the first commit can be made in the task worktree. Without a task
argument, it chooses an unused lowercase world capital for both the folder and
branch. Multiword capitals use hyphens, such as `buenos-aires`.

With an explicit task, it creates `<root>/worktrees/<repo>/<task>`. If that task
folder is occupied, a numeric suffix keeps the new path distinct. If the local
branch exists and is inactive, it is reattached. If it is already active, `new`
returns the existing managed task path or refuses a checkout outside
`worktrees/<repo>/`. Explicit task names are single path-safe components.

## `list`

Shows normal repository checkouts followed by active task worktrees. Dirty
checkouts are labeled. Unmanaged worktrees and task paths that no longer exist
are omitted. `doctor` reports any stale Git metadata left by manual deletion.

## `remove`

Removes an exact managed task worktree while retaining its branch. Select by
`repo/branch` or exact path. Dirty work returns status `3`; `--force` explicitly
discards those uncommitted changes.

## `root`

Prints the selected collection root.

## `doctor`

Checks Git availability, repository object integrity, stale worktree metadata,
and legacy root-level repositories without changing anything. Legacy layouts
are directed to `workspaces setup`.

## Environment

| Variable | Purpose |
|---|---|
| `WORKSPACES_ROOT` | Override the collection root for one process |
| `XDG_CONFIG_HOME` | Relocate the saved root pointer |
