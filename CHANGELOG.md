# Changelog

Notable changes to Workframe are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## Unreleased

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

## 1.5.0

Workframe 1.5.0 is the clean-start product release. See the
[full release notes](docs/releases/1.5.0.md).
