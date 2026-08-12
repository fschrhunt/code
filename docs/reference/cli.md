# CLI reference

```bash
workframe init [--root <path>] [--editor <cmd>] [--org <name>]
workframe setup [--local|--shared] [--root <path>] [--editor <cmd>] [--org <name>]
workframe clone <owner/repo | url | path>
workframe new <repo> <task>
```

| Intent | Command |
|---|---|
| List active workspaces | `workframe list [--repo <name>] [--dirty] [--json]` |
| List archived branches | `workframe list archived` |
| Machine-readable list | `workframe worktrees [--json]` |
| Open or print a workspace | `workframe open <selector>`, `workframe path <selector>` |
| Rename a task branch | `workframe rename <selector> <task>` |
| Pause or restore work | `workframe archive <selector> --yes`, `workframe restore <repo> <branch>` |
| Migrate a legacy store | `workframe migrate [--yes]` |
| Inspect the store | `workframe status`, `workframe doctor` |

`worktrees` emits `repo`, `city`, `path`, and `branch` as TSV. A selector is a
city, `repo/task`, task branch, or absolute workspace path.

Workframe operates only on Git. It does not synchronize Conductor workspace
records, chats, or archives; do not use its lifecycle commands on a
Conductor-managed workspace.
