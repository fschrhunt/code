# Changelog

Notable changes to Code are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- The repository README is now a plain-text `README` file whose reference
  section uses direct URLs, matching the other repositories in the collection.

## 0.0.1

First release of the restarted project. The version history restarts here.

### Added

- `setup` initializes or upgrades a collection to `README.md`, `repos/`, and
  `worktrees/`, with a terminal wizard and `--root`/`--yes` for unattended use.
- `clone` creates base checkouts at `repos/<repo>` from `owner/repo`, a Git
  URL, or a local path.
- `new <agent>` creates a flat agent worktree named `worktrees/<agent>-<repo>`
  from a base checkout's current `HEAD`, suffixing `-1`, `-2`, ... when the
  name is occupied and reattaching an inactive branch of the same name.
- `list` shows repositories and managed worktrees; `remove` deletes a marked
  worktree by branch name, `repo/branch`, or path while keeping its branch.
- `doctor` and `root` report collection health and the selected root.
