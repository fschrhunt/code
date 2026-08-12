# Core concepts

A Workframe store has one canonical Git clone per repository and one isolated
worktree per task:

```text
<store>/
├── repos/<repo>/
└── workspaces/<repo>/<city>/
```

The workspace branch is the task name, such as `fix-login`. Cities are only
unique directory labels; they do not affect the branch or pull request.

`repos/<repo>` is the Git canonical and should not hold task edits. Create work
with `workframe new <repo> <task>`, then edit only the printed workspace.

Workframe mirrors Conductor’s on-disk Git layout but is independent of
Conductor’s workspace/session state. Use one lifecycle owner for a workspace.
