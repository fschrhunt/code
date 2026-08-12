# Filesystem reference

```text
<root>/
├── README.md
├── <repo>/
├── <repo>-<task>/
└── <repo>-<other-task>/
```

Repository directories are ordinary non-bare Git clones with a `.git/`
directory. Task directories are linked Git worktrees with a `.git` file and are
immediate siblings of their repository.

The selected root is stored at:

```text
${XDG_CONFIG_HOME:-~/.config}/workspaces/root
```

Workspaces stores no configuration, logs, migration journals, clone cache, or
nested worktree hierarchy inside the collection. Its ownership marker lives in
the linked worktree's private Git administrative directory.
