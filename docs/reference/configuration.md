# Configuration reference

Workframe preferences live in
`<selected-root>/system/config/workframe.conf`. The default selected root is
`~/workframe`; `workframe setup` can persist any absolute local path.
`WORKFRAME_HOME` replaces the selected root for the current process.

The file is parsed as values-only configuration. It is never sourced as shell
code. Unknown keys and unsafe values are ignored.

## Example

```ini
type = local
editor = cursor
default_org = example
agents = codex, claude
cache_dirs = node_modules, .next, .turbo, dist, build
localdeps = 0
```

Shared profiles also contain:

```ini
box_host = box.example.test
box_addr =
box_user = agents
box_root = /srv/workframe
mount_path = /Volumes/workframe
share_name = workframe
```

Use your own infrastructure values. The repository contains no operational
hostnames, addresses, organizations, credentials, or mount paths.

## Keys

| Key | Meaning | Default |
|---|---|---|
| `type` | `local` or `shared` profile | `local` |
| `editor` | Command used by `workframe ide` | `cursor` |
| `default_org` | Expands a bare repo name for `clone` | empty |
| `agents` | Comma- or space-separated identities | empty |
| `cache_dirs` | Worktree child directories eligible for shared cache links | `node_modules .next .turbo dist build` |
| `localdeps` | Enable shared cache links with `1`, `true`, `yes`, or `on` | `0` |
| `box_host` | Shared SSH hostname | empty |
| `box_addr` | Optional connection address | empty |
| `box_user` | Shared backend user | empty |
| `box_root` | Store root on the shared box | empty |
| `mount_path` | Local mounted path for the shared store | empty |
| `share_name` | SMB share name | empty |

`cache_dirs` entries must be safe single path segments. Separators, traversal
segments, and unsafe characters are discarded.

## Environment variables

| Variable | Purpose |
|---|---|
| `WORKFRAME_HOME` | Override the data root and config directory |
| `WORKFRAME_AGENT` | Choose an agent for non-interactive `new` |
| `WORKFRAME_COLOR` | Force color off with `0` or on with `1` |
| `WORKFRAME_BACKEND` | Select internal backend mode; intended for tests and shared execution |
| `WORKFRAME_VALID_AGENTS` | Forward the authoritative agent list to a shared backend |
| `WORKFRAME_SHARE_NAME` | Override mount-helper share name |
| `WORKFRAME_BOX_USER` | Override mount-helper box user |
| `WORKFRAME_MOUNT_PATH` | Override mount-helper mount path |
| `WORKFRAME_BOX_ADDR` | Override mount-helper server address |
| `WORKFRAME_BOX_HOST` | Fallback mount-helper hostname |

Environment overrides are process-scoped. Credentials are not accepted through
Workframe configuration.

## Root locator

For normal local use, `workframe setup` records the selected root in:

```text
${XDG_CONFIG_HOME:-~/.config}/workframe/root
```

The locator contains one absolute path and is not shell code. It allows the CLI
to find a store on an attached volume without a symlink. If the locator is
missing or invalid, Workframe falls back to `~/workframe`. `WORKFRAME_HOME`
takes precedence and never rewrites the locator. When a selected root is
unavailable, commands stop with an attach-the-volume message instead of
creating or using a fallback store.

## Legacy location

Older installations may have `<selected-root>/config`. Workframe reads that
file until the next successful setup or configuration save, then writes
`system/config/workframe.conf` and removes the legacy file.

## Shared store configuration

Shared installations may provide:

```text
$BOX_ROOT/system/config/workframe.conf
```

or the equivalent file through the local mount. Shared store values may fill
empty connection fields, but they cannot replace editor or organization
preferences loaded from the selected user store.

## Fresh-start behavior

Workframe 1.5.0 initializes only the configured Workframe root. It does not
detect, import, rename, or delete stores created by other installations.

See the [filesystem reference](filesystem.md) for resolved paths.
