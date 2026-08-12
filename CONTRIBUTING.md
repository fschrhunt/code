# Contributing to Workspaces

Workspaces is intentionally small: normal Git repositories at the collection
root and optional sibling worktrees for isolated tasks. Contributions should
make that workflow safer or clearer rather than turn it into an agent, editor,
or repository-management platform.

## Development

```bash
make lint
make test
make check
bin/workspaces help
```

The Bats suite is hermetic. Use the local Git fixtures in `test/helper.bash` and
never test destructive behavior against a live collection.

## Design rules

- Keep normal repository checkouts directly usable.
- Keep task worktrees visible as named siblings.
- Prove ownership with the worktree-specific marker before removal.
- Never delete repositories or branches.
- Keep Git operations native when the CLI adds no safety or clarity.
- Update help, `test/golden/help.txt`, focused tests, and documentation with a
  user-visible command change.
- Add entries only under `## [Unreleased]` in `CHANGELOG.md`; released sections
  are historical records.

Read [AGENTS.md](AGENTS.md) for the complete development and safety contract.

## Pull requests

Explain the user problem first, then the solution and validation. Do not include
credentials, private infrastructure, or generated local state.
