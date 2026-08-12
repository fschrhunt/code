# Contributing to Workframe

Workframe is a small local Git-worktree allocator. Contributions should make
its core workflow safer or clearer—not turn it into a remote-store, agent, or
editor platform.

## Before changing code

Read [AGENTS.md](AGENTS.md). It is the working contract for humans and coding
agents. In particular, Workframe manages only branches marked in
`refs/workframe/managed/*`; it must never infer ownership from a compatible
worktree path, branch name, or Conductor configuration.

## Development

```bash
make lint
make test
make check
bin/workframe help
```

`make check` is required for code changes. The Bats suite is hermetic: use the
fixtures in `test/helper.bash`, never a network, mounted volume, terminal,
editor, or live store.

## Change design

- Keep the public model small: a store location, canonical repositories, and
  task identities written as `repo/task`.
- City names are collision-free directory labels, not user-facing identifiers.
- Keep lifecycle behavior explicit and test each safety boundary directly.
- Do not add remote stores, SSH, mounts, editor launch, shell hooks, dashboards,
  self-update, or agent orchestration.
- Update help, `test/golden/help.txt`, focused tests, and documentation with a
  user-visible command change.
- Add entries only under `## [Unreleased]` in `CHANGELOG.md`; do not edit a
  released version section.

## Pull requests

Keep a PR focused and explain the problem before the implementation. Include
validation and any intentional behavior change. Do not include secrets, private
infrastructure, generated local state, or Conductor application state.
