■ FSCHRHUNT
PROJECT: code

///

STATUS: DEVELOPMENT

///

OVERVIEW:
 - Every repository gets a stable base checkout in repos/.
 - Every work session gets an isolated Git worktree in worktrees/.
 - One small Bash CLI over ordinary Git: setup, clone, new, list, remove, doctor.
 - No index, no daemon, no migration state; ownership is a marker in Git metadata.

///

INSTALL:
 curl -fsSL https://raw.githubusercontent.com/fschrhunt/code/main/scripts/install.sh | sh

START:
 code clone fschrhunt/e
 cd ~/Code/repos/e
 code new e
 # → ~/Code/worktrees/e-e
 code list
 code remove e-e

///

SAFETY:
 - Code removes only worktrees carrying its private ownership marker.
 - Dirty work refuses removal unless --force is explicit.
 - Branches are never deleted.

///

REFERENCE:
 - [Getting started](docs/getting-started.md)
 - [Concepts](docs/concepts.md)
 - [CLI reference](docs/reference/cli.md)
 - [Filesystem reference](docs/reference/filesystem.md)
