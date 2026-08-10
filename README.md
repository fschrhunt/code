<h1 align="center">
  <img src="assets/lockup/lockup.black-on-acid.svg" alt="Workframe" width="713">
</h1>

<p align="center"><strong>A control plane for isolated agent worktrees.</strong></p>

<p align="center">
  <a href="https://github.com/fschrhunt/workframe/actions/workflows/ci.yml"><img src="https://github.com/fschrhunt/workframe/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue.svg" alt="Apache-2.0 license"></a>
</p>

Workframe turns each piece of work into a dedicated Git worktree, branch, and
folder. Agents can work in parallel without sharing uncommitted state, while
every repository keeps one canonical clone.

```text
one canonical clone
├── codex/payment-retry  → workspaces/codex/api/oslo
├── claude/docs-refresh  → workspaces/claude/api/kyoto
└── cursor/cache-fix     → workspaces/cursor/api/dakar
```

Workframe 1.5.3 is a clean-start release. The command is `workframe` — also
installed as `wf` — product environment variables use `WORKFRAME_*`, and local
state begins at `~/workframe`. It is a command-line tool: run `workframe help`
for the everyday command map, or `workframe help --agent` for the complete
scriptable interface.

## Start in 60 seconds

Requirements: Bash, Git, and macOS or Linux. `gum` is optional.

Install with Homebrew:

```bash
brew install fschrhunt/tap/workframe
```

Or install from a Git checkout:

```bash
git clone https://github.com/fschrhunt/workframe.git
cd workframe
./install.sh
```

Homebrew installations update with `brew upgrade workframe`. Checkout
installations update with `workframe update`.

Then create a store, add a repository, and make a workspace:

```bash
workframe init --agent codex
workframe clone owner/repo
workframe new repo feature-name --agent codex
```

`init` is non-interactive and also supports `--root`, `--editor`, and `--org`;
run
`workframe init --help` for its options. `setup` remains available for profile
configuration, including shared stores. Commands offer terminal prompts only
when safe details are omitted, so the same interface works for people, scripts,
and coding agents.

## The lifecycle

<p align="center">
  <img src="docs/images/workspace-lifecycle.png" alt="Workspace lifecycle: clone a canonical repository, create a task workspace, work on an isolated branch, then archive and resume it or open a pull request and safely remove it." width="713" height="270">
</p>

Workframe separates reversible lifecycle actions from destructive ones:

| Intent | Command | Result |
|---|---|---|
| Start | `workframe new` | Creates a branch and worktree |
| Inspect | `workframe list` | Shows active worktrees |
| Pause | `workframe archive` | Removes the folder, keeps the branch |
| Resume | `workframe restore` | Recreates the worktree |
| Delete branch | `workframe remove branch` | Permanently deletes an archived branch |
| Delete repo | `workframe remove repo` | Deletes the canonical clone when safe |

## Local or shared

<p align="center">
  <img src="docs/images/profile-layout.png" alt="Profile layout: the Workframe command uses either a local profile rooted at ~/workframe or a shared profile using a mounted store and SSH backend; both contain canonical repositories and agent worktrees." width="713" height="340">
</p>

- **Local** is the default. `workframe setup --local` uses `~/workframe` unless
  `--root <absolute-path>` selects another location.
- **Shared** keeps the store on a remote box and exposes worktrees through a
  mounted path. Connection details live in
  `system/config/workframe.conf`, never in the repository.

Every store also receives a non-overwriting `WORKFRAME.md` safety contract for
coding agents and agent launchers. Repository-local instructions remain the
automatically discovered authority for tools that stop at the Git root.

Use `workframe setup --shared` to configure a shared profile.

## Find the right guide

| I want to… | Read |
|---|---|
| Install and create my first workspace | [Getting started](docs/getting-started.md) |
| Understand the store and branch model | [Core concepts](docs/concepts.md) |
| Start, pause, resume, or remove work | [Workspace lifecycle](docs/guides/workspace-lifecycle.md) |
| Choose local or shared operation | [Profiles](docs/guides/profiles.md) |
| Configure agents and editors | [Agents and editors](docs/guides/agents-and-editors.md) |
| Look up a command | [CLI reference](docs/reference/cli.md) |
| Drive Workframe from a script or coding agent | [Automation reference](docs/reference/automation.md) |
| Look up configuration or environment variables | [Configuration reference](docs/reference/configuration.md) |
| Diagnose a problem | [Troubleshooting](docs/troubleshooting.md) |
| Operate or release Workframe | [Operations](docs/operations.md) |
| Contribute safely | [Contributing](CONTRIBUTING.md) |
| Get help | [Support](SUPPORT.md) |
| Report a vulnerability | [Security policy](SECURITY.md) |

The complete guided index lives in [the documentation library](docs/README.md).

## Develop

Workframe is a Bash CLI; there is no application server.

```bash
make check
bin/workframe
```

`make check` runs ShellCheck and the hermetic Bats suite. Tests never require a
network connection, shared mount, remote box, or interactive terminal.

Read [AGENTS.md](AGENTS.md) before changing the product. Version: **1.5.3**.

## Community and license

Workframe welcomes focused issues and pull requests. See
[CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md) before participating. Usage questions
belong in [GitHub Discussions](https://github.com/fschrhunt/workframe/discussions);
security reports must use the private channel in [SECURITY.md](SECURITY.md).

Workframe is licensed under the [Apache License 2.0](LICENSE).
