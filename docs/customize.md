# Customize wt (your prefs)

Shape `wt` to your machine and team **without forking the code**. Everything in
this guide lives in `~/.wt/config` (or the prompts behind `wt config` /
`wt init` / `wt agents`).

Updating `wt` (`./install.sh`, `git pull`) does **not** rewrite this file.

---

## First run

```
./install.sh                 # put wt on your PATH
wt init                      # local store under ~/.wt   (or: wt init --shared)
wt agents add cursor         # at least one identity
wt config                    # editor + github org
```

Then day to day:

```
wt new <repo> [feature]      # pick an agent interactively
wt ide                       # open a worktree in your editor
wt list / wt archive / …
```

Bare `wt` opens a sectioned menu (WORK · SETTINGS · MORE). `wt help` lists the
same groups as plain text.

---

## Mental model

```
~/.wt/config          ← you (agents, editor, org, shared host/paths)
this checkout         ← the product (commands, UI, git behavior)
```

| | Prefs (`~/.wt/config`) | Product (this repo) |
|--|------------------------|---------------------|
| Who changes it | You, via CLI or editor | Contributors / coding agents |
| Survives reinstall? | Yes | You pull/rebuild deliberately |
| Examples | `editor = cursor` | New command, logo, defaults |

How to change the product itself: [extending.md](extending.md).

---

## Agents (identities)

An **agent** is a named identity for work (`cursor`, `claude`, `codex`, …). It
is not “which IDE you use.”

There is **no silent default**. Every `wt new` picks from your list
(interactive) or you pass `--agent <name>` (required when not a TTY).

```
wt agents list
wt agents add cursor
wt agents add claude
wt agents remove oldname            # blocked if that agent still has worktrees
wt agents remove oldname --force
```

Config key: `agents = cursor, claude` (comma-separated).

Names: lowercase `[a-z0-9._-]+`.

---

## Default IDE

```
wt config          # choose “prefs”
```

Or in `~/.wt/config`:

```
editor = cursor        # anything on your PATH: code, windsurf, …
```

`wt ide` runs that command. For `cursor` and `code`, wt opens a **new window**
(`-n`) so it does not reuse an existing Agents/chat window. `wt open` is an
alias for `wt ide`.

---

## GitHub org shortcut

```
default_org = your-org
```

`wt clone my-repo` → `https://github.com/your-org/my-repo.git`.  
Full `owner/repo` and `https://…` / `git@…` URLs still work as-is.

---

## Local vs shared store

| Profile | Data lives | Git runs |
|---------|------------|----------|
| **local** (default) | `~/.wt` on this machine | In-process |
| **shared** | box (`box_root`) + Mac mount (`mount_path`) | Over SSH to the box |

```
wt init                 # local
wt init --shared        # prompts for host, user, paths, share name
wt config               # switch profile or edit the shared stack later
```

Shared keys (only present when `type = shared`):

| Key | Meaning |
|-----|---------|
| `box_host` | SSH host (config Host or hostname) |
| `box_addr` | Address for reachability probes (often a Tailscale IP) |
| `box_user` | Remote user for `sudo -u` / SSH |
| `box_root` | Store root on the box (e.g. `/mnt/wt`) |
| `mount_path` | Local mount of that store (e.g. `/Volumes/wt`) |
| `share_name` | SMB share name |

The repo ships **no** fleet hostnames or IPs. Fill these once for your deploy.
Optional helper: [`contrib/mount-wt.sh`](../contrib/mount-wt.sh) (reads the same
keys or `WT_*` env vars).

---

## Full config reference

Path: `~/.wt/config` (or `$WT_HOME/config` in tests).

```
# values only — parsed, never sourced as shell
type = local
editor = cursor
default_org = example
agents = cursor, claude

# only when type = shared:
box_host = my-box
box_addr = 100.x.x.x
box_user = wt
box_root = /mnt/wt
mount_path = /Volumes/wt
share_name = wt
```

- Unknown keys are ignored.
- Values with `` ` $ ( ) ; | & < > \ ' " `` are rejected.
- `wt agents` / `wt config` / `wt init` rewrite this file deliberately.
- Install, pull, and `wt update` do **not**.

---

## Folder layout (fixed)

This path scheme is the product — keep it unless you are intentionally forking:

```
<store>/repos/<repo>                       # one canonical clone per repo
<store>/workspaces/<agent>/<repo>/<city>   # worktree directory (city = stable id)
branch: <agent>/<feature>                  # mutable branch name
```

- **Local** `<store>` → `~/.wt`
- **Shared** `<store>` → `mount_path` on the Mac, `box_root` on the box

City names are random labels so folders stay stable when you rename a feature.

---

## Common “how do I…?”

| Goal | Do this |
|------|---------|
| Add a teammate’s agent name | `wt agents add NAME` |
| Use VS Code instead of Cursor | `editor = code` (or `wt config`) |
| Stop picking agent every time in scripts | `wt new repo feat --agent cursor` or `WT_AGENT=cursor` |
| Point at a server store | `wt init --shared` |
| See why shared feels broken | `wt doctor` |
| Jump in the shell | install the `wt cd` zsh snippet from `wt config`, then `wt cd` |
| Make wt look “new” after an edit | `./install.sh` from the checkout you want; check `readlink ~/.local/bin/wt` |

Still stuck? `wt doctor`, then skim [extending.md](extending.md) if the bug is in
the product rather than your config.
