# Editors

Workframe workspaces are task-owned. Choose Codex, Claude, Cursor, or another
agent harness inside the workspace; Workframe does not encode an agent identity
in paths or branch names.

Configure the editor used by `workframe open` interactively:

```bash
workframe config
```

The editor command is stored in `system/config/workframe.conf`. Workframe opens
Cursor and VS Code in a new window; other editor commands receive the workspace
path as their final argument.
