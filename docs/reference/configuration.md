# Configuration reference

Workframe preferences live in `~/workframe/config`, or
`$WORKFRAME_HOME/config` when the root override is set.

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

## Shared overlay

Shared installations may provide:

```text
$BOX_ROOT/system/config/workframe.conf
```

or the equivalent file through the local mount. The overlay may fill empty
shared connection fields, but it cannot replace editor or organization
preferences from the user config.

## Fresh-start behavior

Workframe 1.5.0 initializes only the configured Workframe root. It does not
detect, import, rename, or delete stores created by other installations.

See the [filesystem reference](filesystem.md) for resolved paths.
