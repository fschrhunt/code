# CLI reference

```text
code setup [--root <path>] [--yes]
code clone <owner/repo | url | path>
code new <agent>
code list
code remove <branch | path> [--force]
code root
code doctor
code version
code help
```

The `code` executable is the only installed command.

## `setup`

In a terminal, opens a short wizard to choose the collection root and confirm a
preview of `README.md`, `repos/`, and `worktrees/`. Prompts use stderr, so stdout
remains the resolved root path. `--root` supplies and remembers the path;
`-y`/`--yes` accepts defaults and skips every prompt. Non-terminal use remains
noninteractive.

When repositories exist directly beneath the root, setup preflights all
destinations, moves each base checkout into `repos/`, and repairs its live
linked worktrees. Dirty files and branches are preserved. A repair failure rolls
completed moves back. Generated collection guides are refreshed; custom README
content is never replaced.

## `clone`

Creates a normal checkout at `<root>/repos/<repo>`. It accepts a GitHub
`owner/repo`, Git URL, or local path. Clone progress is written to stderr and the
resulting path to stdout.

## `new`

Takes one argument: the agent name, such as `e`, `pi`, `claude`, or `codex`.
It discovers the base checkout containing the current directory; that checkout
must be directly beneath `<root>/repos/`. This includes normal checkouts
placed there with ordinary `git clone`; no repository index is used.

`new` creates a flat worktree named `<root>/worktrees/<agent>-<repo>` whose
branch matches the folder. An occupied name suffixes `-1`, `-2`, and so on. If
the local branch exists and is inactive, it is reattached, so removing a
worktree and creating it again lands on the same branch. If it is already
active, `new` returns the existing managed path or refuses a checkout outside
`worktrees/`.

If a freshly cloned repository has no commits, `new` creates an unborn branch
so the first commit can be made in the worktree.

## `list`

Shows normal repository checkouts followed by managed worktrees. Dirty
checkouts are labeled. Unmanaged worktrees and paths that no longer exist are
omitted. `doctor` reports any stale Git metadata left by manual deletion.

## `remove`

Removes an exact managed worktree while retaining its branch. Select by
branch name, `repo/branch`, or exact path; an ambiguous branch name must use
`repo/branch` or the path. Dirty work returns status `3`; `--force` explicitly
discards those uncommitted changes.

## `root`

Prints the selected collection root.

## `doctor`

Checks Git availability, repository object integrity, and stale worktree
metadata without changing anything. Legacy layouts are directed to
`code setup`.

## Environment

| Variable | Purpose |
|---|---|
| `CODE_ROOT` | Override the collection root for one process |
| `XDG_CONFIG_HOME` | Relocate the saved root pointer |
