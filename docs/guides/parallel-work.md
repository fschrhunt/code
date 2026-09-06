# Parallel work

A second terminal or agent session does not isolate files. If both processes
edit the same checkout, they can overwrite, stage, or commit each other's work.

Keep the repository checkout on `main` and create one task worktree per editing
session:

```bash
cd ~/Code/repos/pi
first=$(code new pi fix-auth)
second=$(code new pi update-docs)
```

The resulting layout is:

```text
~/Code/repos/pi
~/Code/worktrees/pi/fix-auth
~/Code/worktrees/pi/update-docs
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
code remove pi/fix-auth
```

## Agent sessions

Automated sessions can skip task naming by setting `CODE_AGENT`. The checkout
lands flat in `worktrees/` as `<agent>-<repo>`, with a numeric suffix when the
name is taken:

```bash
cd ~/Code/repos/pi
CODE_AGENT=e code new        # ~/Code/worktrees/e-pi
```

`code list` and `code remove` treat these checkouts like any other managed
worktree.
