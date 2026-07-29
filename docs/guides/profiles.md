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

Initialize:

```bash
workframe init
```

Data lives under `~/workframe`, and store operations run in the same process as
the CLI.

```text
~/workframe/
├── WORKFRAME.md
├── config
├── repos/
├── workspaces/
└── system/logs/
```

`WORKFRAME.md` gives agents and launchers a store-level contract. Re-running
`workframe init` restores the shipped guide when it is missing and never
overwrites an existing file. Tools that begin instruction discovery at the Git
root must be directed to this parent guide explicitly.

Use `WORKFRAME_HOME` for an explicit process-level root, especially in tests:

```bash
WORKFRAME_HOME=/tmp/workframe-demo workframe init
```

## Shared profile

Initialize:

```bash
workframe init --shared
```

The interactive setup collects:

- SSH host and optional address
- Remote box user
- Remote store root
- Local mount path
- SMB share name

These values are written to `~/workframe/config`. They are never shipped as
product defaults.

In shared mode:

1. The frontend resolves and opens paths through the local mount.
2. Store verbs execute over SSH as the configured box user.
3. The backend runs at `$BOX_ROOT/system/bin/workframe`.
4. The backend receives `WORKFRAME_BACKEND=1` and
   `WORKFRAME_HOME=$BOX_ROOT`.

Shared setup provisions `WORKFRAME.md` at `$BOX_ROOT`, not in the Mac-side user
config directory. If the box is offline during initialization, `workframe
update` retries once the shared stack is reachable.

The optional [`mount-workframe.sh`](../../contrib/mount-workframe.sh) helper
reads the same config keys or `WORKFRAME_SHARE_NAME`,
`WORKFRAME_BOX_USER`, `WORKFRAME_MOUNT_PATH`, and
`WORKFRAME_BOX_ADDR`.

## Change profile settings

```bash
workframe config
```

`config` is interactive and refuses to rewrite preferences without a terminal.
You may also edit `~/workframe/config` directly using the supported keys in the
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
reachability, mount state, repositories, worktrees, agents, and editor setup.
