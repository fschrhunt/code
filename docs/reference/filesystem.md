# Filesystem reference

## Local store

The default root is `~/workframe`. `workframe setup` can persist another
absolute path, and `WORKFRAME_HOME` replaces it for the current process.

```text
~/workframe/
├── WORKFRAME.md
├── repos/
│   └── <repo>/
├── workspaces/
│   └── <agent>/
│       └── <repo>/
│           └── <city>/
└── system/
    ├── config/
    │   └── workframe.conf
    └── logs/
```

| Path | Purpose |
|---|---|
| `WORKFRAME.md` | Store safety guidance for coding agents and launchers |
| `repos/<repo>` | Canonical Git clone |
| `workspaces/<repo>/<city>` | Active Git worktree |
| `system/config/workframe.conf` | User profile and preferences |
| `system/logs` | Maintenance logs |

The selected root is remembered outside the store in:

```text
${XDG_CONFIG_HOME:-~/.config}/workframe/root
```

This one-line locator lets Workframe rediscover a store on an attached volume
without a symlink.

## Branches and folders

Branches use the task slug. Folder names use generated city labels so
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
keychain. The seed must be owned by the current user, must not be a symlink, and
must use mode `600` or `400`:

```bash
chmod 600 ~/.workframe-cred.seed
```

Never commit credential material. The optional helper passes the SMB URL to the
system mount utility, so the password may be briefly visible to other processes
running as the same local user. Prefer the login keychain and avoid the helper
on an untrusted multi-user Mac.

## Temporary files and logs

Progress helpers require the system temporary-file utility and create
user-private randomized files below `${TMPDIR:-/tmp}`. They refuse to run if a
secure temporary file cannot be created. Safe cleanup records use
`system/logs/workframe-clean.log`.
