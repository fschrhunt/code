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

This installs `workspaces` and its shorter alias, `ws`, in `~/.local/bin`.
Make sure that directory is on your `PATH`.

To link a development checkout instead:

```bash
git clone https://github.com/fschrhunt/workspaces.git
cd workspaces
./install.sh
```

## Quick start

Clone a repository into the default `~/workspaces/repos` collection:

```bash
ws clone owner/pi
cd ~/workspaces/repos/pi
```

Create an isolated checkout before starting a task:

```bash
cd "$(ws new pi)"
git status --short --branch
```

When no task is supplied, Workspaces chooses an unused US state capital for
both the folder and branch. For example, the command may print:

```text
~/workspaces/worktrees/pi/salem
```

Pass an explicit name when you want one: `ws new pi fix-auth` creates the
`fix-auth` folder and branch.

Work there, commit normally, and use your ordinary Git hosting workflow. When
the checkout is no longer needed:

```bash
ws remove pi/salem
```

Removal keeps the branch. It refuses uncommitted changes unless you explicitly
add `--force`.

## Daily commands

```text
ws clone owner/repo       Clone into repos/<repo>
ws new repo [task]        Create a task; omit its name to use a state capital
ws list                   Show base repositories and managed task worktrees
ws remove repo/task       Remove a clean task checkout, but keep its branch
ws doctor                 Check Git and local worktree metadata
ws root                   Print the selected collection root
ws help                   Show all commands
```

`workspaces` can replace `ws` in every example.

## Upgrading an existing collection

Workspaces does not move existing checkouts automatically. If your repositories
still sit directly beneath `~/workspaces`, first finish or remove their task
worktrees, then move each base checkout into `repos/`:

```bash
mkdir -p ~/workspaces/repos
mv ~/workspaces/pi ~/workspaces/repos/pi
```

If a linked task must remain during the move, repair its Git pointers afterward:

```bash
git -C ~/workspaces/repos/pi worktree repair ~/workspaces/worktrees/pi/fix-auth
```

Run that repair once for each retained task path.

## The safety model

A task checkout is managed only when it is both beneath
`worktrees/<repo>/` **and** carries Workspaces’ marker in its private Git
administrative directory. A matching path or branch name alone is not enough.
Workspaces therefore ignores and refuses to remove manually created or
third-party worktrees.

Automated coding sessions should never edit a checkout in `repos/`. If a session
starts there, run `ws new <repo> [task]` and continue only in the exact path it
prints. One task worktree per editing session keeps files, staging, and commits
isolated.

## Custom collection root

The default root is `~/workspaces`. Select another absolute path with:

```bash
ws setup --root ~/code
```

Setup creates only `README.md`, `repos/`, and `worktrees/`, and never replaces
an existing collection README.

For more detail, see [Getting started](docs/getting-started.md), the
[filesystem reference](docs/reference/filesystem.md), and the
[CLI reference](docs/reference/cli.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and run:

```bash
make check
```
