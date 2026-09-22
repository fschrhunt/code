# Contributing to Code

Code is a thin wrapper over Git: clones live in `repos/<repo>` and worktrees in
`worktrees/<branch>`. Contributions should keep it small.

## Development

```bash
make check
bin/code help
```

`make check` runs ShellCheck and the Bats suite. The suite is hermetic; use the
fixtures in `test/helper.bash` and never test against a live collection.

## Pull requests

Explain the problem first, then the change and how you validated it. See
[AGENTS.md](AGENTS.md) for the development rules.
