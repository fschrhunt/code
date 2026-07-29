# Getting started

This guide installs Workframe, creates a local store, registers an agent, and
opens the first isolated worktree.

## Prerequisites

- Bash
- Git
- macOS or Linux
- Optional: `gum` for interactive selectors and polished terminal output

Contributors also need `shellcheck` and `bats`.

## Install

Install the current release with Homebrew:

```bash
brew install fschrhunt/tap/workframe
```

Upgrade a Homebrew installation with:

```bash
brew upgrade workframe
```

To install from source instead, clone the repository and link the executable
into `~/.local/bin`:

```bash
git clone https://github.com/fschrhunt/workframe.git
cd workframe
./install.sh
```

To choose another binary directory:

```bash
./install.sh /usr/local/bin
```

Confirm the installation:

```bash
workframe version
workframe help
```

Checkout installations can be updated from anywhere with:

```bash
workframe update
```

The command safely fast-forwards the tracked branch of the checkout used by
the installed executable. Homebrew installations remain package-manager-owned
and use `brew upgrade workframe` instead.

If the shell cannot find `workframe`, add `~/.local/bin` to `PATH` or install
into a directory already on `PATH`.

## Set up a local profile

```bash
workframe setup
```

Setup asks where the Workframe store should live, which agent identities to
create, which editor to use, and an optional default GitHub organization. The
suggested local root is `~/workframe`, but any absolute path is supported,
including a folder on an attached volume.

For a non-interactive setup:

```bash
workframe setup --local \
  --root /Volumes/v0/development/workframe \
  --agent codex \
  --agent claude \
  --editor cursor
```

The selected store contains `system/config/workframe.conf` and `WORKFRAME.md`.
Workframe remembers its location in
`${XDG_CONFIG_HOME:-~/.config}/workframe/root`, so later commands find it
without a symlink or exported environment variable. `WORKFRAME.md` is a
central safety contract for agents and launchers. Tools that begin discovery
at the Git root must be directed to the parent guide explicitly.

An agent identity is a branch namespace, not a vendor lock-in. Names such as
`codex`, `claude`, `cursor`, or a teammate name are all valid.

## Create your first workspace

Add a canonical repository:

```bash
workframe clone owner/repo
```

Start an isolated worktree:

```bash
workframe new repo fix-login --agent codex
```

Workframe prints the workspace path, branch, and generated city label. Open it
in the configured editor:

```bash
workframe ide repo/fix-login
```

See all active work:

```bash
workframe list
```

## Pause and resume

Archive removes the worktree folder but preserves its branch:

```bash
workframe archive repo/fix-login --yes
workframe list archived
```

Restore recreates the worktree from that branch:

```bash
workframe restore repo codex/fix-login
```

## Next steps

- Learn the [core concepts](concepts.md).
- Follow the full [workspace lifecycle](guides/workspace-lifecycle.md).
- Configure [agents and editors](guides/agents-and-editors.md).
- Review [local and shared profiles](guides/profiles.md).
- Keep the [CLI reference](reference/cli.md) nearby.
