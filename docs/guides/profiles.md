# Local and shared profiles

Profiles decide where Workframe stores repositories and where backend Git
operations execute.

## Choose a profile

| Need | Recommended profile |
|---|---|
| One developer or one machine | Local |
| No SSH or mount dependency | Local |
| Multiple machines share one canonical store | Shared |
| Existing secured box and mounted filesystem | Shared |

Local is the default.

## Local profile

Set up:

```bash
workframe setup
```

Setup offers `~/workframe` by default and can persist any absolute local path.
Store operations run in the same process as the CLI.

```text
~/workframe/
├── WORKFRAME.md
├── repos/
├── workspaces/
└── system/
    ├── config/workframe.conf
    └── logs/
```

`WORKFRAME.md` gives agents and launchers a store-level contract. Re-running
`workframe setup` restores the shipped guide when it is missing and never
overwrites an existing file. Tools that begin instruction discovery at the Git
root must be directed to this parent guide explicitly.

Choose a custom persistent root interactively or with `--root`:

```bash
workframe setup --local --root /Volumes/v0/development/workframe
```

The one-line locator at `${XDG_CONFIG_HOME:-~/.config}/workframe/root`
remembers that choice. Use `WORKFRAME_HOME` for an explicit process-level
override, especially in tests:

```bash
WORKFRAME_HOME=/tmp/workframe-demo workframe setup
```

## Shared profile

Set up:

```bash
workframe setup --shared
```

The interactive setup collects:

- SSH host and optional address
- Remote box user
- Remote store root
- Local mount path
- SMB share name

These values are written to the selected store's
`system/config/workframe.conf`. They are never shipped as product defaults.

In shared mode:

1. The frontend resolves and opens paths through the local mount.
2. Store verbs execute over SSH as the configured box user.
3. The backend runs at `$BOX_ROOT/system/bin/workframe`.
4. The backend receives `WORKFRAME_BACKEND=1` and
   `WORKFRAME_HOME=$BOX_ROOT`.

Shared setup provisions `WORKFRAME.md` at `$BOX_ROOT`, not in the Mac-side user
configuration directory. If the box is offline during setup, rerun
`workframe setup --shared` once the shared stack is reachable.

The optional [`mount-workframe.sh`](../../contrib/mount-workframe.sh) helper
reads the same config keys or `WORKFRAME_SHARE_NAME`,
`WORKFRAME_BOX_USER`, `WORKFRAME_MOUNT_PATH`, and
`WORKFRAME_BOX_ADDR`.

## Change profile settings

```bash
workframe config
```

`config` is interactive and refuses to rewrite preferences without a terminal.
You may also edit `<selected-root>/system/config/workframe.conf` directly using
the supported keys in the
[configuration reference](../reference/configuration.md).

## Shared local dependency cache

Shared profiles may set:

```ini
localdeps = 1
cache_dirs = node_modules, .next, .turbo, dist, build
```

Workframe then links those directories into `~/.workframe-cache` using a
workspace-specific key. This is opt-in because existing directories may be
replaced when links are created.

## Health checks

```bash
workframe status
workframe doctor
```

`status` is a fast count and summary. `doctor` checks configuration,
reachability, mount state, repositories, worktrees, and editor setup.
