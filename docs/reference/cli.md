# Wizard reference

Workframe is a guided terminal application. For normal use, run:

```text
workframe
```

`wf` is a short name for the same executable, so `wf` and any `wf <command>`
behave exactly like the `workframe` form used throughout this documentation.

The first run opens setup. Later runs return to the main menu. You can cancel
any picker or prompt without changing state.

## Main menu

| Choose | To |
|---|---|
| **Start a new workspace** | Choose a repository, agent identity, and feature name |
| **Continue working** | Choose and open an existing workspace |
| **Manage workspace lifecycle** | Browse, rename, archive, restore, or permanently delete archived work |
| **Manage repositories** | Add, browse, sync, clean, or safely delete canonical repositories |
| **Settings and agents** | Change editor, organization, profile, shared connection details, or agent identities |
| **System health** | See status, run diagnostics, or safely update a checkout installation |

## Setup

The setup flow asks whether the store is local or shared, then asks only for
the details needed for that profile. A local profile offers `~/workframe` and
accepts another absolute path. A shared profile asks for the remote box and
local mount details. It also creates `WORKFRAME.md` when missing without
overwriting an existing guide.

## Safety

The wizard asks for a selection before acting. Archive keeps the branch;
restoring recreates its worktree. Permanent operations are kept in their own
menus, require confirmation, and unsafe dirty work needs an additional
explicit confirmation.

## Support interface

```text
workframe help
workframe version
```

`help`, `-h`, and `--help` describe the wizard. `version`, `-v`, and
`--version` print the installed version.

## Automation compatibility

The previous direct-action verbs remain available for existing scripts and for
the internal local/shared backend. They are not needed for interactive use and
are deliberately omitted from the wizard-facing documentation. Automation
should set `WORKFRAME_BACKEND=1`, `WORKFRAME_HOME`, `WORKFRAME_AGENT`, and
`WORKFRAME_COLOR` as appropriate; see the
[configuration reference](configuration.md).
