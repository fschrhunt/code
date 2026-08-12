# Parallel work

A second terminal or agent session does not isolate files. If both processes
start editing in the same checkout, they can overwrite, stage, or commit each
other's changes.

Create one sibling worktree per editing task:

```bash
workspaces new pi fix-auth
workspaces new pi update-docs
```

Then enter the matching checkout before starting work:

```bash
cd ~/workspaces/pi-fix-auth
pi
```

```bash
cd ~/workspaces/pi-update-docs
pi
```

The normal `~/workspaces/pi` checkout remains available for ordinary work and
repository-wide Git operations.

Branches may be renamed normally:

```bash
git branch -m clearer-name
```

Move a checkout with Git rather than a filesystem-only rename so Git updates its
worktree record:

```bash
git -C ~/workspaces/pi worktree move \
  ~/workspaces/pi-fix-auth \
  ~/workspaces/pi-clearer-name
```

Workspaces ownership follows both operations. When finished, remove the checkout
without deleting its branch:

```bash
workspaces remove pi/clearer-name
```
