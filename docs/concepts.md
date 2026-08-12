# Concepts

## Normal checkout first

A collection is a directory containing normal repositories and optional sibling
worktrees:

```text
<root>/pi/
<root>/pi-fix-auth/
<root>/pi-update-docs/
```

`pi/` is not a cache or protected canonical clone. It is the repository checkout
where a person would normally work. A task worktree shares its Git objects and
history while keeping a separate index and working files.

## Parallel isolation

Separate terminal sessions are not separate filesystems. Two editors or agents
started in the same checkout see the same uncommitted changes. Parallel editing
is isolated only after each task uses a different worktree.

`workspaces new <repo> <task>` creates `<repo>-<task>` beside the repository and
prints that path. If the name is occupied, it adds a numeric suffix. The task
name is both its initial branch and directory suffix. Branches and paths may
later be renamed with ordinary Git commands while they remain beneath the root.

## Worktree ownership

Workspaces places a small marker in the linked worktree's private Git
administrative directory. The marker follows `git worktree move` and does not
depend on the branch name, so normal branch renames remain safe.

Lifecycle commands require all of the following:

- the checkout is recorded by its repository as a Git worktree;
- it is an immediate sibling beneath the configured root;
- its private ownership marker exists.

A path pattern or branch name alone is never treated as ownership. Manually
created and third-party worktrees are neither listed nor removed.
