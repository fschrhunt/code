# Concepts

## Base checkout first

A collection keeps repository checkouts and task worktrees in separate folders:

```text
<root>/repos/pi/
<root>/worktrees/pi/fix-auth/
<root>/worktrees/pi/update-docs/
```

`repos/pi/` is a normal checkout, usually kept on its default branch. It can be
created by `ws clone` or ordinary `git clone`; Workspaces discovers base
checkouts from `repos/` rather than maintaining an index. It is the place to
select the repository and create tasks. Automated editing belongs in a task
worktree, not in this base checkout.

## Task workflow

A second terminal or agent session does not isolate files. Before editing, run:

```bash
cd <root>/repos/pi
path=$(ws new)
cd "$path"
```

With no arguments, `new` discovers the base checkout containing the current
directory. Without a task name, `new` chooses an unused world capital for both the
folder and branch, then prints the authoritative path. An explicit
`ws new pi fix-auth` creates `worktrees/pi/fix-auth`; existing inactive branches
can be reattached. If an explicitly named task folder is occupied, a numeric
suffix keeps the checkout distinct.

Do not create task folders with ordinary filesystem commands or place them in
`repos/`. The separate hierarchies keep the collection readable and make the
repository/task relationship explicit.

## Worktree ownership

Workspaces places a marker in the linked worktree's private Git administrative
directory. Lifecycle commands require all of the following:

- the checkout is recorded by its repository as a Git worktree;
- it lives at `worktrees/<repo>/<task-folder>`;
- its private ownership marker exists.

A path pattern or branch name alone is never treated as ownership. Manually
created and third-party worktrees are neither listed nor removed. If a managed
task folder is manually deleted, it is no longer listed; `ws doctor` reports
the stale Git record until ordinary `git worktree prune` removes it.
