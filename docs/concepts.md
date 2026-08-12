# Concepts

A Workframe store has one canonical clone per repository and any number of
owned task worktrees:

```text
repos/<repo>/
workspaces/<repo>/<city>/
```

The generated city is only a collision-free directory name. A workspace's
identity is `repo/task`, where `task` is its Git branch.

## Ownership and Conductor boundary

Conductor creates standard Git worktrees too. Its documented local layout is
usually `~/conductor/workspaces/<repo>/<workspace>`, while its chats, reviews,
and archive state are associated with the workspace outside Git. A generic Git
worktree has no universal, stable marker saying who created it.

Workframe does not inspect Conductor's private application state or guess from
paths, branch names, `.conductor` settings, or checkpoint refs. Instead it
writes `refs/workframe/managed/<task>` in the canonical repository whenever it
creates or migrates a task. Lifecycle commands require that positive ownership
record. Unmarked worktrees—including Conductor and manually created Git
worktrees—are ignored and cannot be changed by Workframe.

This is intentionally asymmetric: Workframe can prove its own ownership, but
does not claim to identify somebody else's workspace.
