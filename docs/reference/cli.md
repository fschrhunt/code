# CLI reference

```text
workframe setup [--root <path>] [--org <name>]
workframe clone <owner/repo | url | path>
workframe new [--offline] <repo> <task>
workframe list [archived] [--repo <name>] [--dirty] [--json]
workframe repos
workframe worktrees [--json]
workframe path <repo/task | branch | path>
workframe current
workframe run <selector> -- <command> [args...]
workframe archive <selector> --yes [--force]
workframe restore <repo> <task>
workframe remove branch <repo> <task> --yes
workframe migrate [--yes]
workframe status
workframe doctor
```

All commands are non-interactive and write their result to stdout. `new` fetches
and prunes `origin` before creating a task from its current default-branch tip;
it refuses to create a potentially stale workspace if that refresh fails. Use
`--offline` only for intentional disconnected work from the cached remote ref.
`new` writes only its new workspace path, so use
`cd "$(workframe new <repo> <task>)"` to enter it. Human list output is one
workspace per line; use `--json` or `worktrees` for scripts.

A selector is an exact workspace path, a branch name when unique, or
`repo/task`. City folder names are not selectors.

Workframe only acts on branches it owns. Ownership is recorded in private Git
refs when a task is created or migrated; unmarked worktrees, including
Conductor workspaces, are not listed or changed.
