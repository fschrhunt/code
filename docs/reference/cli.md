# CLI reference

```text
workframe setup [--root <path>] [--org <name>]
workframe clone <owner/repo | url | path>
workframe new <repo> <task>
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

All commands are non-interactive and write their result to stdout. Human list
output is one workspace per line; use `--json` or `worktrees` for scripts.

A selector is an exact workspace path, a branch name when unique, or
`repo/task`. City folder names are not selectors.

Workframe only acts on branches it owns. Ownership is recorded in private Git
refs when a task is created or migrated; unmarked worktrees, including
Conductor workspaces, are not listed or changed.
