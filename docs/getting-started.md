# Getting started

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/code/main/scripts/install.sh | sh
```

The verified installer links `code` into `~/.local/bin`.

## Set up the collection

Code uses `~/Code` by default:

```bash
code setup
# Confirm the collection root and preview.
code clone owner/pi
cd ~/Code/repos/pi
git status --short --branch
```

The result is a normal Git checkout, usually on the remote's default branch.
Repositories live in `repos/`; isolated task checkouts live in `worktrees/`.
A checkout created directly with `git clone` is also discovered when placed in
`repos/<repo>`; Code does not maintain a repository index. In a terminal,
setup asks for the collection root and confirms a path preview. Use
`code setup --root ~/Code --yes` to provide every answer noninteractively. Setup
is safe to run again after an upgrade. If it finds pre-4.0 base checkouts
directly beneath the root, it moves them into `repos/` and repairs live task
worktrees. It preserves
dirty files and custom collection README content.

## Start a task

Before an automated coding session edits files, create a task worktree and enter
the exact path printed by the command:

```bash
cd ~/Code/repos/pi
cd "$(code new)"
git status --short --branch
```

With no arguments, `new` discovers the base repository containing the current
directory. You can still run `code new pi` from elsewhere. Without a task
argument, Code chooses an unused world capital for both
the folder and branch. A result might be:

```text
~/Code/worktrees/pi/reykjavik
```

Use `code new pi fix-auth` when you want an explicit name. A new task branch
starts at the current `HEAD` of the base repository checkout. For a repository
without commits, it starts as an unborn branch so the first commit can be made
in the task worktree. If an explicitly named inactive branch already exists,
`new` reattaches it. There is no implicit fetch, pull, reset, or branch deletion.

Do not create task folders manually. Two processes editing a base checkout still
share files; each editing task needs its own returned worktree path.

## Finish a task

```bash
code remove pi/reykjavik
```

Removal deletes the task checkout but retains its branch. It refuses dirty work;
`--force` explicitly discards uncommitted changes. If a task directory is
manually deleted, `code list` omits it and `code doctor` reports Git's stale
worktree metadata. Run ordinary `git worktree prune` from the base checkout to
remove that record. Delete or merge branches with
ordinary Git when that is what you intend.

All examples use the `code` command.
