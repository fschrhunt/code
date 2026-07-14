# AGENTS.md — contract for any coding agent working on `wt`

This file is the single source of build/test/run truth. Conductor's Codex, Grok
build, Claude, and humans all follow it so work stays compatible and safe.

## Golden rules

- **Never edit a deployed copy.** The running fleet tool lives at
  `/Volumes/wt/system/bin/wt` (origin `/mnt/wt/...`). All work happens in
  **this repo**, on a branch, via PR. Editing the mounted/deployed copy directly
  is how you break every machine at once.
- **Dev is decoupled from deploy.** Shipping a new version is a deliberate step
  (`./install.sh`, or a tagged release) — never a live edit. Your in-progress
  work can never take down the running tool.
- **Green before proposed.** Every change must pass `make check` (shellcheck with
  zero warnings + all bats tests) locally. CI re-runs it on macOS and Linux. A
  red PR is not done.
- **Deterministic tests only.** No test may need the network, the box, the SMB
  mount, or an interactive TTY. Use `WT_BACKEND=1` + `WT_HOME=<tmp>` and the
  helpers in `test/helper.bash` (a local bare repo stands in for `origin`).
  Randomness (`RANDOM` city picker) must not affect assertions.
- **Behavior-preserving refactors stay behavior-preserving.** If you restructure,
  prove it with the golden test (`test/help.bats`) and the backend lifecycle
  tests. Intended output changes get their own visible commit + updated golden.
- **Follow the plan; honor the locked decisions.** See `WT-PLAN.md` in the Agents
  store (or the linked issue). Milestones run M0→M1→M2→…; don't implement
  anti-goals; don't reopen locked decisions. If a decision looks wrong, flag it
  in the PR — don't silently diverge.
- **Never run teardown against the live store while developing.** Exercise
  `archive` / `remove` / `clean` only against test fixtures or your own local
  `~/.wt`, never `/Volumes/wt`.
- **Small, reviewable PRs** — one milestone slice each, with its tests.

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
lib/config.sh       defaults, wt.conf overrides, role (ON_MAC) + paths (ROOT/REPOS/WORK)
lib/palette.sh      colors + ok/warn/err/die/banner
lib/ui.sh           logo, help, gum helpers, progress bar/spinner
lib/backend.sh      cmd_* git verbs — operate on $ROOT via `git -C`
lib/frontend.sh     mac_* interactive UX + _bx (ssh transport to the box)
test/               bats tests + golden fixtures
```

## Test seams (added in M0, default to legacy behavior)

- `WT_BACKEND=1` — force the backend role on any OS (frontend is macOS otherwise).
- `WT_HOME=<dir>` — override the data root (default: the mount / box root).
- `WT_COLOR=0/1` — force color off/on regardless of TTY.
