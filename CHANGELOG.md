# Changelog

Notable changes to Workframe are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## Unreleased

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
