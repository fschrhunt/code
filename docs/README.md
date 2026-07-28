# wt documentation

Guides that ship with this checkout (`./install.sh` prints this folder). They
always match the binary you linked — nothing is copied into `~/wt`.

**Never edit** `/Volumes/Agents/system/bin/wt` (live fleet deploy). Change docs
and code here, PR, then install/release.

## Status

| | |
|--|--|
| **Shipped** | M0 — shared/SSH foundation + in-repo CLI (`bin/wt`, `lib/*`) |
| **Next** | [DEV-175](https://linear.app/intuitum/issue/DEV-175) M1 profiles |
| **Then** | [DEV-181](https://linear.app/intuitum/issue/DEV-181) M2 local `~/wt` as documented default |
| **Version** | see [../VERSION](../VERSION) |

## Index

| If you want to… | Read |
|-----------------|------|
| Install, quick CLI tour, profile overview | [../README.md](../README.md) |
| Build/test contract, layout, Linear agent rules | [../AGENTS.md](../AGENTS.md) |
| Change agents, IDE, org, or local/shared prefs | [customize.md](customize.md) |
| Change how `wt` behaves (commands, defaults, UX) | [extending.md](extending.md) |
| Linear ↔ GitHub linking, assignee/delegate rules | [linear.md](linear.md) |

**Rule of thumb:** prefs that are *yours* go in `~/wt/config`. Behavior that
should ship to everyone belongs in this repo (`lib/`, `bin/`). Install never
wipes your config.

## Layout (code)

```
bin/wt                 dispatch
lib/config.sh          defaults + ~/wt/config load/save + paths
lib/palette.sh         colors / ok / warn / err / die
lib/ui.sh              logo, help, gum helpers
lib/agents.sh          agent registry + IDE launch
lib/backend.sh         cmd_* store/git verbs
lib/frontend.sh        mac_* UX + _bx (SSH shared / in-process local)
lib/cities.txt         city slugs for worktree folder names
contrib/mount-wt.sh    optional SMB mount helper
test/                  bats + golden/help.txt
```
