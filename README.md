# wt — agent worktrees

`wt` makes isolated git worktrees easy to create, resume, and put away. Each
piece of work gets its own folder (a stable random city name) on its own branch
(`<agent>/<feature>`), sharing one canonical clone per repo.

You choose the agent on every `wt new`. Manage identities with `wt agents`.
There is no silent default agent.

**Status:** M0 foundation is shipped (shared/SSH store + in-repo CLI). Next:
[M1 profiles](https://linear.app/intuitum/issue/DEV-175) →
[M2 local `~/.wt`](https://linear.app/intuitum/issue/DEV-181).

```
wt init --shared                     # or: wt init  (local under ~/.wt)
wt agents add nova                   # if init did not already
wt clone owner/repo                  # add a repo to the store
wt new <repo> <feature> --agent nova
wt list                              # active worktrees
wt list archived                     # archived branches
wt ide <sel>                         # new IDE window
wt archive <sel> [--yes] [--force]   # put away; --force discards dirty
wt restore <repo> <branch>           # bring back
wt remove branch <repo> <branch> [--yes]
wt remove repo <repo> [--force] [--yes]
wt clean                             # dry-run; wt clean --yes to apply
wt status                            # quick glance (doctor is the deep check)
wt config                            # editor, org, local|shared stack
cd "$(wt cd …)"                      # or install the shell hook via wt init/config
```

## Profiles

| Profile | Data lives | Git / store verbs |
|---------|------------|-------------------|
| **shared** (M0 production / fleet) | box (`box_root`) + Mac mount (`mount_path`) | Over SSH to `$BOX_ROOT/system/bin/wt` |
| **local** (in-repo today; M2 documents as default) | `~/.wt` (or `$WT_HOME`) | In-process |

Configure with `wt init` / `wt init --shared` or `wt config`. Shared hosts and
paths live in `~/.wt/config` (`mount_path`, `box_root`, `share_name`,
`box_host`, …). The repo ships no fleet-specific defaults.

**Never edit the live deploy** at `/Volumes/Agents/system/bin/wt` (or any other
mounted `$BOX_ROOT/system/bin/wt`). Change this repo on a branch, PR, then
install/release deliberately.

Optional: [contrib/mount-wt.sh](contrib/mount-wt.sh) mounts the SMB share using
those same config values (or `WT_*` env overrides).

## Develop

```
make check   # shellcheck + bats
bin/wt help
```

See [AGENTS.md](AGENTS.md) for the contributor + Linear agent contract. Docs
index: [docs/README.md](docs/README.md).

## Install (dev)

```
./install.sh            # symlink bin/wt into ~/.local/bin
./install.sh /usr/local/bin
```

Version: see [VERSION](VERSION) (currently `1.4.2`).
