# Concepts

## Normal checkout first

A collection keeps repository checkouts at the top level and task worktrees in a
reserved folder:

```text
<root>/pi/
<root>/worktrees/pi/fix-auth/
<root>/worktrees/pi/update-docs/
```

`pi/` is a normal checkout, usually kept on its default branch. It is the place
to select the repository and create tasks. Automated editing belongs in a task
worktree, not in this base checkout.

## Task workflow

A second terminal or agent session does not isolate files. Before editing, run:

```bash
cd <root>/pi
path=$(workspaces new pi fix-auth)
cd "$path"
```

`new` creates `worktrees/pi/fix-auth`, checks out branch `fix-auth`, and prints
the authoritative path. Existing inactive branches can be reattached. If a task
folder is occupied, a numeric suffix keeps the checkout distinct.

Do not create task folders with ordinary filesystem commands or place them at
the collection root. The reserved hierarchy keeps the root readable and makes
the repository/task relationship explicit.

## Worktree ownership

Workspaces places a marker in the linked worktree's private Git administrative
directory. Lifecycle commands require all of the following:

- the checkout is recorded by its repository as a Git worktree;
- it lives at `worktrees/<repo>/<task-folder>`;
- its private ownership marker exists.

A path pattern or branch name alone is never treated as ownership. Manually
created and third-party worktrees are neither listed nor removed.
