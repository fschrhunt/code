# Contributing

Workframe is a pure Bash CLI. There is no build server or application runtime;
the development loop is edit, lint, test, and exercise the CLI.

By participating, you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities through the
private channel in [SECURITY.md](SECURITY.md), never through a public issue.

## Requirements

- Bash
- Git
- ShellCheck
- Bats
- Optional: `gum`

## Commands

```bash
make check
make lint
make test
bin/workframe help
```

`make check` must pass before a PR is proposed.

## Code map

| Area | Location |
|---|---|
| Entry and dispatch | `bin/workframe` |
| Defaults, config, profile paths | `lib/config.sh` |
| Backend Git lifecycle | `lib/backend.sh` |
| User-facing frontend | `lib/frontend.sh` |
| Editor launch helper | `lib/editor.sh` |
| Help, selectors, and progress UI | `lib/ui.sh` |
| Colors and messages | `lib/palette.sh` |
| Optional shared mount helper | `contrib/mount-workframe.sh` |
| Hermetic tests and golden output | `test/` |

## Test seams

| Variable | Use |
|---|---|
| `WORKFRAME_BACKEND=1` | Run internal store verbs without SSH |
| `WORKFRAME_HOME=<tmp>` | Isolate config, repos, and workspaces |
| `WORKFRAME_COLOR=0` | Stabilize output |

Tests create local bare origins and canonical clones. They must not use a
network, mounted share, live store, or interactive terminal.

## Adding or changing behavior

1. Search existing GitHub issues and open one when the change needs discussion.
2. Fork the repository and create a focused branch from `main`.
3. Add or update deterministic tests.
4. Change the smallest relevant module.
5. Update help, golden output, and public docs when the interface changes.
6. Run `make check`.
7. Open one reviewable PR and link the issue with `Fixes #<number>` when it
   completes the issue.

Small documentation and typo fixes may be proposed directly without an issue.
Maintainers may track roadmap work in private planning tools, but contributors
never need access to those systems.

## Destructive paths

Exercise `archive`, `remove`, and `clean` only against Bats fixtures or a
personal disposable store. Never modify the live shared executable or store
during development.

## Documentation standard

Documentation is public and task-oriented:

- Lead with the outcome.
- Use commands verified against the current CLI.
- Link related concepts and next steps.
- Keep infrastructure examples generic.
- Never commit secrets, credentials, private addresses, or organization data.

The [documentation index](docs/README.md) shows the intended information
architecture.

## License

By submitting a contribution, you agree that it will be licensed under the
[Apache License 2.0](LICENSE).
