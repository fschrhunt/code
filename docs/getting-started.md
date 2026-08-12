# Getting started

## Install

Install the latest verified release:

```bash
curl -fsSL https://raw.githubusercontent.com/fschrhunt/workframe/main/scripts/install.sh | sh
```

The installer links `workframe` and `wf` into `~/.local/bin`. It downloads only
versioned GitHub release assets and verifies their SHA-256 checksum.

For development, link a checkout instead:

```bash
git clone https://github.com/fschrhunt/workframe.git
cd workframe
./install.sh
```

Both install `workframe` and its short alias, `wf`.

## Create a workspace

```bash
workframe setup --root ~/workframe
workframe clone owner/repo
cd "$(workframe new repo feature-name)"
```

`new` fetches the repository's default branch before creating the task, so the
workspace starts from the current remote tip. It prints only the workspace path,
so it composes with ordinary Git and GitHub CLI commands without a Workframe
wrapper:

```bash
cd "$(workframe new repo feature-name)"
git status --short --branch
gh pr create
```

For intentional disconnected work, use `workframe new --offline repo
feature-name`; it uses the locally cached remote ref. Use the task identity to
find work later:

```bash
workframe path repo/feature-name
workframe list
```

Refresh a canonical repository at any time with `workframe sync repo`, or all
canonical repositories with `workframe sync --all`. Sync fast-forwards only
clean, non-diverged canonical checkouts.

A command cannot change its parent shell's directory. If you prefer `wf new`
to enter the workspace directly, add this opt-in wrapper to `~/.zshrc`:

```zsh
wf() {
  if [[ $1 == new ]]; then
    local workspace
    workspace=$(command workframe "$@") || return
    cd "$workspace"
  else
    command workframe "$@"
  fi
}
```

## Update Workframe

```bash
workframe update
```

This reruns the verified release installer. It replaces Workframe's versioned
payload and command links; it does not change your store or workspaces.

## Pause or finish work

```bash
workframe archive repo/feature-name --yes
workframe restore repo feature-name
workframe remove branch repo feature-name --yes
```

Archive keeps the branch and refuses dirty work unless `--force` is explicit.
Removing a branch is permanent.

See the [CLI reference](reference/cli.md) for every command and the
[Conductor boundary](concepts.md#conductor-boundary) before using Workframe in
a repository also managed by Conductor.
