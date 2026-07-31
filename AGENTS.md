# AGENTS.md — contract for any coding agent working on `workframe`

This file is the single source of build/test/run truth. Contributors and coding
agents follow it so work stays compatible and safe.

## Golden rules

- **Never edit a live deploy.** Do not patch any installed or mounted
  `$BOX_ROOT/system/bin/workframe` in place. All work happens in **this repo**,
  on a branch, via PR. Shipping is a deliberate install/release step.
- **Dev is decoupled from deploy.** In-progress work must not take down a
  running fleet tool.
- **Green before proposed.** Every change must pass `make check` (shellcheck with
  zero warnings + all bats tests) locally. CI re-runs it on macOS and Linux. A
  red PR is not done.
- **Deterministic tests only.** No test may need the network, a remote box, an SMB
  mount, or an interactive TTY. Use `WORKFRAME_BACKEND=1` + `WORKFRAME_HOME=<tmp>` and the
  helpers in `test/helper.bash` (a local bare repo stands in for `origin`).
  Randomness (`_pick_city` / `$RANDOM`) must not affect assertions.
- **Behavior-preserving refactors stay behavior-preserving.** If you restructure,
  prove it with the golden test (`test/help.bats`) and the backend lifecycle
  tests. Intended output changes get their own visible commit + updated golden.
- **Never run teardown against a live shared store while developing.** Exercise
  `archive` / `remove` / `clean` only against test fixtures or your own local
  `~/workframe`.
- **Small, reviewable PRs** — one milestone slice each, with its tests.
- **No fleet secrets in the repo.** Hostnames, Tailscale IPs, org names, and
  mount paths belong in the selected store's `system/config/workframe.conf`
  (or a private deploy), not in shipped defaults.

## Status

Workframe 1.5.0 is the current clean-start product surface:

- CLI: `workframe`
- Local root: `~/workframe`
- Profiles: `local|shared`

The current tracked issue and user request are the scope boundary. Internal
maintainer work is tracked in Linear; an existing GitHub issue may define scope
only when it came from a consumer or community contributor. Do not infer roadmap
work from historical milestones or completed issues.

## Build / test / run

```
make check      # lint + test (run this before every PR)
make lint       # shellcheck entry, installer, libraries, and mount helper
make test       # bats -r test
bin/workframe help
./install.sh    # symlink bin/workframe into ~/.local/bin
```

Requirements: `bash`, `git`, `shellcheck`, `bats`. `gum` is optional (pretty UI;
plain fallback otherwise).

## Layout

```
bin/workframe              entry point: resolves lib/, sources modules, dispatches
lib/config.sh       defaults, system/config/workframe.conf, role + paths
lib/cities.txt      world place-name slugs for worktree folder labels (~4.5k)
lib/palette.sh      colors + ok/warn/err/die/banner
lib/ui.sh           logo, help, gum helpers, progress bar/spinner
lib/backend.sh      cmd_* git verbs — operate on $ROOT via `git -C` (+ city picker)
lib/frontend.sh     mac_* interactive UX + _bx (SSH for shared; in-process for local)
lib/agents.sh       managed agent list + editor open
contrib/            optional helpers (e.g. mount-workframe.sh) — not required for local
docs/               guides — start at docs/README.md
test/               bats tests + golden fixtures
```

## Prompting

Gate every prompt on `_interactive` (stdin + stderr), never on `[ -t 1 ]`.
Prompt helpers render to stderr and their results are routinely captured with
`$(…)`, which makes stdout a pipe in a fully interactive session — gating on
stdout silently turns the wizard into its non-interactive error path. Checks
that guard *rendering to stdout* (progress bar, spinner, cursor control) still
use `[ -t 1 ]`.

## Test seams

- `WORKFRAME_BACKEND=1` — force the backend role on any OS (frontend is the default CLI).
- `WORKFRAME_HOME=<dir>` — override the data root (and read
  `$WORKFRAME_HOME/system/config/workframe.conf`).
- `WORKFRAME_COLOR=0/1` — force color off/on regardless of TTY.
- `WORKFRAME_AGENT=<name>` — non-interactive agent for `workframe new` (must be in `agents=`).

## Cursor Cloud specific instructions

- This is a pure Bash CLI; there is no build/dev server. "Run it" = `bin/workframe help`
  (or any subcommand). Standard commands live in `## Build / test / run` above.
- Dev tools (`shellcheck`, `bats`) install from apt and are refreshed by the
  startup update script; no per-session install is needed.
- Git default branch **must** be `main` for the bats suite to pass. The tests
  (`test/helper.bash` `_seed_repo`) seed a `main` branch, but `git init --bare`
  uses `init.defaultBranch`; if that is `master` the bare origin's HEAD dangles
  and every backend test fails at setup with "remote HEAD refers to nonexistent
  ref". Setup already ran `git config --global init.defaultBranch main`.
- `make lint` uses `.shellcheckrc`; `SC2015` on the `[ $# -gt 0 ] && shift || true`
  dispatch line in `bin/workframe` is disabled there (intentional no-arg shift). Do not
  "fix" that line as part of env setup.
- The user-facing CLI is the frontend on any OS. Store verbs (positional
  `new <agent> <repo> <feature>`, …) require `WORKFRAME_BACKEND=1` (tests + SSH box).
  To exercise the backend end-to-end without SSH/mount: set `WORKFRAME_BACKEND=1` +
  `WORKFRAME_COLOR` + a throwaway `WORKFRAME_HOME`, seed a store the way `test/helper.bash`
  `_seed_repo` does (bare origin + clone into `$WORKFRAME_HOME/repos/<name>`), then
  use `workframe new <agent> <repo> <feature>`, `workframe list`, `workframe archive <workspace>`,
  `workframe restore <repo> <branch>`.

## Tracking + multi-agent loop

1. Planned internal maintainer work starts from a Linear issue with a clear
   problem and acceptance criteria. Never create a GitHub issue for internal
   tracking. GitHub Issues are reserved for issues submitted by consumers or
   community contributors. Tiny documentation fixes and automated dependency
   updates are exceptions.
2. Keep one agent on an issue unless a maintainer explicitly splits the work.
3. Use an isolated branch/worktree for implementation.
4. Keep the PR focused. Use `Fixes #<number>` only when it completes an existing
   consumer/community GitHub issue; do not expose private Linear details in
   public PRs.
5. Treat review comments as feedback on the PR. Open a follow-up issue only for
   durable work that does not belong in the current change, using Linear for
   internal work.
6. Never expose secrets, private infrastructure, customer data, or local agent
   state in issues, commits, logs, or PRs.

Linear is the source of truth for internal maintainer planning. Public
contributors need only GitHub access and may use GitHub Issues for consumer or
community reports; Linear is not part of the public contribution contract.
