# wt — agent worktrees

`wt` makes isolated git worktrees easy to create, resume, and put away. Each
piece of work gets its own folder (a stable random city name) on its own branch
(`<agent>/<feature>`), sharing one canonical clone per repo.

```
wt new <repo> <feature>   # start an isolated worktree
wt list                   # see active worktrees
wt open                   # open one in your editor
wt archive                # put it away (folder gone, branch kept — restorable)
wt restore                # bring an archived worktree back
```

## Status

This is the **M0 foundation**: the tool has been brought into version control and
split from a single 425-line script into `bin/wt` + `lib/*.sh`, with tests and
CI, behavior-identical to the deployed v1. See `WT-PLAN.md` (Agents store) for the
roadmap.

Today `wt` runs in **shared mode**: a Mac frontend forwards git operations over
SSH to a box where the store lives. **Local mode** — everything on your own
computer under `~/.wt`, no mount/SSH/box — is the next milestones (M1 profiles,
M2 local mode) and will become the default.

## Develop

```
make check   # shellcheck + bats — run before every PR
bin/wt help
```

See [AGENTS.md](AGENTS.md) for the contributor/agent contract.

## Install (dev)

```
./install.sh            # symlink bin/wt into ~/.local/bin
./install.sh /usr/local/bin
```
