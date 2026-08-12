# WORKFRAME.md — guide to this Workframe store

This directory is a Workframe store: a safe place to keep one canonical clone
of each repository and a separate Git worktree for each task. Read this guide
before creating, changing, or cleaning up work here.

## The short version

1. Find or create a **task workspace**, not a clone in `repos/`.
2. Do the work only in that workspace and follow its repository instructions.
3. Inspect before acting; use reversible lifecycle commands by default.
4. Commit, validate, and clearly report what remains when handing work off.

Run `workframe help` for the complete command map. `wf` is the same command
when it is installed.

## Know where you are

```text
<store>/
├── WORKFRAME.md                 this guide
├── repos/<repo>/                canonical clones — do not develop here
├── workspaces/<repo>/<city>/    active task worktrees
└── system/                      configuration and operational state
```

Some older stores use `workspaces/<agent>/<repo>/<city>/`. Run
`workframe migrate` for a dry-run conversion, then `workframe migrate --yes`
only after it reports no conflicts.

Before editing, confirm the directory and branch:

```bash
pwd
git branch --show-current
workframe current                 # when already inside a Workframe workspace
```

Only edit an active worktree under `workspaces/`. `repos/` holds the canonical
clone from which worktrees are made. Do not implement task work in `repos/`.
`system/` can contain private configuration and operational state, so do not
put project work there or disclose its contents.

Repository-local instructions such as `AGENTS.md`, `CONTRIBUTING.md`, and test
documentation still apply. Read them before changing code. They are more
specific than this store-level guide.

## Start or find a task workspace

Use these commands to see what already exists:

```bash
workframe list                    # readable summary of active work
workframe list --dirty            # active work with uncommitted changes
workframe list archived           # branches that can be restored
workframe repos                   # canonical repository names
workframe path <selector>         # print one active workspace path
```

A selector may be a city name, `repo/task`, a branch name, or the full
workspace path. Workframe refuses an ambiguous selector instead of guessing.

When the task calls for a new workspace, create one from a repository already
in the store:

```bash
workframe clone <owner/repo | url | path>   # only when the repo is absent
workframe new <repo> <task>
```

`new` creates a task branch and an isolated worktree, then prints its path.
Use that printed path (or `workframe path <selector>`) to enter the workspace.
Do not use `workframe cd` in automation: optional shell integration can make it
change the caller's directory instead of printing a path.

```bash
workspace=$(workframe path <selector>)
cd "$workspace"
```

If the branch already exists but has no active workspace, restore it instead of
creating another branch:

```bash
workframe restore <repo> <branch>
```

Do not initialize, reconfigure, or switch a store simply to complete a coding
task. Commands such as `workframe init`, `setup`, and `config` change the
operator's environment and need an explicit request.

## Work only in the current worktree

Inside the assigned workspace:

- Keep changes limited to the assigned task and preserve pre-existing changes.
- Do not inspect, edit, or use sibling workspaces to finish the task unless the
  task explicitly requires it.
- Do not move, replace, or delete the worktree's `.git` file.
- Run the repository's documented formatter, build, tests, and review checks.
- Commit only when that is within the task's requested workflow; do not assume
  permission to push, open a pull request, or change another branch.

## Validate and hand off

At handoff, report the workspace path, branch, validation performed, and any
uncommitted or unpushed changes. If work is paused rather than finished,
archive it only when appropriate:

```bash
workframe archive <selector> --yes
```

Archive removes the worktree folder but keeps the branch, so it can be resumed
with `workframe restore <repo> <branch>`. It refuses dirty work unless
`--force` is given. `--force` discards uncommitted changes; use it only with
explicit authorization to lose those changes.

## Use the CLI safely in scripts and agents

For stable, machine-readable discovery, prefer:

```bash
workframe worktrees               # TSV: repo, city, path, branch
workframe repos                   # one repository name per line
workframe path <selector>         # one resolved workspace path
workframe run <selector> -- <command> [args...]
```

`workframe list` is intentionally formatted for people. Set `WORKFRAME_COLOR=0`
or `NO_COLOR=1` when plain output is needed. In a non-interactive session,
supply every required argument rather than expecting a prompt.

An exit status of `3` means Workframe refused a potentially destructive action
and left the work intact—for example, a dirty workspace during archive. Inspect
the state, commit or preserve the work, and ask before discarding anything.

## Lifecycle boundaries

These operations have different consequences:

| Goal | Command | What happens |
|---|---|---|
| Inspect active work | `workframe list` | No changes |
| Pause work | `workframe archive <selector> --yes` | Removes folder, keeps branch |
| Resume work | `workframe restore <repo> <branch>` | Recreates a worktree |
| Remove an archived branch | `workframe remove branch <repo> <branch> --yes` | Permanently deletes branch |
| Remove a repository | `workframe remove repo <repo> --yes` | Permanently deletes canonical clone when safe |
| Clear safe stale state | `workframe clean` | Dry run unless `--yes` is supplied |

Never run `workframe archive --force`, `workframe clean --yes`, `workframe
remove`, or recursive deletion commands unless the task explicitly authorizes
that exact destructive action. Do not delete a store, canonical repository, or
workspace path with a raw recursive-delete command.

When in doubt, stop after inspection and ask the task owner which workspace or
lifecycle action they intend.

## Conductor boundary

Workframe intentionally operates only on Git. It never reads or updates
Conductor’s local database, sessions, or archive state. Do not use Workframe
lifecycle commands on a workspace created or managed by Conductor.
