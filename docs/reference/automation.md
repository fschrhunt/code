# Automation and coding agents

Workframe is a Git-only command-line control plane. Use `workframe help` for
the command map and set `WORKFRAME_COLOR=0` or `NO_COLOR=1` for plain output.

## Store and workspace commands

```bash
workframe init [--root <path>] [--editor <cmd>] [--org <name>]
workframe setup --local --root <path> [--editor <cmd>] [--org <name>]
workframe clone <owner/repo | url | path>
workframe new <repo> <task>
workframe worktrees                 # TSV: repo, city, path, branch
workframe list [archived] [--repo <name>] [--dirty] [--json]
workframe path <selector>
workframe run <selector> -- <command> [args...]
```

Workspaces live at `workspaces/<repo>/<city>` and task branches use the task
name directly. A selector is a city, `repo/task`, branch, or absolute path.

## Lifecycle and legacy migration

```bash
workframe archive <selector> --yes [--force]
workframe restore <repo> <branch>
workframe remove branch <repo> <branch> --yes
workframe migrate [--yes]
```

`migrate` converts pre-cutover `workspaces/<agent>/<repo>/<city>` worktrees
and configured agent-prefixed branches. It is a dry run without `--yes`, never
pushes or changes remotes, journals successful local operations, and rolls them
back if a later local operation fails.

Workframe never reads or writes Conductor state. Do not run Workframe lifecycle
commands against a workspace managed by Conductor.

## Environment

| Variable | Purpose |
|---|---|
| `WORKFRAME_HOME` | Override the data root and config directory, process-scoped |
| `WORKFRAME_COLOR` | `0` forces plain output, `1` forces color |

`WORKFRAME_HOME` does not write a root locator, so it is safe for tests and
throwaway stores.
