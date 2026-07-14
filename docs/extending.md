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
lib/ui.sh              logo, help (WORK/SETTINGS/MORE), gum helpers
lib/agents.sh          agent registry + IDE launch
lib/backend.sh         git verbs on $ROOT
lib/frontend.sh        Mac UX, wizard, SSH `_bx` for shared
contrib/mount-wt.sh    optional SMB mount (config/env driven)
docs/                  these guides
test/                  bats + golden/help.txt
```

---

## “I want to change…” → file

| Goal | Edit |
|------|------|
| Help text / section labels | `lib/ui.sh` → `_help` |
| Bare-`wt` menu | `lib/frontend.sh` → `wizard` |
| Neutral defaults, cities list | `lib/config.sh` |
| IDE launch flags (`-n`, …) | `lib/agents.sh` → `_editor_open` |
| Agent name rules | `lib/agents.sh` |
| new / archive / clone / … | `lib/backend.sh` |
| Prompts, SSH, doctor, init | `lib/frontend.sh` |
| New subcommand wiring | `bin/wt` (+ help + wizard) |
| Mount helper | `contrib/mount-wt.sh` |
| Locked help UX | `test/golden/help.txt` (same change as copy) |

Keep UI sections **action-scoped**: WORK · SETTINGS · MORE. Users scan by job.

---

## Recipes

### Add a command

1. Implement `cmd_*` (backend) and/or `mac_*` (frontend).
2. Dispatch in `bin/wt`.
3. Add under the matching section in `_help` **and** `wizard`.
4. Update `test/golden/help.txt` if help lines changed.
5. `make check`.

### Change shipped defaults

Only in `lib/config.sh`, and keep them **neutral** (empty shared stack, local
profile, generic `editor = cursor`). Real fleet values stay in user config.

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
- [ ] Help and wizard sections still match (WORK / SETTINGS / MORE)
- [ ] Golden help updated when copy changed
- [ ] `make check` green
- [ ] No edits to a deployed/mounted live binary
