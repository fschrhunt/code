# AGENTS.md — contract for any coding agent working on `wt`

This file is the single source of build/test/run truth. Contributors and coding
agents follow it so work stays compatible and safe.

## Golden rules

- **Never edit the live deploy.** Do not patch `/Volumes/Agents/system/bin/wt`
  (or any mounted `$BOX_ROOT/system/bin/wt`) in place. All work happens in
  **this repo**, on a branch, via PR. Shipping is a deliberate install/release
  step (`./install.sh` or a tagged release onto the box).
- **Dev is decoupled from deploy.** In-progress work must not take down a
  running fleet tool.
- **Green before proposed.** Every change must pass `make check` (shellcheck with
  zero warnings + all bats tests) locally. CI re-runs it on macOS and Linux. A
  red PR is not done.
- **Deterministic tests only.** No test may need the network, a remote box, an SMB
  mount, or an interactive TTY. Use `WT_BACKEND=1` + `WT_HOME=<tmp>` and the
  helpers in `test/helper.bash` (a local bare repo stands in for `origin`).
  Randomness (`_pick_city` / `$RANDOM`) must not affect assertions.
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

## Status (milestones)

| Milestone | Linear | Reality |
|-----------|--------|---------|
| **M0** foundation | shipped | Shared/SSH mode + CLI in this repo (`bin/wt`, `lib/*`) |
| **M1** profiles | [DEV-175](https://linear.app/intuitum/issue/DEV-175) | Configurable profiles (schema, selection, multi-profile tests) |
| **M2** local `~/.wt` | [DEV-181](https://linear.app/intuitum/issue/DEV-181) | Local as documented default + shared→local migration notes |

`type = local|shared` already exists in code; M1/M2 harden and productize it.
Do not invent scope beyond the active `DEV-*`.

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
lib/config.sh       defaults, ~/.wt/config, role + paths (ROOT/REPOS/WORK)
lib/cities.txt      world place-name slugs for worktree folder labels (~4.5k)
lib/palette.sh      colors + ok/warn/err/die/banner
lib/ui.sh           logo, help, gum helpers, progress bar/spinner
lib/backend.sh      cmd_* git verbs — operate on $ROOT via `git -C` (+ city picker)
lib/frontend.sh     mac_* interactive UX + _bx (SSH for shared; in-process for local)
lib/agents.sh       managed agent list + editor open
contrib/            optional helpers (e.g. mount-wt.sh) — not required for local
docs/               guides — start at docs/README.md
test/               bats tests + golden fixtures
```

## Test seams

- `WT_BACKEND=1` — force the backend role on any OS (frontend is the default CLI).
- `WT_HOME=<dir>` — override the data root (and read `$WT_HOME/config`).
- `WT_COLOR=0/1` — force color off/on regardless of TTY.
- `WT_AGENT=<name>` — non-interactive agent for `wt new` (must be in `agents=`).

## Cursor Cloud specific instructions

- This is a pure Bash CLI; there is no build/dev server. "Run it" = `bin/wt help`
  (or any subcommand). Standard commands live in `## Build / test / run` above.
- Dev tools (`shellcheck`, `bats`) install from apt and are refreshed by the
  startup update script; no per-session install is needed.
- Git default branch **must** be `main` for the bats suite to pass. The tests
  (`test/helper.bash` `_seed_repo`) seed a `main` branch, but `git init --bare`
  uses `init.defaultBranch`; if that is `master` the bare origin's HEAD dangles
  and every backend test fails at setup with "remote HEAD refers to nonexistent
  ref". Setup already ran `git config --global init.defaultBranch main`.
- `make lint` uses `.shellcheckrc`; `SC2015` on the `[ $# -gt 0 ] && shift || true`
  dispatch line in `bin/wt` is disabled there (intentional no-arg shift). Do not
  "fix" that line as part of env setup.
- The user-facing CLI is the frontend on any OS. Store verbs (positional
  `new <agent> <repo> <feature>`, …) require `WT_BACKEND=1` (tests + SSH box).
  To exercise the backend end-to-end without SSH/mount: set `WT_BACKEND=1` +
  `WT_COLOR` + a throwaway `WT_HOME`, seed a store the way `test/helper.bash`
  `_seed_repo` does (bare origin + clone into `$WT_HOME/repos/<name>`), then
  use `wt new <agent> <repo> <feature>`, `wt list`, `wt archive <workspace>`,
  `wt restore <repo> <branch>`.

## Linear + multi-agent loop

Workspace: [intuitum](https://linear.app/intuitum) · Team **Engineering** (`DEV-*`) ·
Project [wt](https://linear.app/intuitum/project/wt-03565bb5855d).

Source of truth for process:
- [Agent Contract](https://linear.app/intuitum/document/agent-contract-5cca5188b456)
- [Triage Ritual](https://linear.app/intuitum/document/triage-ritual-806f09954c6c)
- [Week-1 Focus](https://linear.app/intuitum/document/week-1-focus-3083713a8662)
- Repo detail: [docs/linear.md](docs/linear.md)

Rules for every agent (Cursor, Claude, Codex, Leo, Devin):

1. No real implementation without a `DEV-*` (tiny drive-bys / Renovate excepted).
2. Fischer stays **assignee**; agents are **delegates** — never silent owners.
3. Issue must have **Why** + **Acceptance** before coding; if missing, stop and
   ask (or file Needs/Clarification) instead of inventing scope.
4. Branch from Linear (`⌘⇧.` / `DEV-XXX` in the name); PR body includes
   `Fixes DEV-XXX` or `Contributes to DEV-XXX`.
5. Greptile reviews the PR — do not open Linear issues for nits unless the
   follow-up is durable (>~30 min).
6. One agent per issue unless Fischer splits into sub-issues; use `wt` when
   paralleling on the same repo.
7. Status: Triage/Backlog = do not start; Todo/In Progress = OK to pick up.
