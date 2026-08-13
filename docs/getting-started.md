# Getting started

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workspaces/main/scripts/install.sh | sh
```

The verified installer links `workspaces` and its `ws` alias into
`~/.local/bin`.

## Set up the collection

Workspaces uses `~/workspaces` by default:

```bash
ws setup
ws clone owner/pi
cd ~/workspaces/repos/pi
git status --short --branch
```

The result is a normal Git checkout, usually on the remote's default branch.
Repositories live in `repos/`; isolated task checkouts live in `worktrees/`.
A checkout created directly with `git clone` is also discovered when placed in
`repos/<repo>`; Workspaces does not maintain a repository index. Use another
collection root with `ws setup --root ~/code`. Setup is safe to run
again after an upgrade. If it finds pre-4.0 base checkouts directly beneath the
root, it moves them into `repos/` and repairs live task worktrees. It preserves
dirty files and custom collection README content.

## Start a task

Before an automated coding session edits files, create a task worktree and enter
the exact path printed by the command:

```bash
cd ~/workspaces/repos/pi
cd "$(ws new)"
git status --short --branch
```

With no arguments, `new` discovers the base repository containing the current
directory. You can still run `ws new pi` from elsewhere. Without a task
argument, Workspaces chooses an unused world capital for both
the folder and branch. A result might be:

```text
~/workspaces/worktrees/pi/reykjavik
```

Use `ws new pi fix-auth` when you want an explicit name. A new task branch
starts at the current `HEAD` of the base repository checkout. For a repository
without commits, it starts as an unborn branch so the first commit can be made
in the task worktree. If an explicitly named inactive branch already exists,
`new` reattaches it. There is no implicit fetch, pull, reset, or branch deletion.

Do not create task folders manually. Two processes editing a base checkout still
share files; each editing task needs its own returned worktree path.

## Finish a task

```bash
ws remove pi/reykjavik
```

Removal deletes the task checkout but retains its branch. It refuses dirty work;
`--force` explicitly discards uncommitted changes. If a task directory is
manually deleted, `ws list` omits it and `ws doctor` reports Git's stale
worktree metadata. Run ordinary `git worktree prune` from the base checkout to
remove that record. Delete or merge branches with
ordinary Git when that is what you intend.

`workspaces` can replace `ws` in every example.
