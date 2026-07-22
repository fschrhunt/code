# Customize wt (your prefs)

Shape `wt` to your machine and team **without forking the code**. Everything in
this guide lives in `~/.wt/config` (or the prompts behind `wt config` /
`wt init` / `wt agents`).

Updating `wt` (`./install.sh`, `git pull`) does **not** rewrite this file.

**Never edit** the live fleet binary at `/Volumes/Agents/system/bin/wt`. Prefs
belong here in `~/.wt/config`; product changes belong in a PR against this repo.

---

## First run

```
./install.sh                 # put wt on your PATH
wt init --shared             # fleet / M0 shared store (or: wt init for local)
wt clone owner/repo          # add a repo
wt new <repo> <feature>      # pick an agent interactively
```

Day to day: `wt ide`, `wt list`, `wt archive`, `wt restore`, …

Bare `wt` prints the same help as `wt help` (EXAMPLES · COMMANDS).

Roadmap: shared/SSH is the M0 production path. Local under `~/.wt` works in
this checkout today; [M2 / DEV-181](https://linear.app/intuitum/issue/DEV-181)
is when local becomes the documented default with migration notes. See
[README.md](README.md) for milestone status.

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

An **agent** is a named identity for work (`nova`, `alice`, your handle, …). It
is not “which IDE you use.” Pick any names you like — wt does not ship a vendor
roster.

There is **no silent default**. Every `wt new` picks from your list
(interactive) or you pass `--agent <name>` (required when not a TTY).
Scripts may also set `WT_AGENT=<name>`.

```
wt agents list
wt agents add nova
wt agents add alice
wt agents remove oldname            # blocked if that agent still has worktrees
```

Config key: `agents = nova, alice` (comma-separated).

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
| **local** | `~/.wt` on this machine | In-process (`cmd_*`) |
| **shared** | box (`box_root`) + Mac mount (`mount_path`) | Over SSH to `$BOX_ROOT/system/bin/wt` |

```
wt init                 # local under ~/.wt
wt init --shared        # prompts for host, user, paths, share name
wt config               # switch profile or edit the shared stack later
```

Shared keys (only present when `type = shared`):

| Key | Meaning |
|-----|---------|
| `box_host` | SSH host (config Host or hostname) |
| `box_addr` | Address for reachability probes (often a Tailscale IP) |
| `box_user` | Remote user for `sudo -u` / SSH |
| `box_root` | Store root on the box (e.g. `/mnt/wt` or `/Volumes/Agents` on some fleets) |
| `mount_path` | Local mount of that store (e.g. `/Volumes/Agents`) |
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
agents = nova, alice
cache_dirs = node_modules, .next, .turbo, dist, build
localdeps = 0                # shared only: 1 = link cache dirs into ~/.wt-cache

# only when type = shared (example values — use yours):
box_host = my-box
box_addr = my-box.example
box_user = wt
box_root = /mnt/wt
mount_path = /Volumes/wt
share_name = wt
```

- Unknown keys are ignored.
- Values with `` ` $ ( ) ; | & < > \ ' " `` are rejected.
- `wt agents` / `wt config` / `wt init` rewrite this file deliberately.
- Install and pull do **not**. `wt update` refreshes mount/sync/doctor on shared;
  on local it only reminds you to re-run `./install.sh`.

---

## Folder layout (fixed)

This path scheme is the product — keep it unless you are intentionally forking:

```
<store>/repos/<repo>                       # one canonical clone per repo
<store>/workspaces/<agent>/<repo>/<city>   # worktree directory (city = stable id)
branch: <agent>/<feature>                  # mutable branch name
```

- **Local** `<store>` → `~/.wt` (or `$WT_HOME`)
- **Shared** `<store>` → `mount_path` on the Mac, `box_root` on the box

City names are random folder labels (sampled from `lib/cities.txt`, with a
syllable fallback on collisions) so paths stay stable when you rename a feature.

On a **shared** mount, set `localdeps = 1` if you want `node_modules` / build
caches symlinked into `~/.wt-cache` (off by default — it replaces those dirs).

---

## Common “how do I…?”

| Goal | Do this |
|------|---------|
| Add a teammate’s agent name | `wt agents add NAME` |
| Use VS Code instead of Cursor | `editor = code` (or `wt config`) |
| Stop picking agent every time in scripts | `wt new repo feat --agent nova` or `WT_AGENT=nova` |
| Point at a server store | `wt init --shared` |
| Quick store glance | `wt status` |
| See why shared feels broken | `wt doctor` |
| Jump in the shell | `cd "$(wt cd …)"`, or install the shell snippet from `wt config` then `wt cd` |
| Make wt look “new” after an edit | `./install.sh` from the checkout you want; check `readlink ~/.local/bin/wt` |

Still stuck? `wt doctor`, then skim [extending.md](extending.md) if the bug is in
the product rather than your config.
