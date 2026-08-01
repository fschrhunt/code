# Troubleshooting

Start with:

```bash
workframe status
workframe doctor
```

`status` is fast. `doctor` explains missing configuration, connectivity,
mount, repository, worktree, agent, and editor dependencies.

## Command not found

Check the installed links — `workframe` and `wf` point at the same executable:

```bash
readlink ~/.local/bin/workframe
readlink ~/.local/bin/wf
```

Reinstall from the intended checkout:

```bash
./install.sh
```

Ensure the installation directory is on `PATH`.

## Update refuses the checkout

`workframe update` only moves a clean Git checkout onto commits published on
the remote's stable `main` branch. It automatically recovers a deleted
pull-request branch when the installed program tree exactly matches published
history. In the checkout reported by `readlink ~/.local/bin/workframe`, commit
or stash local changes, switch away from a detached HEAD, or reconcile
unpublished commits before rerunning:

```bash
workframe update
```

Updating never repairs or maintains the Workframe store. Run `workframe sync`,
`workframe doctor`, or `workframe setup` explicitly when those operations are
needed.

## No agents configured

```bash
workframe agents add codex
workframe agents list
```

Automation must pass a configured identity through `--agent` or
`WORKFRAME_AGENT`.

## Repository not found

List managed canonicals:

```bash
workframe repos
```

Then clone:

```bash
workframe clone owner/repo
```

Bare names require `default_org`; full `owner/repo`, URL, and local path forms
do not.

## Branch is already active

Run:

```bash
workframe list
```

Open the reported workspace instead of creating another worktree for the same
branch.

## Branch is archived

```bash
workframe list archived
workframe restore repo agent/feature
```

`new` intentionally refuses to recreate a branch that should be restored.

## Archive refuses dirty work

Commit, stash, or otherwise preserve the changes. If discarding them is
intentional:

```bash
workframe archive <selector> --yes --force
```

`--yes` alone confirms the operation; it never authorizes data loss.

## Shared profile is incomplete

```bash
workframe config
```

Confirm `box_host`, `box_user`, `box_root`, and `mount_path`. Then rerun
`workframe doctor`.

## Mount is down

Use the configured platform mount process or:

```bash
contrib/mount-workframe.sh
```

The helper requires the share, user, mount path, and server values in
`system/config/workframe.conf` or their `WORKFRAME_*` overrides.

## Sync skips a repository

Workframe will not fast-forward a dirty or diverged canonical. Inspect it:

```bash
git -C ~/workframe/repos/<repo> status
git -C ~/workframe/repos/<repo> log --oneline --decorate --graph --all -20
```

Resolve the Git state manually, then run `workframe sync <repo>` again.

## Tests fail during setup

The hermetic test origins use `main`. Confirm:

```bash
git config --global init.defaultBranch main
make check
```

Tests should not require network, SMB, SSH, or a live store.
