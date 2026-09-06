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
code clone owner/e
cd ~/Code/repos/e
git status --short --branch
```

The result is a normal Git checkout, usually on the remote's default branch.
Repositories live in `repos/`; agent worktrees live flat in `worktrees/`.
A checkout created directly with `git clone` is also discovered when placed in
`repos/<repo>`; Code does not maintain a repository index. In a terminal,
setup asks for the collection root and confirms a path preview. Use
`code setup --root ~/Code --yes` to provide every answer noninteractively. Setup
is safe to run again after an upgrade. If it finds base checkouts
directly beneath the root, it moves them into `repos/` and repairs live
worktrees. It preserves dirty files and custom collection README content.

## Start a session

Before an editing session touches files, create a worktree and enter the exact
path printed by the command:

```bash
cd ~/Code/repos/e
cd "$(code new e)"
git status --short --branch
```

`new` takes the agent name — `e`, `pi`, `claude`, `codex`, anything
path-safe. It discovers the base repository containing the current directory
and names the folder and branch `<agent>-<repo>`:

```text
~/Code/worktrees/e-e
```

An occupied name suffixes `-1`, `-2`, and so on. A new branch starts at the
current `HEAD` of the base repository checkout. For a repository without
commits, it starts as an unborn branch so the first commit can be made in the
worktree. An inactive branch of the same name is reattached. There is no
implicit fetch, pull, reset, or branch deletion.

Do not create worktree folders manually. Two processes editing a base checkout
still share files; each editing session needs its own returned worktree path.

## Finish a session

```bash
code remove e-e
```

Removal deletes the worktree but retains its branch, so the next
`code new e` for the same pair reattaches it. It refuses dirty work;
`--force` explicitly discards uncommitted changes. If a worktree directory is
manually deleted, `code list` omits it and `code doctor` reports Git's stale
worktree metadata. Run ordinary `git worktree prune` from the base checkout to
remove that record. Delete or merge branches with ordinary Git when that is
what you intend.

All examples use the `code` command.
