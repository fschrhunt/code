<p align="center">
  <img src="assets/logo.svg" alt="Workspaces" width="128">
</p>

# Workspaces

Workspaces gives every repository a stable base checkout and every task its own
Git worktree. You get parallel branches without agents, terminals, or half-done
changes sharing the same files.

```text
~/workspaces/
├── README.md
├── repos/
│   └── pi/                        normal checkout, usually on main
└── worktrees/
    └── pi/
        ├── fix-auth/              isolated checkout on fix-auth
        └── update-docs/           isolated checkout on update-docs
```

`repos/` answers “which projects do I have?” and `worktrees/` answers “what am
I working on?” Workspaces does not fetch automatically, delete branches, or
hide Git behind a new workflow.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workspaces/main/scripts/install.sh | sh
```

This installs `workspaces` in `~/.local/bin`.
Make sure that directory is on your `PATH`.

To link a development checkout instead:

```bash
git clone https://github.com/fschrhunt/workspaces.git
cd workspaces
./install.sh
```

## Quick start

Create a new collection—or upgrade an existing pre-4.0 collection—then clone:

```bash
workspaces setup
# ? Collection root [~/workspaces]:
# ? Set up this collection? [Y/n]:
workspaces clone owner/pi
cd ~/workspaces/repos/pi
```

Create an isolated checkout before starting a task. From a base checkout,
Workspaces discovers the repository from the current directory:

```bash
cd "$(workspaces new)"
git status --short --branch
```

A normal `git clone` placed directly in `repos/<repo>` works the same as
`workspaces clone`; Workspaces scans the folder rather than maintaining an index. When
no task is supplied, Workspaces chooses an unused world capital for both
the folder and branch. For example, the command may print:

```text
~/workspaces/worktrees/pi/reykjavik
```

Pass an explicit name when you want one: `workspaces new pi fix-auth` creates the
`fix-auth` folder and branch.

Work there, commit normally, and use your ordinary Git hosting workflow. When
the checkout is no longer needed:

```bash
workspaces remove pi/reykjavik
```

Removal keeps the branch. It refuses uncommitted changes unless you explicitly
add `--force`.

## Daily commands

```text
workspaces clone owner/repo       Clone into repos/<repo>
workspaces new [repo [task]]      Create a task; infer repo here or omit task for a capital
workspaces list                   Show base repositories and managed task worktrees
workspaces remove repo/task       Remove a clean task checkout, but keep its branch
workspaces doctor                 Check Git and local worktree metadata
workspaces root                   Print the selected collection root
workspaces help                   Show all commands
```

All examples use the `workspaces` command.

## Upgrading an existing collection

Run setup after installing a new release. In a terminal it opens a short wizard
that confirms the root and previews the resulting paths:

```bash
workspaces setup
```

Scripts and unattended installs can provide every answer with flags:

```bash
workspaces setup --root ~/workspaces --yes
```

For a pre-4.0 collection, setup moves base checkouts from `<root>/<repo>` to
`<root>/repos/<repo>` and repairs every live linked worktree. Dirty files,
branches, and ownership markers are preserved. All destinations are checked
before the first move; if repair fails, completed moves are rolled back.

Setup also refreshes a Workspaces-generated collection `README.md`. A custom
README is never replaced. `workspaces list` and `workspaces doctor` warn when they find a legacy
layout that still needs setup.

## The safety model

A task checkout is managed only when it is both beneath
`worktrees/<repo>/` **and** carries Workspaces’ marker in its private Git
administrative directory. A matching path or branch name alone is not enough.
Workspaces therefore ignores and refuses to remove manually created or
third-party worktrees.

Automated coding sessions should never edit a checkout in `repos/`. If a session
starts there, run `workspaces new` and continue only in the exact path it prints. One
task worktree per editing session keeps files, staging, and commits isolated.

Use `workspaces remove` instead of deleting a task folder manually. If a folder is
removed outside Workspaces, `workspaces list` omits it and `workspaces doctor` reports the stale
Git worktree metadata; ordinary `git worktree prune` removes that stale record.

## Custom collection root

The default root is `~/workspaces`. Select another path in the wizard, or skip
the prompts with:

```bash
workspaces setup --root ~/code --yes
```

Setup leaves only `README.md`, `repos/`, and `worktrees/` at the collection
root. It refreshes generated guides but never replaces a custom collection
README.

For more detail, see [Getting started](docs/getting-started.md), the
[filesystem reference](docs/reference/filesystem.md), and the
[CLI reference](docs/reference/cli.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and run:

```bash
make check
```
