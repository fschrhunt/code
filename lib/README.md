# Workspaces collection

This folder separates stable repository checkouts from isolated task worktrees:

```text
<root>/
├── README.md                     this guide
├── repos/
│   └── pi-cloud/                 base repository, usually on main
└── worktrees/
    └── pi-cloud/
        └── colored-logo/         isolated task checkout and branch
```

## Start a task

Choose a base repository, create a task, and enter the exact path printed by
Workspaces:

```bash
root=$(workspaces root)
cd "$root/repos/pi-cloud"
cd "$(workspaces new)"
git status --short --branch
```

From a base checkout in `repos/`, `new` discovers the repository from the
current folder.
Without an explicit task name, Workspaces chooses an unused world capital for
both the folder and branch, such as
`<root>/worktrees/pi-cloud/reykjavik`. Pass a name when you want one:
`workspaces new pi-cloud colored-logo`.

The task shares Git history with the base repository but has independent working
files and a separate branch.

## Finish a task

```bash
workspaces remove pi-cloud/reykjavik
```

Removal keeps the branch and refuses uncommitted changes. `--force` explicitly
discards those changes. If a task folder is manually deleted, `workspaces list` omits
it and `workspaces doctor` reports the stale Git metadata.

## Rules

- Put base repositories in `repos/`; use `workspaces clone` or ordinary `git clone`.
- Create task checkouts with `workspaces new`; they belong in
  `worktrees/<repo>/<task>`.
- Do not use `mkdir`, `cp`, `git clone`, or raw `git worktree add` to create a
  managed task.
- Automated coding sessions must not edit a base checkout in `repos/`. If one
  starts there, create a task and continue only in the returned path.
- Workspaces removes only task worktrees carrying its private ownership marker.

Run `workspaces help` for the complete CLI.

<!-- workspaces-generated-readme -->
