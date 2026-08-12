# Workframe

**A small, safe allocator for Git worktrees.**

Workframe keeps one canonical clone per repository and creates one owned
worktree per task. Its only job is to allocate that worktree, locate it later,
and safely archive it.

```text
<store>/
├── repos/<repo>/                 canonical clone
└── workspaces/<repo>/<city>/     Workframe-owned task checkout
```

A task is always addressed as `<repo>/<task>`; the generated city is only a
unique folder name. Workframe records every branch it creates or migrates in a
private Git ref. It never lists, archives, restores, or deletes an unmarked
worktree—even if its path looks identical. That cleanly separates Workframe
workspaces from [Conductor](https://www.conductor.build/) workspaces and raw
Git worktrees.

## Install

Install the latest verified release without a package manager:

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workframe/main/scripts/install.sh | sh
```

The installer downloads a versioned GitHub release, verifies its SHA-256
checksum, and links `workframe` and `wf` into `~/.local/bin`.

Homebrew remains supported:

```bash
brew install fschrhunt/tap/workframe
```

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

workframe list
workframe path repo/payment-retry
workframe archive repo/payment-retry --yes
workframe restore repo payment-retry
```

`wf` is the short alias. `workframe help` is the complete command reference.

## Conductor boundary

Conductor uses ordinary Git worktrees and usually places them beneath
`~/conductor/workspaces/<repo>/<workspace>`. It stores workspace sessions,
reviews, and archive state outside Git, so another Git-only tool cannot
reliably identify every Conductor workspace from its path or branch alone.

Workframe therefore uses a positive ownership rule, not a heuristic: only
branches marked in `refs/workframe/managed/*` are Workframe-owned. Conductor
worktrees remain unmarked and are ignored. Do not add those refs manually.

## Develop

```bash
make check
```

This runs ShellCheck and the hermetic Bats suite. See [AGENTS.md](AGENTS.md)
and [docs](docs/README.md) before contributing.
