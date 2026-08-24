# Parallel work

A second terminal or agent session does not isolate files. If both processes
edit the same checkout, they can overwrite, stage, or commit each other's work.

Keep the repository checkout on `main` and create one task worktree per editing
session:

```bash
cd ~/workspaces/repos/pi
first=$(workspaces new pi fix-auth)
second=$(workspaces new pi update-docs)
```

The resulting layout is:

```text
~/workspaces/repos/pi
~/workspaces/worktrees/pi/fix-auth
~/workspaces/worktrees/pi/update-docs
```

Start each process in its returned path:

```bash
cd "$first"
# Start the first editing process here.
```

```bash
cd "$second"
# Start the second editing process here.
```

Branches may be renamed normally. Keep task directories beneath their matching
`worktrees/<repo>/` folder. When finished, remove the checkout without deleting
its branch:

```bash
workspaces remove pi/fix-auth
```
