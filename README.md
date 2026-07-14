# wt — agent worktrees

`wt` makes isolated git worktrees easy to create, resume, and put away. Each
piece of work gets its own folder (a stable random city name) on its own branch
(`<agent>/<feature>`), sharing one canonical clone per repo.

You choose the agent on every `wt new` (interactive picker, or `--agent`). There
is no silent default agent. Manage identities with `wt agents`.

```
wt init                   # first run: local ~/.wt profile
wt agents add cursor      # configure agent identities
wt new <repo> <feature>   # start an isolated worktree (picks agent)
wt list                   # see active worktrees
wt open                   # open one in a new editor window
wt archive                # put it away (folder gone, branch kept — restorable)
wt restore                # bring an archived worktree back
```

## Status

Local-first simplify: `wt init` creates `~/.wt`, calm Greptile-style help, managed
agents (no `DEFAULT_AGENT`), and `wt open` launches a **new IDE window** (`cursor -n`).
Shared Mac→SSH→box remains available as a shared profile. See `WT-PLAN.md` (Agents store).

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
