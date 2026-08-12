<p align="center">
  <img src="assets/logo.svg" alt="Workspaces" width="128">
</p>

# Workspaces

A small CLI for keeping normal Git repositories and isolated task checkouts in
one predictable folder.

```text
~/workspaces/
├── pi/                            normal checkout on main
└── worktrees/
    └── pi/
        ├── fix-auth/              isolated task checkout
        └── update-docs/           another isolated task checkout
```

`pi/` is the ordinary repository you expect: enter it, see `main`, and use it as
the base for new tasks. Parallel work lives beneath `worktrees/`, grouped by
repository, so task folders never obscure the top-level repository list.

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

Create a task checkout before editing:

```bash
cd ~/workspaces/pi
path=$(workspaces new pi fix-auth)
cd "$path"
git status --short --branch
```

This returns `~/workspaces/worktrees/pi/fix-auth`. Start the agent from that
path. A second task gets another directory beneath `worktrees/pi/`; both share
Git history with `pi/`, but not working files.

Automated coding sessions must not edit the top-level `pi/` checkout. If an
agent starts there, it should use `workspaces new` and continue only in the
returned path. Do not create top-level task folders manually.

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
