# Getting started

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workspaces/main/scripts/install.sh | sh
```

The verified installer links `workspaces` and its `ws` alias into
`~/.local/bin`.

## Clone a repository

Workspaces uses `~/workspaces` by default:

```bash
ws clone owner/pi
cd ~/workspaces/repos/pi
git status --short --branch
```

The result is a normal Git checkout, usually on the remote's default branch.
Repositories live in `repos/`; isolated task checkouts live in `worktrees/`.
Setup is optional unless you want another collection root:

```bash
ws setup --root ~/code
```

## Start a task

Before an automated coding session edits files, create a task worktree and enter
the exact path printed by the command:

```bash
cd ~/workspaces/repos/pi
cd "$(ws new pi)"
git status --short --branch
```

Without a task argument, Workspaces chooses an unused world capital for both
the folder and branch. A result might be:

```text
~/workspaces/worktrees/pi/reykjavik
```

Use `ws new pi fix-auth` when you want an explicit name. A new task branch
starts at the current `HEAD` of the base repository checkout. If an explicitly
named inactive branch already exists, `new` reattaches it. There is no implicit
fetch, pull, reset, or branch deletion.

Do not create task folders manually. Two processes editing a base checkout still
share files; each editing task needs its own returned worktree path.

## Finish a task

```bash
ws remove pi/reykjavik
```

Removal deletes the task checkout but retains its branch. It refuses dirty work;
`--force` explicitly discards uncommitted changes. Delete or merge branches with
ordinary Git when that is what you intend.

`workspaces` can replace `ws` in every example.
