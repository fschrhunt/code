# Filesystem reference

## Local store

The default root is `~/workframe`. `WORKFRAME_HOME` replaces it for the current
process.

```text
~/workframe/
├── WORKFRAME.md
├── config
├── repos/
│   └── <repo>/
├── workspaces/
│   └── <agent>/
│       └── <repo>/
│           └── <city>/
└── system/
    └── logs/
```

| Path | Purpose |
|---|---|
| `WORKFRAME.md` | Store safety guidance for coding agents and launchers |
| `config` | User profile and preferences |
| `repos/<repo>` | Canonical Git clone |
| `workspaces/<agent>/<repo>/<city>` | Active Git worktree |
| `system/logs` | Maintenance logs |

## Branches and folders

Branches use `<agent>/<feature>`. Folder names use generated city labels so
paths remain short and stable while branch names remain descriptive.

Archive removes the city folder but leaves the branch in the canonical clone.
Restore creates a new city folder for the same branch.

## Shared store

The box stores the same layout below `box_root`. The frontend reads and opens
files through `mount_path`, while backend Git operations use the box path.
The shared `WORKFRAME.md` lives directly under `box_root` so it remains an
ancestor of every mounted worktree.

The backend executable is:

```text
$BOX_ROOT/system/bin/workframe
```

An optional shared overlay is:

```text
$BOX_ROOT/system/config/workframe.conf
```

## Local dependency cache

When a shared profile enables `localdeps`, eligible worktree directories link
into:

```text
~/.workframe-cache/<agent_repo_city>/
```

The cache is outside the store and is never enabled by default.

## Mount credentials

The optional macOS mount helper reads credentials from the login keychain. A
one-shot seed may be placed at:

```text
~/.workframe-cred.seed
```

The helper removes the seed after successfully adding the credential to the
keychain. Never commit credential material.

## Temporary files and logs

Progress helpers may use `/tmp/workframe.*.out` when the system temporary-file
utility is unavailable. Safe cleanup records use
`system/logs/workframe-clean.log`.
