<p align="center">
  <img src="assets/logo.svg" alt="Workframe" width="128">
</p>

# Workframe

A local CLI for safe, owned Git task worktrees.

Workframe gives each task an owned Git worktree. One canonical clone stays
clean; each task gets its own branch and directory.

```text
<store>/
├── repos/<repo>/                 canonical clone
└── workspaces/<repo>/<city>/     owned task checkout
```

A task is `repo/task`. The city is only a unique directory name.

## Install

Install the latest verified release:

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workframe/main/scripts/install.sh | sh
```

The installer downloads a versioned GitHub release, verifies its SHA-256
checksum, and links `workframe` and `wf` into `~/.local/bin`.

For development, link a checkout instead:

```bash
git clone https://github.com/fschrhunt/workframe.git
cd workframe
./install.sh                    # link this checkout into ~/.local/bin
```

## Use

```bash
workframe setup --root ~/workframe
workframe clone owner/repo
workframe new repo payment-retry

workframe path repo/payment-retry
workframe archive repo/payment-retry --yes
workframe restore repo payment-retry
```

`wf` is the short alias. Run `workframe help` for the complete interface.

## Ownership

Conductor and raw Git worktrees use the same Git primitive. Workframe does not
guess ownership from their paths or branches. It records only its own branches
in `refs/workframe/managed/*`, and lists or changes only those branches.

## Develop

```bash
make check
```

See [AGENTS.md](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md), and
[docs](docs/README.md).
