# Parallel work

A second terminal or agent session does not isolate files. If both processes
edit the same checkout, they can overwrite, stage, or commit each other's work.

Keep the repository checkout on `main` and create one worktree per editing
session. Name each worktree after the agent that owns it:

```bash
cd ~/Code/repos/e
first=$(code new e)
second=$(code new codex)
```

The resulting layout is:

```text
~/Code/repos/e
~/Code/worktrees/e-e
~/Code/worktrees/codex-e
```

A second worktree for the same agent suffixes the name, such as `e-e-1`.

Start each process in its returned path:

```bash
cd "$first"
# Start the first editing process here.
```

```bash
cd "$second"
# Start the second editing process here.
```

Branches may be renamed normally; worktree folders may be moved anywhere
beneath `worktrees/` and ownership survives. When finished, remove the checkout
without deleting its branch:

```bash
code remove e-e
```
