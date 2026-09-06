# Code collection

This folder separates stable repository checkouts from isolated agent worktrees:

```text
<root>/
├── README.md                     this guide
├── repos/
│   └── e/                        base repository, usually on main
└── worktrees/
    └── e-e/                      agent e working on repository e
```

## Start a session

Choose a base repository, name the agent, and enter the exact path printed by
Code:

```bash
root=$(code root)
cd "$root/repos/e"
cd "$(code new e)"
git status --short --branch
```

`new` discovers the repository from the current folder and names the checkout
and branch `<agent>-<repo>`, such as `e-e`. An occupied name suffixes `-1`,
`-2`, and so on. The worktree shares Git history with the base repository but
has independent working files and its own branch.

## Finish a session

```bash
code remove e-e
```

Removal keeps the branch and refuses uncommitted changes. `--force` explicitly
discards those changes. If a worktree folder is manually deleted, `code list`
omits it and `code doctor` reports the stale Git metadata.

## Rules

- Put base repositories in `repos/`; use `code clone` or ordinary `git clone`.
- Create worktrees with `code new <agent>`; they belong in
  `worktrees/<agent>-<repo>`.
- Do not use `mkdir`, `cp`, `git clone`, or raw `git worktree add` to create a
  managed worktree.
- Automated coding sessions must not edit a base checkout in `repos/`. If one
  starts there, create a worktree and continue only in the returned path.
- Code removes only worktrees carrying its private ownership marker.

Run `code help` for the complete CLI.

<!-- code-generated-readme -->
