# Development rules

## Product boundary

Code is a small local CLI for normal repository checkouts beneath
`repos/<repo>` and isolated task worktrees beneath `worktrees/<repo>/<task>`. Its complete
job is to select a root, clone repositories, create task worktrees, list them,
remove them safely, and diagnose local Git metadata.

Do not add agent orchestration, remote stores, SSH, mounting, editor launch,
shell hooks, dashboards, branch deletion, archive state, migration state,
package-management behavior, or automatic Git synchronization.

## Safety

- Work only in an isolated Git worktree and preserve unrelated changes.
- Repository checkouts beneath `repos/` are task bases, not agent editing locations.
  When started in one, run `code new <repo> [task]` and continue only in
  the exact returned path before changing files.
- Never create task directories manually or place them at the collection root.
- A task worktree is owned only when its private Git administrative directory
  carries the Code marker.
- A path, name, branch, or Git worktree record alone is not ownership.
- Never remove an unmarked checkout or any checkout outside
  `<root>/worktrees/<repo>/`.
- Never discard dirty work unless `--force` is explicit.
- Never delete repository checkouts or branches.
- Add a focused Bats test for every destructive behavior or safety boundary.

## Code quality

- Prefer direct Bash functions over abstractions or modules.
- Use quoted variables and `git -C`; never depend on the caller's directory.
- Treat ShellCheck warnings and infos as failures.
- Do not add compatibility aliases unless explicitly requested.
- Update help, its golden fixture, focused tests, and docs together.
- Keep comments concise and focused on purpose or safety contracts.

## Validation

```bash
make lint
make test
make check
bin/code help
```

Tests must use disposable roots and local Git fixtures. They must not require a
network, terminal, editor, or live collection.

## Git and releases

- Stage only explicit files changed for the task; never use `git add .` or
  `git add -A`.
- Do not reset, clean, stash, force-push, or bypass hooks.
- Use `feat:`, `fix:`, `docs:`, `test:`, or `chore:` commit prefixes.
- Add future-facing changes only under `## [Unreleased]` in `CHANGELOG.md`.
- Do not bump `VERSION`, tag, or publish without an explicit release request.
