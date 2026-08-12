# Changelog

Notable changes to Workframe are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## 2.0.1

### Changed

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
