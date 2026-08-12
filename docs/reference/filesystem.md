# Filesystem reference

```text
<root>/
├── WORKFRAME.md
├── repos/<repo>/
├── workspaces/<repo>/<city>/
└── system/
    ├── config/workframe.conf
    ├── logs/
    └── migrations/
```

Workframe creates and manages only two-level workspace paths. `migrations/`
contains journals produced by successful or rolled-back legacy migrations.
