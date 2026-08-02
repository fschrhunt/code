# Automation and coding agents

Workframe's product surface is the [wizard](cli.md). Everything the wizard can
do also has a command form, so scripts and coding agents have the same
capabilities as a person at the keyboard.

The command catalogue ships with the tool:

```bash
workframe help --agent
```

`wf` is a short name for the same executable, so every command on this page
works under either name.

Set `WORKFRAME_COLOR=0` for output without ANSI escapes.

## Set up a store

```bash
workframe setup --local --root <path> --agent <name> [--editor <cmd>] [--org <name>]
workframe agents list
workframe agents add <name>
workframe agents remove <name>
```

`setup` is idempotent. Repeating it against an existing store updates the
selected root and configuration without touching repositories or workspaces,
and never overwrites an existing `WORKFRAME.md`.

At least one agent identity must exist before a workspace can be created. An
agent identity is a branch namespace, not a vendor name.

## Repositories

```bash
workframe clone <owner/repo | url | path>
workframe repos                       # one canonical repo name per line
workframe sync [<repo> | --all]
workframe remove repo <repo> --yes [--force]
```

`clone` accepts `owner/repo` (expanded with the configured default
organization), a full URL, or a local path.

## Workspaces

```bash
workframe new <repo> <feature> --agent <name>
workframe list [archived]
workframe worktrees                   # TSV: agent, repo, city, path, branch
workframe path <selector>             # prints the workspace path
workframe rename <selector> <feature>
workframe open <selector>             # opens the configured editor
```

`new` prints the workspace path, the branch, and the generated city label.
`--agent` is required; `WORKFRAME_AGENT` sets it for a whole session.

`workframe worktrees` is the machine-readable listing — tab-separated, no
header, no color. Prefer it over `workframe list`, which is formatted for
people.

### Use `path`, not `cd`

Workframe offers to install a shell integration that wraps `workframe` in a
function so that `workframe cd <selector>` changes the shell's directory. Where
that hook is installed, `cd` prints nothing and `$(workframe cd …)` is empty.
`wf` is defined in terms of that same function, so `wf cd` behaves the same way.

`workframe path <selector>` is the stable spelling. The shell function passes it
through untouched, so it behaves identically whether or not the hook is present:

```bash
ws=$(workframe path webapp/dark-mode)
cd "$ws"
```

## Lifecycle

```bash
workframe archive <selector> --yes [--force]
workframe restore <repo> <branch>
workframe remove branch <repo> <branch> --yes
workframe clean [--yes]
```

Archive is reversible: it removes the folder and keeps the branch. Restore
recreates the worktree in a fresh city folder. Deleting a branch or a
repository is permanent.

`workframe clean` without `--yes` is a dry run.

## Selectors

A workspace can be named any of these ways:

| Form | Example |
|---|---|
| City label | `loslaureles` |
| Repository and feature | `webapp/dark-mode` |
| Branch | `claude/dark-mode` |
| Agent, repository, and city | `claude/webapp/loslaureles` |
| Absolute path | `/home/you/workframe/workspaces/claude/webapp/loslaureles` |

An ambiguous selector is refused rather than guessed. `workframe worktrees`
supplies every unambiguous form.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `3` | Refused to destroy something — nothing was changed |
| other non-zero | Failure — the reason is on stderr |

Exit `3` is worth handling separately: it means the work is intact and the
command declined to destroy it. It is returned when a worktree has uncommitted
or unpushed work, and when `remove repo` finds worktrees outside the store.
The message on stdout says which.

## Safety rules that automation must respect

- Destructive verbs require `--yes` when no terminal is attached. Without it
  they refuse rather than assume consent.
- `--force` on `archive` discards uncommitted work. `--force` on
  `remove repo` deletes a canonical clone that still has workspaces.
- Workframe only deletes worktrees under `workspaces/`. If a repository has a
  worktree somewhere else, `remove repo` refuses; with `--force` it deletes the
  repository and leaves those files on disk.
- Nothing is deleted implicitly. `archive` keeps the branch; only
  `remove branch` and `remove repo` destroy anything.

## Environment

See the [configuration reference](configuration.md) for the full list.
The variables that matter most to automation:

| Variable | Purpose |
|---|---|
| `WORKFRAME_HOME` | Override the data root and config directory, process-scoped |
| `WORKFRAME_AGENT` | Default agent for `workframe new` |
| `WORKFRAME_COLOR` | `0` forces plain output, `1` forces color |

`WORKFRAME_HOME` does not write a root locator, so it is safe for tests and
throwaway stores.

## The store contract

Every store carries a `WORKFRAME.md` at its root: the safety contract for
coding agents working inside it. It is created on setup and never overwritten.
Tools that begin discovery at the Git root do not find it automatically and
must be pointed at it explicitly.
