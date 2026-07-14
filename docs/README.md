# wt documentation

These guides ship with the checkout you installed (`./install.sh` prints this
folder). They always match that binary — nothing is copied into `~/.wt`.

## Start here

| If you want to… | Read |
|-----------------|------|
| Change agents, IDE, org, or local/shared store | [customize.md](customize.md) |
| Change how `wt` itself behaves (menus, commands, defaults) | [extending.md](extending.md) |
| Install / develop / CI contract | [../README.md](../README.md), [../AGENTS.md](../AGENTS.md) |

**Rule of thumb:** prefs that are *yours* go in `~/.wt/config`. Behavior that
should ship to everyone belongs in this repo (`lib/`, `bin/`). Install never
wipes your config.
