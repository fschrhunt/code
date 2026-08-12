# Changelog

Notable changes to Workspaces are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## 4.1.0

### Added

- Make `setup` upgrade pre-4.0 collections by moving root-level base checkouts
  into `repos/` and repairing live linked worktrees. Setup preflights every
  destination and rolls completed moves back if repair fails.
- Warn from `list` and `doctor` when a collection still needs `ws setup`.

### Changed

- Refresh Workspaces-generated collection guides during setup while preserving
  custom README content, and direct newly installed releases to `ws setup`.

### Fixed

- Refuse symlinked collection directories and collection README symlinks instead
  of following them during setup.

## 4.0.0

### Breaking changes

- Base repository checkouts now live at `<root>/repos/<repo>` instead of
  `<root>/<repo>`, leaving only `README.md`, `repos/`, and `worktrees/` at the
  collection root. Existing checkouts are not moved automatically. Remove task
  worktrees before moving a base checkout, or repair each retained task after
  the move with `git -C <root>/repos/<repo> worktree repair <task-path>`.

### Added

- Make the task argument to `new` optional. When omitted, Workspaces chooses an
  unused world capital for both the task folder and branch.
- Install `ws` as a short alias for the `workspaces` command, including shell
  completion support.

### Changed

- Rewrote the project and generated collection READMEs around the directory
  model, first task workflow, command reference, and removal safety contract.

## 3.0.1

### Changed

- Group task worktrees beneath `<root>/worktrees/<repo>/<task>` while keeping
  normal repository checkouts at the collection root.
- Expanded the collection README with the required task workflow for people and
  automated coding sessions.

## 3.0.0

### Breaking changes

- Replaced Workframe with the `workspaces` command and the default
  `~/workspaces` collection. The retired command, alias, environment variables,
  private refs, and store layout are not migrated automatically.
- Normal repository checkouts now live directly at `<root>/<repo>`. Task
  worktrees are visible siblings named `<repo>-<task>`; `repos/`, nested
  `workspaces/`, `system/`, and generated city directories have been removed.
- Reduced the public CLI to `setup`, `clone`, `new`, `list`, `remove`, `root`,
  and `doctor`. Git remains responsible for fetching, branch deletion, and other
  repository operations.

### Changed

- Attached ownership to each task worktree's private Git directory so branch
  renames and `git worktree move` do not break lifecycle safety.
- Replaced the store contract with a short, human-facing `README.md`.

## 2.0.2

### Added

- `sync <repo>` and `sync --all` to refresh canonical repositories and
  fast-forward only clean, non-diverged checkouts.
- `update` to rerun the checksum-verified Workframe release installer without
  changing a configured store.

### Changed

- Made terminal output inherit the user's foreground and background instead of
  forcing white; data output remains plain.

### Fixed

- Isolated Bats' selected-store pointer under its temporary configuration
  directory so test setup cannot overwrite a user's configured Workframe root.

## 2.0.1
- Made `new` refresh the repository's default branch before creating a task and
  refuse stale work if it cannot fetch; `--offline` explicitly uses the cached
  remote ref for disconnected work.
- Replaced the favicon with the square monochrome frame and restored its 16%
  rounded corners.
- Made `new` emit only its workspace path and removed Git's worktree chatter,
  so `cd "$(workframe new <repo> <task>)"` enters the new workspace cleanly.
- Relicensed Workframe under MIT and removed the Code of Conduct from the
  repository's community files.
- Reorganized the documentation around task workflows, references, and project
  policies; simplified the store-local `WORKFRAME.md` guide for humans and
  coding agents.

## 2.0.0

### Breaking changes

- Task workspaces and branches no longer include an agent identity. Run
  `workframe migrate` first to preview conversion of a legacy store, then
  `workframe migrate --yes` to apply it. Agent commands and `workframe help
  --agent` have been removed.

### Fixed

