# Configuration reference

Preferences live in `<selected-root>/system/config/workframe.conf` and are
parsed as values, never sourced as shell code.

```ini
type = local
editor = cursor
default_org = example
cache_dirs = node_modules, .next, .turbo, dist, build
localdeps = 0
```

`WORKFRAME_HOME` overrides the selected root for one process. Otherwise the
selected local root is recorded at `${XDG_CONFIG_HOME:-~/.config}/workframe/root`.

Older `agents=` values are read only by `workframe migrate`; new configuration
never writes agent identities.
