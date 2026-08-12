# Getting started

## Install

Install the supported Homebrew formula:

```bash
brew install fschrhunt/tap/workframe
```

For development, install a checkout instead:

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
workframe new repo feature-name
```

`new` prints the worktree path, branch, and generated folder label. Use the
task identity—not the folder label—to find it later:

```bash
workframe path repo/feature-name
workframe list
```

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
