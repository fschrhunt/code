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

## Renaming `Agents` → `wt` (ops migration)

**Code:** new shared profiles suggest `/Volumes/wt`, `/mnt/wt`, share `wt`. Existing
`/Volumes/Agents` mounts are still auto-detected so today’s fleet keeps working.

**Live rename is medium–hard** — do not do it casually:

1. Stop agents/editors with cwd under `/Volumes/Agents`.
2. On the box: rename/export the SMB share `Agents` → `wt`, path `/mnt/agents` → `/mnt/wt`.
3. Update every Mac: mount script + LaunchAgent (`mount-wt.sh`), remount at `/Volumes/wt`.
4. Point `~/.wt/config` at the new paths (`wt config` → shared).
5. Open worktrees / Cursor windows will need reopening under the new path.

Until that migration, keep `share_name = Agents` and `mount_path = /Volumes/Agents`.

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
