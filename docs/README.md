# Workframe documentation

Workframe is a local Git-worktree allocator. A store has one canonical clone
per repository in `repos/` and owned task worktrees in `workspaces/`. Tasks are
always addressed as `repo/task`.

## Use Workframe

- [Getting started](getting-started.md) — install, configure a store, and create
  a task workspace.
- [Concepts](concepts.md) — the store model and ownership boundary.
- [Workspace lifecycle](guides/workspace-lifecycle.md) — pause, resume, remove,
  and migrate work.

## Reference

- [CLI reference](reference/cli.md)
- [Automation reference](reference/automation.md)
- [Filesystem reference](reference/filesystem.md)

## Project

- [Contributing](../CONTRIBUTING.md)
- [Security policy](../SECURITY.md)
- [Release procedure](releasing.md)

The checksum-verified direct installer is the supported installation path.
Workframe has no shared-store, SSH, mount, editor, dashboard, shell-integration,
self-update, or package-management mode.
