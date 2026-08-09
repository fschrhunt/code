# CLI reference

Workframe is a command-line control plane for isolated Git worktrees. Run:

```text
workframe help
```

`wf` is a short name for the same executable, so every `wf <command>` behaves
exactly like the `workframe` form below. Commands prompt for omitted safe
details in an interactive terminal; scripts and coding agents should supply
the arguments shown here.

## Start a store and workspace

```bash
workframe init --agent <name>
workframe clone <owner/repo | url | path>
workframe new <repo> <feature> --agent <name>
```

`init` is a non-interactive local bootstrap and creates a neutral `default`
agent when no `--agent` is supplied. `setup` is idempotent. It defaults to a local store at `~/workframe`; use
`--root <absolute-path>`, `--editor <command>`, and `--org <name>` to set
preferences. Use `workframe setup --shared` to configure a shared store.

## Everyday commands

| Intent | Command |
|---|---|
| Show active workspaces | `workframe list` |
| Show archived workspaces | `workframe list archived` |
| Filter active workspaces | `workframe list --agent <name> --repo <name> --dirty` |
| Open a workspace | `workframe open <selector>` |
| Open active work or restore archived work | `workframe resume <selector>` |
| Show the workspace containing the current directory | `workframe current` |
| Print a workspace path | `workframe path <selector>` |
| Run a command in a workspace | `workframe run <selector> -- <command> [args…]` |
| Rename a workspace branch | `workframe rename <selector> <feature>` |
| Pause work and keep its branch | `workframe archive <selector> [--yes] [--force]` |
| Recreate archived work | `workframe restore <repo> <branch>` |
| List canonical repositories | `workframe repos` |
| Update repositories | `workframe sync [<repo> | --all]` |
| Check the store | `workframe status`, `workframe doctor` |
| Get an at-a-glance summary | `workframe dashboard` |

A selector may be a city, `repo/feature`, `agent/feature`,
`agent/repo/city`, or an absolute workspace path. `path` is the stable command
for scripts; optional shell integration may make `workframe cd` change the
current shell directory rather than print a path.

## Configuration and agents

```bash
workframe agents [list | add <name> | remove <name>]
workframe config
workframe update
workframe version
```

`config` is an interactive editor for profile and preference changes. An agent
identity is a Git branch namespace, not a vendor lock-in.

## Permanent operations

```bash
workframe remove branch <repo> <branch> --yes
workframe remove repo <repo> --yes [--force]
workframe clean [--yes]
```

Archive is reversible. Permanent operations require confirmation, and in a
non-interactive session require `--yes`. `--force` is necessary before an
archive or repository removal can discard uncommitted work.

## Output and automation

Use `workframe worktrees` for machine-readable TSV output; `list` is formatted
for people. Set `WORKFRAME_COLOR=0` or `NO_COLOR=1` for plain output.
`WORKFRAME_THEME=light` and `WORKFRAME_THEME=dark` select terminal color
palettes; `auto` is the default.

`list`, `repos`, `worktrees`, `status`, `current`, `archive`, and `restore`
support `--json` where shown in their help text. The JSON interface is emitted
without colors or status decoration. `workframe doctor --fix` performs only
safe local repairs: missing store directories, the non-overwriting
`WORKFRAME.md`, root locator refresh, stale worktree metadata, and relative
worktree configuration.

Shell completion is available without an additional package:

```bash
source <(workframe completion bash)
source <(workframe completion zsh)
workframe completion fish > ~/.config/fish/completions/workframe.fish
```

`workframe help --agent` prints the complete command catalogue, including
automation notes and exit-code conventions. See the
[automation reference](automation.md) for detailed scripting guidance.
