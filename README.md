<p align="center">
  <img src="assets/logo.svg" alt="Code" width="128">
</p>

# Code

Code gives every repository a stable base checkout and every task its own
Git worktree. You get parallel branches without agents, terminals, or half-done
changes sharing the same files.

```text
~/Code/
├── README.md
├── repos/
│   └── pi/                        normal checkout, usually on main
└── worktrees/
    └── pi/
        ├── fix-auth/              isolated checkout on fix-auth
        └── update-docs/           isolated checkout on update-docs
```

`repos/` answers “which projects do I have?” and `worktrees/` answers “what am
I working on?” Code does not fetch automatically, delete branches, or
hide Git behind a new workflow.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/code/main/scripts/install.sh | sh
```

This installs `code` in `~/.local/bin`.
Make sure that directory is on your `PATH`.

To link a development checkout instead:

```bash
git clone https://github.com/fschrhunt/code.git
cd code
./install.sh
```

## Quick start

Create a new collection—or upgrade an existing pre-4.0 collection—then clone:

```bash
code setup
# ? Collection root [~/Code]:
# ? Set up this collection? [Y/n]:
code clone owner/pi
cd ~/Code/repos/pi
```

Create an isolated checkout before starting a task. From a base checkout,
Code discovers the repository from the current directory:

```bash
cd "$(code new)"
git status --short --branch
```

A normal `git clone` placed directly in `repos/<repo>` works the same as
`code clone`; Code scans the folder rather than maintaining an index. When
no task is supplied, Code chooses an unused world capital for both
the folder and branch. For example, the command may print:

```text
~/Code/worktrees/pi/reykjavik
```

Pass an explicit name when you want one: `code new pi fix-auth` creates the
`fix-auth` folder and branch.

Work there, commit normally, and use your ordinary Git hosting workflow. When
the checkout is no longer needed:

```bash
code remove pi/reykjavik
```

Removal keeps the branch. It refuses uncommitted changes unless you explicitly
add `--force`.

## Daily commands

```text
code clone owner/repo       Clone into repos/<repo>
code new [repo [task]]      Create a task; infer repo here or omit task for a capital
code list                   Show base repositories and managed task worktrees
code remove repo/task       Remove a clean task checkout, but keep its branch
code doctor                 Check Git and local worktree metadata
code root                   Print the selected collection root
code help                   Show all commands
```

All examples use the `code` command.

## Upgrading an existing collection

Run setup after installing a new release. In a terminal it opens a short wizard
that confirms the root and previews the resulting paths:

```bash
code setup
```

Scripts and unattended installs can provide every answer with flags:

```bash
code setup --root ~/Code --yes
```

For a pre-4.0 collection, setup moves base checkouts from `<root>/<repo>` to
`<root>/repos/<repo>` and repairs every live linked worktree. Dirty files,
branches, and ownership markers are preserved. All destinations are checked
before the first move; if repair fails, completed moves are rolled back.

Setup also refreshes a Code-generated collection `README.md`. A custom
README is never replaced. `code list` and `code doctor` warn when they find a legacy
layout that still needs setup.

## The safety model

A task checkout is managed only when it is both beneath
`worktrees/<repo>/` **and** carries Code’ marker in its private Git
administrative directory. A matching path or branch name alone is not enough.
Code therefore ignores and refuses to remove manually created or
third-party worktrees.

Automated coding sessions should never edit a checkout in `repos/`. If a session
starts there, run `code new` and continue only in the exact path it prints. One
task worktree per editing session keeps files, staging, and commits isolated.

Use `code remove` instead of deleting a task folder manually. If a folder is
removed outside Code, `code list` omits it and `code doctor` reports the stale
Git worktree metadata; ordinary `git worktree prune` removes that stale record.

## Custom collection root

The default root is `~/Code`. Select another path in the wizard, or skip
the prompts with:

```bash
code setup --root ~/Code --yes
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
