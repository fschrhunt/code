<p align="center">
  <img src="assets/logo.svg" alt="Workframe" width="128">
</p>

# Workframe

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

## Start a task

```bash
workframe setup --root ~/workframe
workframe clone owner/repo
workframe new repo payment-retry
```

See [Getting started](docs/getting-started.md) for the complete workflow and
[the CLI reference](docs/reference/cli.md) for every command. `wf` is the short
alias for `workframe`.

## Ownership

Workframe acts only on branches it records in `refs/workframe/managed/*`.
Conductor and manually created worktrees are unmarked and remain untouched. See
[Concepts](docs/concepts.md#ownership-and-conductor-boundary) for the boundary.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). Run the
full check before submitting a change:

```bash
make check
```

## Documentation

See the [documentation index](docs/README.md) for guides and references.
