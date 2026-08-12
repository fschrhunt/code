# Development rules

## Conversational style

- Keep responses concise, direct, and technical. Do not use emojis or filler.
- Answer a question before editing code.
- Explain non-obvious work as: problem, concrete consequence, solution.
- State agreement or disagreement explicitly when responding to feedback.
- Never expose local paths outside the active worktree, credentials, mounted
  volumes, Conductor application state, or other private operator data.

## Product boundary

Workframe is a local Git-worktree allocator. Its complete job is to configure a
store location, create an owned task workspace, find it, archive it, restore
it, and migrate legacy Workframe stores.

Do not add remote stores, SSH, mounting, editor launch, shell hooks, dashboards,
self-update, package-management behavior, or agent orchestration. A task is
always `repo/task`; generated city names are internal directory labels.

## Safety and ownership

- Work only in an isolated Workframe worktree. Never modify an installed binary
  or a canonical clone under `repos/`.
- Workframe owns only branches recorded in `refs/workframe/managed/*`.
  A path, branch pattern, `.conductor` file, or Git worktree record is never
  proof of Workframe ownership.
- Never make a lifecycle command list, archive, restore, rename, or delete an
  unmarked worktree or branch.
- Do not inspect, parse, or modify Conductor's private application state.
  Workframe proves its own ownership; it does not identify Conductor's.
- Keep destructive actions explicit. A focused Bats test must cover every new
  safety boundary or destructive behavior.

## Code quality

- Read a file completely before making a broad change to it.
- Prefer a direct Bash function over a new abstraction or module. Inline a
  single-use helper unless it clarifies a safety boundary.
- Use quoted variables and `git -C`; never depend on the caller's directory.
- Treat shellcheck warnings and infos as failures. Do not suppress a diagnostic
  without a concise reason next to it.
- Do not add backward compatibility or aliases unless explicitly requested.
- Update command help, the golden fixture, tests, and docs in the same change.

## Tests and commands

```bash
make lint                         # ShellCheck
make test                         # hermetic Bats suite
make check                        # required after code changes
bin/workframe help                # inspect the public CLI
```

- After code changes, run `make check` and fix every failure before handoff.
- Test one changed Bats file while iterating, then run the full suite.
- Tests use `WORKFRAME_BACKEND=1` and `WORKFRAME_HOME=<tmp>` with
  `test/helper.bash`. They must not require a network, terminal, mount, editor,
  remote store, or real Conductor installation.
- Never test destructive commands against a live store.

## Git

Multiple agents can share a repository. Preserve their work.

- Before a commit, inspect `git status` and stage only files changed in this
  session with explicit paths. Never use `git add -A` or `git add .`.
- Never run `git reset --hard`, `git checkout .`, `git clean -fd`, `git stash`,
  or `git commit --no-verify`.
- Do not force-push.
- Commit format: `feat:`, `fix:`, `docs:`, `test:`, or `chore:` followed by a
  short imperative summary.

## Pull requests and releases

- Keep PRs focused. Explain the user problem first, then the solution and
  validation; do not lead with an implementation inventory.
- Use the existing PR when the branch already has one. Do not create duplicates.
- Add future-facing changes under `## [Unreleased]` in `CHANGELOG.md`; released
  sections are immutable. Use `### Added`, `### Changed`, `### Fixed`,
  `### Removed`, and `### Breaking changes` as applicable.
- Do not bump `VERSION`, tag, or publish without an explicit release request.
