# Code

This folder contains normal repository checkouts and their isolated task
worktrees:

```text
~/Code/
├── pi-cloud/                     repository checkout; keep on main
└── worktrees/
    └── pi-cloud/
        └── colored-logo/         isolated task checkout and branch
```

## Start work

Enter the repository checkout to choose the project, then create a task before
editing:

```bash
cd ~/Code/pi-cloud
path=$(code new pi-cloud colored-logo)
cd "$path"
git status --short --branch
```

`code new` prints the authoritative task path. Work only in that returned
path. The checkout and branch share Git history with the repository while their
working files remain isolated.

## Rules

- Top-level directories are repository checkouts created with `code clone`.
- Task checkouts belong only under `worktrees/<repo>/<task>`.
- Do not create task folders with `mkdir`, `cp`, `git clone`, or raw
  `git worktree add`; use `code new`.
- Automated coding sessions must not edit a top-level repository checkout. When
  started there, create a task and continue in its returned path first.
- Remove a finished checkout with `code remove <repo>/<task>`. This keeps
  its branch and refuses dirty work unless `--force` is explicit.
