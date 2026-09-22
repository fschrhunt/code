# Development rules

Code is a small Bash wrapper over Git checkouts and worktrees. Keep it small.

## Scope

- `bin/code` is the whole tool. There is no daemon, index, or configuration.
- Do not add commands, flags, or state beyond what a task needs.

## Safety

- Work in a worktree; never edit a base checkout under `repos/`.
- `code remove` must refuse paths outside `<root>/worktrees/`.
- Never delete branches or repositories. `remove` keeps the branch.
- Do not discard dirty work unless `--force` is explicit.

## Code quality

- Prefer direct Bash over abstractions.
- Quote variables; use `git -C` and never depend on the caller's directory.
- Treat ShellCheck warnings as failures.
- Update `bin/code` help, `test/golden/help.txt`, tests, and `README` together.
- Add a focused Bats test for each behavior worth protecting.

## Validation

```bash
make lint
make test
make check
bin/code help
```

Tests use disposable roots and local Git fixtures. They never touch the network
or a live collection.

## Git

- Stage explicit files only; never `git add .` or `git add -A`.
- Do not reset, clean, stash, or force-push.
- Use `feat:`, `fix:`, `docs:`, `test:`, or `chore:` prefixes.
- Add changes under `## [Unreleased]` in `CHANGELOG.md`.
- Do not bump `VERSION`, tag, or publish without a release request.
