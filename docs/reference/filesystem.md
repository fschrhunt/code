# Filesystem reference

```text
<root>/
├── README.md
├── repos/
│   └── <repo>/
└── worktrees/
    └── <agent>-<repo>/
```

Base repository directories are ordinary non-bare Git clones with a `.git/`
directory. They live only beneath `repos/`. Worktree directories are linked Git
worktrees with a `.git` file and live only beneath `worktrees/`, named
`<agent>-<repo>` and suffixed `-1`, `-2`, ... when occupied.

The selected root is stored at:

```text
${XDG_CONFIG_HOME:-~/.config}/code/root
```

The collection README documents the required workflow for people and automated
coding sessions. `code setup` can relocate root-level repositories and repair
their live linked worktrees without writing migration state. Code stores no
logs, migration journals, or clone cache inside the collection. Its ownership
marker lives in each linked worktree's private Git administrative directory.
