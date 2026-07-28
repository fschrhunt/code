# Extending wt (the product)

Use this when a coding agent (or you) should change **how wt behaves for
everyone**, not just one machine’s prefs.

User prefs (`agents`, `editor`, shared hosts) belong in `~/wt/config` —
see [customize.md](customize.md). Do **not** hardcode private IPs, orgs, or
fleet hostnames into shipped defaults.

Contributor contract (PRs, `make check`, Linear loop, never patch a live
deploy): [AGENTS.md](../AGENTS.md).

---

## Before you edit

1. Work in a **git worktree of this repo** — **never**
   `/Volumes/Agents/system/bin/wt` (or any `$BOX_ROOT/system/bin/wt` on a mount).
2. Point PATH at this checkout: `./install.sh`
3. Gate every change: `make check` (shellcheck + bats)
4. Planned work needs a `DEV-*` with Why + Acceptance (see [linear.md](linear.md))

Dev seams (tests / local override):

```
WT_BACKEND=1              # force backend/git role on any OS
WT_HOME=/tmp/wt-store     # throwaway data root + config
WT_COLOR=0                # stable golden output
WT_AGENT=nova             # non-interactive agent for frontend new
```

Helpers: `test/helper.bash`. Tests must stay offline, non-interactive, deterministic.

---

## Layout of the code

```
bin/wt                 entry + dispatch (frontend vs WT_BACKEND=1)
lib/config.sh          neutral defaults + ~/wt/config load/save + ROOT paths
lib/palette.sh         colors + ok/warn/err/die/banner
lib/ui.sh              logo, help (EXAMPLES/COMMANDS), gum helpers, progress
lib/agents.sh          agent registry + IDE launch (`_editor_open`)
lib/backend.sh         cmd_* git/store verbs on $ROOT (+ `_pick_city`)
lib/frontend.sh        mac_* UX; `_bx` → SSH shared or in-process local
lib/cities.txt         ~4.5k city slugs for worktree folder labels
contrib/mount-wt.sh    optional SMB mount (config/env driven)
docs/                  these guides (index: README.md)
test/                  bats + golden/help.txt
```

There is no deeper package tree — every product change lands in one of the files
above.

---

## “I want to change…” → file

| Goal | Edit |
|------|------|
| Help text / section labels | `lib/ui.sh` → `_help` |
| Neutral defaults / path resolution | `lib/config.sh` |
| World cities list / city picker | `lib/cities.txt`, `lib/backend.sh` → `_pick_city` |
| IDE launch flags (`-n`, …) | `lib/agents.sh` → `_editor_open` |
| Agent name rules / `WT_AGENT` | `lib/agents.sh` |
| new / archive / clone / … | `lib/backend.sh` |
| Arg parsing, confirms, SSH, init, config UX | `lib/frontend.sh` |
| New subcommand wiring | `bin/wt` (+ help in `lib/ui.sh`) |
| Mount helper | `contrib/mount-wt.sh` |
| Locked help UX | `test/golden/help.txt` (same change as copy) |

Keep help as EXAMPLES (full invocations) then COMMANDS (short verbs).
Commands are CLI-first (args + flags). Interactive prompts only fill missing args on a TTY.

---

## Recipes

### Add a command

1. Implement `cmd_*` (backend) and/or `mac_*` (frontend).
2. Dispatch in `bin/wt` (both `WT_BACKEND=1` and frontend cases when needed).
3. Add a short COMMANDS line in `_help` (and an EXAMPLES line if it's a common flow).
4. Update `test/golden/help.txt` if help lines changed.
5. Prefer args/flags over menus; TTY pickers only when an arg is missing.
6. `make check`.

### Change shipped defaults

Only in `lib/config.sh`, and keep them **neutral** (empty shared stack; product
default `type = local` until M2 documents local as the default for fleets).
`editor = cursor` is a Cursor-oriented default — override in user config. Real
shared-stack hosts/paths stay in `~/wt/config`.

### Change how the IDE opens

`_editor_open` in `lib/agents.sh`. Preserve “new window” for Cursor/VS Code
unless the product intent explicitly changes.

### Shared transport

Frontend `_bx`:

- **local** (`type = local`) — calls `cmd_*` in-process
- **shared** — SSH to `box_host` running `$BOX_ROOT/system/bin/wt` with
  `WT_BACKEND=1` and `WT_HOME=$BOX_ROOT`

Incomplete shared config should fail with `_require_shared_stack`, not silent
wrong hosts.

---

## What must not land in the repo

- Tailscale / LAN IPs, private hostnames, org names as defaults  
- Auto-detect of one person’s `/Volumes/…` layout as the only shared path  
- Silent default agent  
- Live edits to `/Volumes/Agents/system/bin/wt` or any mounted fleet `system/bin/wt`

---

## PR checklist

- [ ] `DEV-*` linked (`Fixes` / `Contributes to`) unless tiny drive-by / Renovate
- [ ] Fischer remains Linear assignee; you are delegate
- [ ] Per-user prefs → config UX or [customize.md](customize.md), not baked defaults
- [ ] Help stays EXAMPLES + COMMANDS (short lines; golden updated)
- [ ] Golden help updated when copy changed
- [ ] Destructive commands accept args/flags (`--yes` / `--force`); TTY prompts only fill missing args
- [ ] `make check` green
- [ ] No edits to `/Volumes/Agents/system/bin/wt` or any live mounted binary
