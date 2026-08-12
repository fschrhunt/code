# Workframe store guide

This directory is a Workframe store. It holds canonical Git clones and isolated
task worktrees. Read this guide before creating, changing, or removing work.

## Rules

- Work in a task workspace under `workspaces/`, never in a canonical clone
  under `repos/`.
- Treat `system/` as private operational state. Do not edit or disclose it.
- Read the workspace repository's `AGENTS.md`, `CONTRIBUTING.md`, and test
  documentation before changing code. They take precedence over this guide.
- Preserve existing changes. Do not inspect or change sibling workspaces unless
  the task explicitly requires it.
- Do not reconfigure a store with `workframe setup` unless the operator asks.

```text
<store>/
├── repos/<repo>/                 canonical clone; not a development directory
├── workspaces/<repo>/<city>/     active task worktree
└── system/                       private configuration and operational state
```

A task is identified as `repo/task`; `task` is the Git branch. The generated
city name is a directory label, not an identifier to use in commands.

## Start or resume work

Inspect before creating anything:

```bash
workframe list                    # active task workspaces
workframe list --dirty            # active work with local changes
workframe list archived           # branches available to restore
workframe repos                   # canonical repository names
workframe path <repo/task>        # one active workspace path
```

Create a canonical clone only when the repository is absent, then enter a new
task workspace. From that point, use ordinary `git` and `gh` commands:

```bash
workframe clone <owner/repo | url | path>
cd "$(workframe new <repo> <task>)"  # refreshes origin first
git status --short --branch
gh pr create
```

`new` writes only the workspace path so it composes with `cd`, scripts, Git,
and GitHub CLI without a Workframe-specific wrapper. It cannot change the
parent shell's directory. For intentional disconnected work, use
`workframe new --offline <repo> <task>`; otherwise `new` refuses a stale
default-branch ref when it cannot refresh `origin`.

If the branch already exists without an active workspace, resume it instead:

```bash
workframe restore <repo> <task>
```

Before editing, verify the location and branch:

```bash
pwd
git branch --show-current
workframe current                 # from inside a task workspace
```

## Work and validate

Keep changes limited to the task. Do not move, replace, or delete the
workspace's `.git` file. Run the repository's documented formatter, build, and
tests.

At handoff, report the task identity, branch, validation performed, and any
uncommitted or unpushed changes. Commit, push, open a pull request, or archive
work only when the task's requested workflow permits it.

## Lifecycle is explicit

| Goal | Command | Result |
|---|---|---|
| Pause clean work | `workframe archive <repo/task> --yes` | Removes the folder; keeps the branch |
| Resume work | `workframe restore <repo> <task>` | Creates a new task worktree |
| Delete an archived branch | `workframe remove branch <repo> <task> --yes` | Permanently deletes the branch |

`archive` refuses dirty work unless `--force` is explicit. Never use
`archive --force`, `remove`, or a recursive deletion command without explicit
authorization to discard that exact work. When uncertain, inspect and ask.

## Scripts and agents

Workframe allocates and locates task worktrees; Git and GitHub operations stay
native. Start an agent task with the same command sequence a person uses:

```bash
cd "$(workframe new <repo> <task>)"
git status --short --branch
git add <paths>
git commit -m "type: summary"
gh pr create
```

Use machine-readable Workframe commands only when discovering or addressing
work from outside its workspace:

```bash
workframe worktrees               # TSV: repo, city, path, branch
workframe worktrees --json
workframe list --json
workframe path <repo/task>        # exactly one path
workframe run <repo/task> -- <command> [args...]
```

| Variable | Purpose |
|---|---|
| `WORKFRAME_HOME` | Use this store root for one command or process |
| `WORKFRAME_COLOR=0` | Disable color (`NO_COLOR=1` also disables it) |

In non-interactive sessions, provide every required argument. Exit status `3`
means Workframe refused a potentially destructive action and left work intact.
Inspect the state; do not discard changes without authorization.

## Ownership boundary

Workframe records every task branch it creates or migrates in
`refs/workframe/managed/*`. It acts only on branches with that record.

Conductor and manually created Git worktrees remain unmarked. Workframe does
not inspect Conductor's private state or infer ownership from paths, branch
names, `.conductor` files, or Git worktree records. It cannot list, archive,
restore, or remove unmarked worktrees.

For a pre-2.0 agent-scoped store, run `workframe migrate` to preview the
conversion. Run `workframe migrate --yes` only after it reports no conflicts.
