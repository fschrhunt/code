# Menubar app

Workframe has two intentional interfaces:

- **Coding agents and scripts** use the `workframe` CLI and its stable,
  machine-readable commands.
- **People on macOS** use the Workframe menubar app to continue active work,
  start a workspace, restore paused work, and archive work deliberately.

The app is a native SwiftUI companion, not a second backend. It calls the
installed CLI for all state and lifecycle operations, so the rules that protect
worktrees and branches remain in one place. In particular, archive keeps a
branch, and an app action never discards uncommitted changes unless a person
explicitly chooses that later CLI recovery path.

The interface follows the system visual language: standard macOS controls and
materials on macOS 14–25, and SwiftUI Liquid Glass surfaces on macOS 26 or
newer. Glass is reserved for actionable workspace cards and compact controls,
not used as a decorative layer over every element.

The menu-bar label is a 24×18-point, monochrome template rendering of the
Workframe brace mark. Its color comes from the system appearance, so it matches
the other status icons in light and dark menu bars; the acid brand color is
reserved for the full app icon and in-app brand surfaces.

## Build and run during development

Requirements: macOS 14 or later, Xcode 26 or later, and an installed
`workframe` command. The app discovers the CLI in `~/.local/bin`,
`/opt/homebrew/bin`, or `/usr/local/bin`. Set `WORKFRAME_EXECUTABLE` to point
at a different executable when developing.

```bash
make menubar-test
make menubar-build
open .build/Workframe.app
```

`make menubar-build` creates a standalone app bundle at
`.build/Workframe.app`. The bundle deliberately does not carry a second copy of
the shell backend: installing or upgrading the CLI updates the one backend used
by both the app and coding agents.

The bundle carries `app/Workframe.icon` as the authored Icon Composer source
for macOS 26 and later, plus `app/Workframe.icns` as its fallback for macOS
14–25. Keep both files together: change the layered icon in Icon Composer, then
regenerate the fallback from the approved 1024×1024 artwork before release.

The release process must code-sign and notarize that bundle with the release
team's Apple credentials. Those credentials and the resulting distribution
channel are deliberately outside this repository.

## Interaction model

The menubar title describes the next useful human action:

- no active workspaces → create one;
- one active workspace → continue it;
- several active workspaces → choose where to continue.

Workspace rows open the configured editor with one click and offer Finder
reveal and archive in a context menu. New workspaces use the task-owned
`workframe new <repo> <task>` model. Paused branches are shown separately and
can be restored. The app never invents a selector; it uses the full worktree
path or the repository and branch reported by the CLI.
