# wt — agent worktrees

`wt` makes isolated git worktrees easy to create, resume, and put away. Each
piece of work gets its own folder (a stable random city name) on its own branch
(`<agent>/<feature>`), sharing one canonical clone per repo.

You choose the agent on every `wt new`. Manage identities with `wt agents`.
There is no silent default agent.

```
wt init                   # local ~/.wt (or: wt init --shared)
wt agents add cursor
wt new <repo> <feature>   # picks agent interactively
wt list                   # active worktrees
wt list archived          # archived branches
wt open                   # new IDE window
wt archive / wt restore
wt config                 # editor, org, local|shared stack
```

## Profiles

- **Local** (default after `wt init`): everything under `~/.wt`, no SSH/mount.
- **Shared**: repos on a box (`box_root`), mounted locally (`mount_path`), git over SSH.
  Configure with `wt init --shared` or `wt config` → shared. Your server store stays.

Paths are values in `~/.wt/config` (`mount_path`, `box_root`, `share_name`, …) — not
hardcoded to one machine’s layout.

## Shared store layout

Fleet Macs mount `smb://…/wt` at `/Volumes/wt`. On the box the image lives at
`/opt/wt-store/wt.img` (filesystem label `wt`), mounted at `/mnt/wt`. Compatibility
symlinks remain: `/mnt/agents` → `/mnt/wt`, `/opt/agents-store` → `/opt/wt-store`.

Use `~/.local/bin/mount-wt.sh` (LaunchAgent `com.fschrhunt.wt-mount`). Older
`mount-agents.sh` is a thin wrapper.


## Develop

```
make check   # shellcheck + bats
bin/wt help
```

See [AGENTS.md](AGENTS.md) for the contributor contract. Roadmap: `WT-PLAN.md` on the store.

## Install (dev)

```
./install.sh            # symlink bin/wt into ~/.local/bin
./install.sh /usr/local/bin
```
