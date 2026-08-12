# Workspace lifecycle

```bash
workframe new repo feature-name
workframe list
workframe archive repo/feature-name --yes
workframe restore repo feature-name
workframe remove branch repo feature-name --yes
```

`new` creates `feature-name` from the canonical repository’s default branch and
adds a worktree below `workspaces/repo/<city>`. Archive removes that worktree
but retains the branch; restore creates a new city directory for the branch.

`--force` is required to archive dirty work. Removing a branch or canonical
repository is permanent and requires `--yes` outside an interactive terminal.

For a pre-cutover agent-scoped store, first run `workframe migrate` to inspect
the exact moves and branch renames, then add `--yes` only when it has no
conflicts. The migration never changes remotes or Conductor state.
