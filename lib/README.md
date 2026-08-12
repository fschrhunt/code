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
root=$(ws root)
cd "$root/repos/pi-cloud"
cd "$(ws new pi-cloud)"
git status --short --branch
```

Without an explicit task name, Workspaces chooses an unused US state capital
for both the folder and branch, such as
`<root>/worktrees/pi-cloud/salem`. Pass a name when you want one:
`ws new pi-cloud colored-logo`.

The task shares Git history with the base repository but has independent working
files and a separate branch.

## Finish a task

```bash
ws remove pi-cloud/salem
```

Removal keeps the branch and refuses uncommitted changes. `--force` explicitly
discards those changes.

## Rules

- Clone base repositories with `ws clone`; they belong in `repos/`.
- Create task checkouts with `ws new`; they belong in
  `worktrees/<repo>/<task>`.
- Do not use `mkdir`, `cp`, `git clone`, or raw `git worktree add` to create a
  managed task.
- Automated coding sessions must not edit a base checkout in `repos/`. If one
  starts there, create a task and continue only in the returned path.
- Workspaces removes only task worktrees carrying its private ownership marker.

`workspaces` can replace `ws` in every command. Run `ws help` for the complete
CLI.
