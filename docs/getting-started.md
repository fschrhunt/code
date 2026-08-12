# Getting started

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workspaces/main/scripts/install.sh | sh
```

The verified installer links `workspaces` into `~/.local/bin`.

## Clone a repository

Workspaces uses `~/workspaces` by default:

```bash
workspaces clone owner/pi
cd ~/workspaces/pi
git status --short --branch
```

The result is a normal Git checkout, usually on the remote's default branch.
Top-level directories are reserved for repositories. Setup is optional unless
you want another collection root:

```bash
workspaces setup --root ~/code
```

## Start a task

Before an automated coding session edits files, create a task worktree and enter
the exact path printed by the command:

```bash
cd ~/workspaces/pi
path=$(workspaces new pi fix-auth)
cd "$path"
git status --short --branch
pi
```

The task path is:

```text
~/workspaces/worktrees/pi/fix-auth
```

A new task branch starts at the current `HEAD` of the normal repository
checkout. If an inactive branch already exists, `new` reattaches it. There is no
implicit fetch, pull, reset, or branch deletion.

Do not create top-level task folders manually. Two agents editing the base
checkout still share files; each editing task needs its own returned worktree
path.

## Finish a task

```bash
workspaces remove pi/fix-auth
```

Removal deletes the task checkout but retains its branch. It refuses dirty work;
`--force` explicitly discards uncommitted changes. Delete or merge branches with
ordinary Git when that is what you intend.
