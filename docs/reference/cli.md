# CLI reference

All commands use the user-facing frontend. Internal backend syntax is reserved
for tests and shared-store execution through `WORKFRAME_BACKEND=1`.

## Global forms

```text
workframe
workframe help
workframe version
```

Bare `workframe`, `-h`, and `--help` print help. `-v` and `--version` print the
version.

## Initialization and configuration

### `init`

```text
workframe init [--local|--shared]
```

Creates or updates the selected profile. Local is the default. Initialization
also provisions the store-level `WORKFRAME.md` when it is missing; an existing file
is never overwritten.

### `config`

```text
workframe config
```

Interactively changes editor, organization shortcut, agent identities,
profile, and shared connection settings.

### `agents`

```text
workframe agents [list]
workframe agents add <name>
workframe agents remove <name>
```

Lists and manages branch identity namespaces.

## Repositories and workspaces

### `clone`

```text
workframe clone <owner/repo|url|path>
```

Adds a canonical repository to the store.

### `new`

```text
workframe new <repo> <feature> [--agent <name>]
```

Creates an isolated worktree and `<agent>/<feature>` branch.

### `rename`

```text
workframe rename <selector> <new-feature>
```

Renames the current branch while retaining its agent namespace.

### `ide`

```text
workframe ide [<selector>]
workframe open [<selector>]
```

Opens a worktree in the configured editor.

### `cd`

```text
workframe cd [<selector>]
```

Prints the selected worktree path. Shell integration can turn this into a
current-shell directory change.

### `list`

```text
workframe list
workframe list archived
```

Lists active worktrees or archived branches.

### `repos` and `worktrees`

```text
workframe repos
workframe worktrees
```

Print machine-friendly repository names or tab-separated active-worktree
records. These are useful for diagnostics and scripts.

### `archive`

```text
workframe archive <worktree|repo/feature|city> [--yes] [--force]
```

Removes the worktree while keeping its branch. `--yes` answers the confirmation
prompt. `--force` additionally permits discarding dirty work.

### `restore`

```text
workframe restore <repo> <branch>
```

Recreates a worktree for an archived branch.

## Maintenance

### `sync`

```text
workframe sync [<repo>]
```

Fetches canonicals and safely fast-forwards clean repositories.

### `status`

```text
workframe status
```

Prints a quick store summary.

### `doctor`

```text
workframe doctor
```

Runs deeper profile, connection, mount, repository, worktree, agent, and editor
checks.

### `clean`

```text
workframe clean [--yes]
```

Finds safe orphan cleanup candidates. The default is a dry run; `--yes`
applies removals.

### `update`

```text
workframe update
```

Fast-forwards the tracked branch of the Git checkout that provides the
installed CLI. The update refuses dirty checkouts, detached HEADs, branches
without an upstream, and non-fast-forward changes so local work is never
discarded.

For shared profiles, a successful CLI update also refreshes mount state, syncs
canonicals, and runs health checks.

## Permanent removal

### `remove branch`

```text
workframe remove branch <repo> <branch> [--yes]
```

Permanently deletes an archived branch. Active branches must be archived first.

### `remove repo`

```text
workframe remove repo <repo> [--force] [--yes]
```

Deletes a canonical clone. Workframe refuses unsafe state unless the explicit
force path is used.

## Selectors and automation

Commands accepting `<selector>` support an exact workspace path,
`repo/feature`, or city label. Interactive selection is available when a TTY
and `gum` are present.

Automation should set `WORKFRAME_AGENT`, `WORKFRAME_HOME`, and
`WORKFRAME_COLOR` as needed. See the
[configuration reference](configuration.md).
