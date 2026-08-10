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

The installer links two names for the same executable: `workframe` and the
short `wf`. Every example in the documentation accepts either.

Confirm the installation, then view the command map:

```bash
workframe version
wf help
```

Checkout installations can be updated from anywhere with:

```bash
workframe update
```

The command safely updates the checkout used by the installed executable from
its stable `main` branch. It can recover a clean checkout whose pull-request
branch was squash-merged and deleted, but refuses unpublished or divergent
work. Homebrew installations remain package-manager-owned and use
`brew upgrade workframe` instead.

If the shell cannot find `workframe` or `wf`, add `~/.local/bin` to `PATH` or
install into a directory already on `PATH`.

## Set up a local profile

Create a local store explicitly. The suggested local root is `~/workframe`, but
any absolute path is supported, including a folder on an attached volume:

```bash
workframe init --agent codex
# Optional: --root /Volumes/workframe --editor cursor --org owner
```

`setup` prompts for omitted safe details in an interactive terminal; scripts
and coding agents should pass the flags they need.

The selected store contains `system/config/workframe.conf` and `WORKFRAME.md`.
Workframe remembers its location in
`${XDG_CONFIG_HOME:-~/.config}/workframe/root`, so later commands find it
without a symlink or exported environment variable. `WORKFRAME.md` is a
central safety contract for agents and launchers. Tools that begin discovery
at the Git root must be directed to the parent guide explicitly.

An agent identity is a branch namespace, not a vendor lock-in. Names such as
`codex`, `claude`, `cursor`, or a teammate name are all valid.

## Create your first workspace

Clone a repository, then create a workspace. Workframe prints its path, branch,
and generated city label:

```bash
workframe clone owner/repo
workframe new repo feature-name --agent codex
workframe list
workframe open repo/feature-name
```

## Pause and resume

Use `workframe archive <selector>` to remove the folder while keeping its
branch, then `workframe restore <repo> <branch>` to bring it back. Permanent
removal is separate and requires confirmation.

## Next steps

- Learn the [core concepts](concepts.md).
- Follow the full [workspace lifecycle](guides/workspace-lifecycle.md).
- Configure [agents and editors](guides/agents-and-editors.md).
- Review [local and shared profiles](guides/profiles.md).
- Keep the [CLI reference](reference/cli.md) nearby.
