# Filesystem reference

```text
<root>/
├── README.md
├── repos/
│   └── <repo>/
└── worktrees/
    └── <repo>/
        ├── <task>/
        └── <other-task>/
```

Base repository directories are ordinary non-bare Git clones with a `.git/`
directory. They live only beneath `repos/`. Task directories are linked Git
worktrees with a `.git` file and live only beneath `worktrees/<repo>/`.

The selected root is stored at:

```text
${XDG_CONFIG_HOME:-~/.config}/workspaces/root
```

The collection README documents the required workflow for people and automated
coding sessions. Workspaces stores no logs, migration journals, or clone cache
inside the collection. Its ownership marker lives in each linked worktree's
private Git administrative directory.
