# Menubar app

Workframe has two intentional interfaces:

- **Coding agents and scripts** use the `workframe` CLI and its stable,
  machine-readable commands.
- **People on macOS** use the Workframe menubar app to continue active work,
  start a workspace, restore paused work, and archive work deliberately.

The app is a native SwiftUI companion, not a second backend. The Homebrew cask
bundles the same shell CLI release inside the signed app and exports it as
`workframe` and `wf`. The app calls that embedded CLI, so the rules that protect
worktrees and branches remain in one place and an app upgrade cannot drift from
the command-line backend. In particular, archive keeps a branch, and an app
action never discards uncommitted changes unless a person explicitly chooses
that later CLI recovery path.

The interface follows the system visual language: standard macOS controls and
materials on macOS 14–25, and SwiftUI Liquid Glass surfaces on macOS 26 or
newer. Glass is reserved for actionable workspace cards and compact controls,
not used as a decorative layer over every element.

The menu-bar label is a 24×18-point, monochrome template rendering of the
Workframe brace mark. Its color comes from the system appearance, so it matches
the other status icons in light and dark menu bars; the acid brand color is
reserved for the full app icon and in-app brand surfaces.

## Build and run during development

Requirements: macOS 14 or later and Xcode 26 or later. The release bundle
contains its own CLI. Set `WORKFRAME_EXECUTABLE` to point at a different
executable when developing; otherwise the app first uses its embedded backend,
then falls back to `~/.local/bin`, `/opt/homebrew/bin`, or `/usr/local/bin`.

```bash
make menubar-test
make menubar-build
open .build/Workframe.app
```

`make menubar-build` creates a standalone app bundle at
`.build/Workframe.app`. The bundle carries `bin/`, `lib/`, and `VERSION` under
`Contents/Resources/workframe`. The Homebrew cask supplies shell wrappers for
both command names that execute this bundled copy.

The bundle carries `app/Workframe.icon` as the authored Icon Composer source
for macOS 26 and later, plus `app/Workframe.icns` as its fallback for macOS
14–25. Keep both files together: change the layered icon in Icon Composer, then
regenerate the fallback from the approved 1024×1024 artwork before release.

## Install and update

Install the complete macOS surface with:

```bash
brew install --cask fschrhunt/tap/workframe
```

The cask installs `Workframe.app` and provides `workframe` / `wf` in Homebrew's
bin directory. If the older CLI-only formula is already installed, uninstall
that formula before installing the cask so its command links do not conflict.
Existing store data is in the user's Workframe root and is unaffected by
changing packages.

```bash
brew uninstall --formula fschrhunt/tap/workframe
brew install --cask fschrhunt/tap/workframe
```

The app checks `brew outdated --cask` at launch. When a newer version is
available, its header displays an **Update &lt;version&gt;** pill. Selecting it runs
`brew upgrade --cask workframe`, then offers a restart. In a terminal,
`workframe update` delegates to the same cask upgrade.

## Release security

Only ship a signed and notarized cask archive. The release environment supplies
the Developer ID Application signing identity and a `notarytool` keychain
profile; neither belongs in this repository:

```bash
WORKFRAME_SIGNING_IDENTITY='Developer ID Application: …' \
WORKFRAME_NOTARY_PROFILE=workframe-notary \
make menubar-release
```

That command builds the release app, signs it with the hardened runtime and
secure timestamp, submits the archive to Apple notarization, staples the
returned ticket, verifies it with Gatekeeper, and prints a command that
generates the checksum-pinned cask stanza for the Homebrew tap. Apple
notarization is the Gatekeeper protection against altered or known-malicious
direct-distribution software; it cannot promise that every third-party
antivirus will never produce a false positive.

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
