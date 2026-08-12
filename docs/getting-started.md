# Getting started

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workspaces/main/scripts/install.sh | sh
```

The verified installer links `workspaces` into `~/.local/bin`.

## Clone a repository

Workspaces uses `~/workspaces` by default. Clone directly into it:

```bash
workspaces clone owner/pi
cd ~/workspaces/pi
git status --short --branch
```

The result is an ordinary Git checkout, normally on the remote's default
branch. Workspaces does not reserve it, wrap Git, or move it beneath another
folder.

To choose another collection once:

```bash
workspaces setup --root ~/code
```

For a one-command override, set `WORKSPACES_ROOT`.

## Work in parallel

Two agents editing the same checkout can overwrite or commit each other's work.
Give each task its own sibling checkout:

```bash
cd "$(workspaces new pi fix-auth)"
# work or start an agent

cd "$(workspaces new pi update-docs)"
# work or start another agent
```

This creates:

```text
~/workspaces/pi
~/workspaces/pi-fix-auth
~/workspaces/pi-update-docs
```

A new task branch starts at the current `HEAD` of the normal repository
checkout. If an inactive branch already exists, `new` reattaches it instead.
There is no implicit fetch, pull, reset, or branch deletion.

## Finish a task

```bash
workspaces remove pi/fix-auth
```

Removal deletes the task checkout but retains `fix-auth`. It refuses dirty work;
`--force` explicitly discards uncommitted changes. Delete or merge branches with
ordinary Git when that is what you intend.
