# Workframe documentation

Workframe is a local Git worktree allocator. It intentionally has one model:
canonical repositories live in `repos/`; owned task worktrees live in
`workspaces/`; tasks are addressed as `repo/task`.

- [Getting started](getting-started.md)
- [Concepts and the Conductor boundary](concepts.md)
- [Workspace lifecycle](guides/workspace-lifecycle.md)
- [CLI reference](reference/cli.md)
- [Automation reference](reference/automation.md)
- [Filesystem reference](reference/filesystem.md)

The Homebrew formula is the supported package. Workframe has no shared-store,
SSH, mount, editor, dashboard, or shell-integration mode.
