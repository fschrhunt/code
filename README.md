<p align="center">
  <img src="assets/logo.svg" alt="Workspaces" width="128">
</p>

# Workspaces

A small CLI for keeping normal Git repositories and isolated task checkouts in
one predictable folder.

```text
~/workspaces/
├── pi/                    normal checkout
├── pi-fix-auth/           isolated task worktree
└── pi-update-docs/        another isolated task worktree
```

There is no hidden canonical clone or nested worktree hierarchy. `pi/` is the
ordinary repository you expect: enter it, see `main`, and use Git normally.
Task worktrees are visible siblings, so parallel work does not share files.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workspaces/main/scripts/install.sh | sh
```

For development, link a checkout instead:

```bash
git clone https://github.com/fschrhunt/workspaces.git
cd workspaces
./install.sh
```

## Use

The default collection is `~/workspaces`; setup is optional unless you want a
custom location.

```bash
workspaces clone owner/pi
cd ~/workspaces/pi
git status --short --branch
```

Create separate checkouts before running parallel tasks:

```bash
cd "$(workspaces new pi fix-auth)"
# start the first agent or work normally

cd "$(workspaces new pi update-docs)"
# start the second agent or work normally
```

Both task directories share Git history with `pi/`, but not working files.
Starting two editing processes directly in `pi/` does not provide isolation.

```bash
workspaces list
workspaces remove pi/fix-auth
```

Removal keeps the branch and refuses uncommitted changes unless `--force` is
explicit. Workspaces only removes task worktrees carrying its private ownership
marker; manually created worktrees remain untouched.

See [Getting started](docs/getting-started.md) and the
[CLI reference](docs/reference/cli.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and run:

```bash
make check
```