- Isolated Bats' selected-store pointer under its temporary configuration
  directory so test setup cannot overwrite a user's configured Workframe root.

### Added

- A checksum-verified direct installer at `scripts/install.sh` for the latest
  GitHub release, alongside the checkout linker.
- A manually dispatched, protected release workflow that validates the version
  and changelog, runs the complete check suite, then tags and publishes a
  GitHub release. Merges to `main` remain CI-only.
- Workframe records ownership of every branch it creates or migrates in a
  private Git ref. Lifecycle commands list, archive, restore, and delete only
  those owned branches, so compatible Conductor worktrees are left alone.

### Removed

- Homebrew distribution. The verified direct installer is now the only
  supported installation path.

### Changed

- Replaced the Workframe mark and reduced the visual system to ink (`#09090B`)
  and white (`#FFFFFF`). Removed the legacy wordmark, lockups, tiles, PNG
  exports, and lifecycle diagrams.
- Simplified the README to the essential install, workflow, and ownership model.

## 1.5.3

- Workframe is CLI-only. The native macOS menubar companion, Homebrew cask,
  app assets, and app-release automation have been removed. Homebrew users
  install and upgrade the `workframe` formula.

- **Data loss fixed:** `workframe remove repo` deleted worktrees that lived
  outside the store. A clean, fully pushed worktree added by hand elsewhere was
  removed with `rm -rf` and no warning. Workframe now only deletes worktrees
  under `workspaces/`; `remove repo` refuses when others exist, and `--force`
  deletes the repository while leaving their files in place.
- **Store containment fixed:** an agent could be named `.` or `..`, which made
  `workframe new` create directories outside `workspaces/`. Agent names now
  follow the same rules as repository names, and the check is applied wherever
  a name is used, so a hand-edited config cannot reintroduce it.
- Feature names are validated. `workframe new <repo> "   "` previously created
  the branch `<agent>/---`, and names git rejects surfaced a raw `fatal:`
  instead of an explanation. Spaces and slashes still work as before.
- Scripts and coding agents now have a discoverable command surface with the
  same capabilities as the wizard. `workframe help --agent` prints the full
  non-interactive catalogue, and the new
  [automation reference](docs/reference/automation.md) documents selectors,
  exit codes, and the safety rules automation must respect. The store's
  `WORKFRAME.md` contract points agents at both.
- Added `workframe path <selector>`, the stable way to resolve a workspace
  directory. The optional shell integration wraps `workframe` so that
  `workframe cd` changes directory instead of printing, which made
  `$(workframe cd …)` empty in scripts; `path` is never intercepted.
- `rename`, `open`, and `cd` now fail with a clear message when given no
  selector and no terminal, instead of a raw prompt-program error and exit 0.
- `workframe clean` and `workframe cd` output ends with a newline.
- Fixed the wizard's **Start a new workspace** action, which always failed with
  a non-interactive usage error. Prompting is now gated on stdin and stderr
  rather than stdout, so a prompt whose result is captured with `$(…)` still
  reaches the terminal.
- `WORKFRAME_COLOR=0` now forces plain output as documented, including when a
  terminal is attached.
- A failed prompt program is no longer mistaken for typed input.
- The first-run "next" hint now names the actual main-menu entries.
- `archive` accepts a worktree path reached through a symlinked store root.
- `workframe sync` output ends with a newline.
- Security and community foundations for the public repository.
- Homebrew installation through `fschrhunt/tap/workframe`.
- Interactive `workframe setup` with persistent custom local roots and
  first-run agent configuration.
- Store configuration now lives under `system/config/workframe.conf`, with
  automatic migration from the former top-level file.
- `workframe update` now updates program files only; store maintenance remains
  under explicit setup, sync, and doctor commands.
- `wf` is installed alongside `workframe` as a short name for the same command,
  including in the optional `cd` shell wrapper.

## 1.5.0

Workframe 1.5.0 is the clean-start product release. See the
[full release notes](docs/releases/1.5.0.md).
