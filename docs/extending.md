# Extending wt (the product)

Use this when a coding agent (or you) should change **how wt behaves for
everyone**, not just one machine’s prefs.

User prefs (`agents`, `editor`, shared hosts) belong in `~/.wt/config` —
see [customize.md](customize.md). Do **not** hardcode private IPs, orgs, or
fleet hostnames into shipped defaults.

Contributor contract (PRs, `make check`, never patch a live deployed binary):
[AGENTS.md](../AGENTS.md).

---

## Before you edit

1. Work in a **git worktree of this repo** (not `/…/system/bin/wt` on a mount).
2. Point PATH at this checkout: `./install.sh`
3. Gate every change: `make check` (shellcheck + bats)

Dev seams (tests / local override):

```
WT_BACKEND=1              # force backend/git role on any OS
WT_HOME=/tmp/wt-store     # throwaway data root + config
WT_COLOR=0                # stable golden output
```

Helpers: `test/helper.bash`. Tests must stay offline, non-interactive, deterministic.

---

## Layout of the code

```
bin/wt                 dispatch
lib/config.sh          neutral defaults + ~/.wt/config load/save
lib/palette.sh         colors
lib/ui.sh              logo, help (EXAMPLES/COMMANDS), gum helpers
lib/agents.sh          agent registry + IDE launch
lib/backend.sh         git verbs on $ROOT
lib/frontend.sh        Mac UX + SSH `_bx` for shared (CLI-first; TTY fill-in only)
contrib/mount-wt.sh    optional SMB mount (config/env driven)
docs/                  these guides
test/                  bats + golden/help.txt
```

---

## “I want to change…” → file

| Goal | Edit |
|------|------|
| Help text / section labels | `lib/ui.sh` → `_help` |
| Neutral defaults | `lib/config.sh` |
| World cities list / city picker | `lib/cities.txt` (~4.5k slugs), `lib/backend.sh` → `_pick_city` |
| IDE launch flags (`-n`, …) | `lib/agents.sh` → `_editor_open` |
| Agent name rules | `lib/agents.sh` |
| new / archive / clone / … | `lib/backend.sh` |
| Arg parsing, confirms, SSH, init | `lib/frontend.sh` |
| New subcommand wiring | `bin/wt` (+ help) |
| Mount helper | `contrib/mount-wt.sh` |
| Locked help UX | `test/golden/help.txt` (same change as copy) |

Keep help as EXAMPLES (full invocations) then COMMANDS (short verbs).
Commands are CLI-first (args + flags). Interactive prompts only fill missing args on a TTY.

---

## Recipes

### Add a command

1. Implement `cmd_*` (backend) and/or `mac_*` (frontend).
2. Dispatch in `bin/wt`.
3. Add a short COMMANDS line in `_help` (and an EXAMPLES line if it's a common flow).
4. Update `test/golden/help.txt` if help lines changed.
5. Prefer args/flags over menus; TTY pickers only when an arg is missing.
6. `make check`.

### Change shipped defaults

Only in `lib/config.sh`, and keep them **neutral** (empty shared stack, local
profile). `editor = cursor` is a Cursor-oriented default — override in user
config. Real shared-stack hosts/paths stay in `~/.wt/config`.

### Change how the IDE opens

`_editor_open` in `lib/agents.sh`. Preserve “new window” for Cursor/VS Code
unless the product intent explicitly changes.

### Shared transport

Frontend calls `_bx` → SSH to `box_host` running `$BOX_ROOT/system/bin/wt`.
Incomplete shared config should fail with `_require_shared_stack`, not silent
wrong hosts.

---

## What must not land in the repo

- Tailscale / LAN IPs, private hostnames, org names as defaults  
- Auto-detect of one person’s `/Volumes/…` layout as the only shared path  
- Silent default agent  
- Live edits to a mounted fleet `system/bin/wt`

---

## PR checklist

- [ ] Per-user prefs → config UX or [customize.md](customize.md), not baked defaults
- [ ] Help stays EXAMPLES + COMMANDS (short lines; golden updated)
- [ ] Golden help updated when copy changed
- [ ] Destructive commands accept args/flags (`--yes` / `--force`); TTY prompts only fill missing args
- [ ] `make check` green
- [ ] No edits to a deployed/mounted live binary
