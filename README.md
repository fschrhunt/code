# wt — agent worktrees

`wt` makes isolated git worktrees easy to create, resume, and put away. Each
piece of work gets its own folder (a stable random city name) on its own branch
(`<agent>/<feature>`), sharing one canonical clone per repo.

You choose the agent on every `wt new`. Manage identities with `wt agents`.
There is no silent default agent.

```
wt init                              # local ~/.wt (or: wt init --shared)
wt agents add cursor
wt new <repo> <feature> --agent cursor
wt list                              # active worktrees
wt list archived                     # archived branches
wt ide <sel>                         # new IDE window
wt archive <sel> [--yes]             # put away (keeps branch)
wt restore <repo> <branch>           # bring back
wt remove branch <repo> <branch> [--yes]
wt remove repo <repo> [--force] [--yes]
wt clean                             # dry-run; wt clean --yes to apply
wt config                            # editor, org, local|shared stack
```

## Profiles

- **Local** (default after `wt init`): everything under `~/.wt`, no SSH/mount.
- **Shared**: repos on a box (`box_root`), mounted locally (`mount_path`), git over SSH.
  Configure with `wt init --shared` or `wt config` → shared.

All shared-stack hosts and paths live in `~/.wt/config` (`mount_path`, `box_root`,
`share_name`, `box_host`, …). The repo ships no fleet-specific defaults.

Optional: [contrib/mount-wt.sh](contrib/mount-wt.sh) mounts the SMB share using
those same config values (or `WT_*` env overrides).

## Develop

```
make check   # shellcheck + bats
bin/wt help
```

See [AGENTS.md](AGENTS.md) for the contributor contract. Docs:
[docs/README.md](docs/README.md) — customize prefs · extend the product.

## Install (dev)

```
./install.sh            # symlink bin/wt into ~/.local/bin
./install.sh /usr/local/bin
```
