# AGENTS.md — contract for any coding agent working on `wt`

This file is the single source of build/test/run truth. Contributors and coding
agents follow it so work stays compatible and safe.

## Golden rules

- **Never edit a deployed copy.** If a machine runs `wt` from an installed or
  mounted path, do not patch that binary in place. All work happens in **this
  repo**, on a branch, via PR. Shipping is a deliberate install/release step.
- **Dev is decoupled from deploy.** Ship with `./install.sh` or a tagged release
  — never a live edit of someone else's running install. In-progress work must
  not take down a running tool.
- **Green before proposed.** Every change must pass `make check` (shellcheck with
  zero warnings + all bats tests) locally. CI re-runs it on macOS and Linux. A
  red PR is not done.
- **Deterministic tests only.** No test may need the network, a remote box, an SMB
  mount, or an interactive TTY. Use `WT_BACKEND=1` + `WT_HOME=<tmp>` and the
  helpers in `test/helper.bash` (a local bare repo stands in for `origin`).
  Randomness (`RANDOM` city picker) must not affect assertions.
- **Behavior-preserving refactors stay behavior-preserving.** If you restructure,
  prove it with the golden test (`test/help.bats`) and the backend lifecycle
  tests. Intended output changes get their own visible commit + updated golden.
- **Never run teardown against a live shared store while developing.** Exercise
  `archive` / `remove` / `clean` only against test fixtures or your own local
  `~/.wt`.
- **Small, reviewable PRs** — one milestone slice each, with its tests.
- **No fleet secrets in the repo.** Hostnames, Tailscale IPs, org names, and
  mount paths belong in `~/.wt/config` (or a private deploy), not in shipped
  defaults.

## Build / test / run

```
make check      # lint + test (run this before every PR)
make lint       # shellcheck -x bin/wt install.sh
make test       # bats -r test
bin/wt help     # run it
./install.sh    # symlink bin/wt into ~/.local/bin (dev convenience)
```

Requirements: `bash`, `git`, `shellcheck`, `bats`. `gum` is optional (pretty UI;
plain fallback otherwise).

## Layout

```
bin/wt              entry point: resolves lib/, sources modules, dispatches
lib/config.sh       defaults, ~/.wt/config, role (ON_MAC) + paths (ROOT/REPOS/WORK)
lib/palette.sh      colors + ok/warn/err/die/banner
lib/ui.sh           logo, help, gum helpers, progress bar/spinner
lib/backend.sh      cmd_* git verbs — operate on $ROOT via `git -C`
lib/frontend.sh     mac_* interactive UX + _bx (ssh transport for shared)
lib/agents.sh       managed agent list + editor open
contrib/            optional helpers (e.g. mount-wt.sh) — not required for local
docs/               guides (docs/README.md → customize · extending)
test/               bats tests + golden fixtures
```

## Test seams

- `WT_BACKEND=1` — force the backend role on any OS (frontend is macOS otherwise).
- `WT_HOME=<dir>` — override the data root (and read `$WT_HOME/config`).
- `WT_COLOR=0/1` — force color off/on regardless of TTY.
