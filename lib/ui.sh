#!/usr/bin/env bash
# UI — static command reference. Diagnostics live in palette.sh; commands emit
# plain data and never prompt or animate.

_help(){
  cat <<'EOF'
Workframe — owned Git worktrees for parallel tasks.

Start
  workframe setup [--root <path>] [--org <name>]
  workframe clone <owner/repo | url | path>
  workframe new [--offline] <repo> <task>

Work
  workframe list [archived] [--repo <name>] [--dirty] [--json]
  workframe path <repo/task | branch | path>
  workframe current
  workframe run <repo/task | branch | path> -- <command> [args...]

Lifecycle
  workframe archive <selector> --yes [--force]
  workframe restore <repo> <task>
  workframe remove branch <repo> <task> --yes
  workframe migrate [--yes]

Inspect
  workframe repos
  workframe worktrees [--json]
  workframe status
  workframe doctor

Workframe only manages branches it created or migrated. They are recorded in
private Git refs; unmarked Git worktrees, including Conductor workspaces, are
never listed or changed. Use `wf` as a short alias.
EOF
}
