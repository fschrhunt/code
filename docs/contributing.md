# Contributing

Workframe is a pure Bash CLI. There is no build server or application runtime;
the development loop is edit, lint, test, and exercise the CLI.

Read [`AGENTS.md`](../AGENTS.md) first. It is the source of truth for safety,
test, and issue workflow.

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
| Agent identities and editor opening | `lib/agents.sh` |
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
| `WORKFRAME_AGENT=<name>` | Select an agent without a prompt |

Tests create local bare origins and canonical clones. They must not use a
network, mounted share, live store, or interactive terminal.

## Adding or changing behavior

1. Start with a `DEV-*` issue in Todo or In Progress.
2. Confirm Why and Acceptance are complete.
3. Add or update deterministic tests.
4. Change the smallest relevant module.
5. Update help, golden output, and public docs when the interface changes.
6. Run `make check`.
7. Open one reviewable PR with `Fixes DEV-<id>`.

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

The [documentation index](README.md) shows the intended information
architecture.
