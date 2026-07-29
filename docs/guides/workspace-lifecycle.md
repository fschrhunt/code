# Workspace lifecycle

This guide follows a piece of work from repository setup through safe cleanup.

## Add a repository

```bash
workframe clone owner/repo
```

`clone` also accepts a full Git URL or local path. A bare repository name works
when `default_org` is configured.

The canonical clone is stored under `repos/<repo>`.

## Start work

```bash
workframe new repo feature-name --agent codex
```

Workframe:

1. Confirms the repository and agent exist.
2. Creates `codex/feature-name` from the canonical default branch.
3. Chooses an unused city label.
4. Adds the worktree below `workspaces/codex/repo/<city>`.
5. Prints the workspace, branch, and city.

If the branch is already active, Workframe reports its current path. If it is
archived, Workframe points to `restore`.

## Locate and open work

```bash
workframe list
workframe ide <selector>
workframe cd <selector>
```

`ide` opens a new editor window. `cd` prints the resolved path so scripts can
use:

```bash
cd "$(workframe cd repo/feature-name)"
```

Run `workframe setup` or `workframe config` interactively to offer installation
of the shell wrapper that makes `workframe cd` change the current shell.

## Rename a branch

```bash
workframe rename <selector> new-feature-name
```

The agent namespace remains unchanged. Only the feature portion is replaced.

## Archive work

```bash
workframe archive <selector> --yes
```

Archive removes the worktree and keeps its branch. Without `--yes`, Workframe
asks for confirmation in an interactive terminal.

Dirty work is protected. `--yes` confirms the archive but does not authorize
discarding changes:

```bash
workframe archive <selector> --yes --force
```

Use `--force` only when losing uncommitted changes is intentional.

## Inspect archived work

```bash
workframe list archived
```

The `archived` command remains available as a convenience alias, but
`workframe list archived` is the preferred form.

## Restore work

```bash
workframe restore repo codex/feature-name
```

Restore creates a new city folder for the existing branch and prints the new
workspace path.

## Synchronize canonicals

```bash
workframe sync
workframe sync repo
```

Workframe fetches canonicals and fast-forwards a clean repository when it is
only behind its default branch. Dirty or diverged canonicals are left alone.

## Clean orphans

```bash
workframe clean
workframe clean --yes
```

`clean` is a dry run. It reports safe orphan candidates and skips worktrees
with local changes or unpushed commits. `--yes` applies the safe removals.

## Permanent removal

Delete an archived branch:

```bash
workframe remove branch repo codex/feature-name --yes
```

Delete a canonical repository:

```bash
workframe remove repo repo --yes
```

Workframe refuses repository deletion while managed worktrees or risky state
remain. `--force` broadens deletion authority and should be used only after
reviewing `workframe status` and `workframe doctor`.

See the [CLI reference](../reference/cli.md) for exact forms and
[troubleshooting](../troubleshooting.md) for recovery paths.
