#!/usr/bin/env bash
# wt configuration: defaults, optional overrides, and role + path resolution.
#
# Values only. wt.conf currently contains KEY=value lines and is *sourced*; M1
# replaces this with a non-executable parser and per-user profiles under ~/.wt.

# ---- defaults (overridable via wt.conf) ----
BOX_HOST=server; BOX_USER=agents; BOX_ROOT=/mnt/agents; BOX_HOME=/mnt/agents/.home; MAC_ROOT=/Volumes/Agents
VALID_AGENTS="claude codex cursor grok devin opencode"
DEFAULT_ORG=intuitumxyz; DEFAULT_AGENT=codex; EDITOR_CMD=cursor
CACHE_DIRS="node_modules .next .turbo dist build"
CITIES="accra amman athens austin bali berlin bogota cairo dakar denver dublin geneva hanoi havana kyoto lagos lima lisbon luanda lusaka madrid manila maputo nairobi osaka oslo porto prague quito rabat reno riga rome seoul sofia taipei tokyo toledo tunis turin vienna warsaw zagreb"
for c in "$MAC_ROOT/system/config/wt.conf" "$BOX_ROOT/system/config/wt.conf"; do
  # shellcheck disable=SC1090
  [ -f "$c" ] && . "$c" 2>/dev/null && break
done

# ---- role ----
# WT_BACKEND=1 forces the backend path (used by tests today, and by local mode
# in M2). Otherwise macOS is the frontend; everything else is the backend.
if [ "${WT_BACKEND:-0}" = 1 ]; then ON_MAC=0
elif [ "$(uname)" = "Darwin" ]; then ON_MAC=1
else ON_MAC=0
fi

# ---- data root + paths ----
# WT_HOME overrides the data root (tests, and the M2 local root ~/.wt). When it
# is unset behavior is identical to the pre-split monolith.
if [ "$ON_MAC" = 1 ]; then
  ROOT="${WT_HOME:-$MAC_ROOT}"
else
  ROOT="${WT_HOME:-$BOX_ROOT}"
  # On the real box, point HOME at the box home so git finds the PAT credential
  # store. Tests set WT_HOME and keep their own HOME.
  [ -n "${WT_HOME:-}" ] || export HOME="$BOX_HOME"
  export GIT_TERMINAL_PROMPT=0
fi
# Canonicalize so our path checks match git's resolved worktree paths on hosts
# where the root is reached through a symlink (macOS /tmp and /var, a symlinked
# ~/.wt). A no-op on the production mounts (/Volumes/Agents, /mnt/agents), which
# are not symlinks — so behavior there is unchanged.
[ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
REPOS="$ROOT/repos"; WORK="$ROOT/workspaces"; LOGDIR="$ROOT/system/logs"
