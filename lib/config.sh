#!/usr/bin/env bash
# wt configuration: defaults, user-owned config under ~/.wt (or $WT_HOME), and
# role + path resolution.
#
# Values only. User config is parsed (never sourced). Known keys only; values
# with shell metacharacters are rejected.

# ---- built-in defaults ----
BOX_HOST=server; BOX_USER=agents; BOX_ROOT=/mnt/agents; BOX_HOME=/mnt/agents/.home; MAC_ROOT=/Volumes/Agents
# Suggested names for `wt init` / first `agents add` help — not a silent default for `new`.
SUGGESTED_AGENTS="claude codex cursor grok devin opencode"
VALID_AGENTS=""   # populated from user config; empty until agents are added
DEFAULT_ORG=intuitumxyz
EDITOR_CMD=cursor
CACHE_DIRS="node_modules .next .turbo dist build"
CITIES="accra amman athens austin bali berlin bogota cairo dakar denver dublin geneva hanoi havana kyoto lagos lima lisbon luanda lusaka madrid manila maputo nairobi osaka oslo porto prague quito rabat reno riga rome seoul sofia taipei tokyo toledo tunis turin vienna warsaw zagreb"
WT_PROFILE_TYPE=shared   # local | shared — local becomes default after `wt init`

# User/data directory: $WT_HOME for tests/local override, else ~/.wt
if [ -n "${WT_HOME:-}" ]; then
  WT_USER_DIR="$WT_HOME"
else
  WT_USER_DIR="${HOME}/.wt"
fi
WT_USER_CONFIG="$WT_USER_DIR/config"

# Safe value check: reject shell metacharacters
_config_safe_val(){
  case "$1" in *[\`\$\(\)\;\|\&\<\>\\\'\"]*) return 1;; esac
  return 0
}

# Parse a key=value (or key = value) config file into globals.
_load_user_config(){
  local file="${1:-$WT_USER_CONFIG}"
  [ -f "$file" ] || return 0
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%#*}
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [ -z "$line" ] && continue
    case "$line" in *=*) ;; *) continue;; esac
    key=${line%%=*}
    val=${line#*=}
    key=${key%"${key##*[![:space:]]}"}
    key=${key#"${key%%[![:space:]]*}"}
    val=${val#"${val%%[![:space:]]*}"}
    val=${val%"${val##*[![:space:]]}"}
    _config_safe_val "$val" || continue
    case "$key" in
      type|profile_type) WT_PROFILE_TYPE=$val;;
      editor|EDITOR_CMD) EDITOR_CMD=$val;;
      default_org|DEFAULT_ORG) DEFAULT_ORG=$val;;
      agents|VALID_AGENTS)
        VALID_AGENTS=$(printf '%s' "$val" | tr ',;' '  ' | tr -s ' ')
        VALID_AGENTS=${VALID_AGENTS# }
        VALID_AGENTS=${VALID_AGENTS% }
        ;;
      box_host|BOX_HOST) BOX_HOST=$val;;
      box_user|BOX_USER) BOX_USER=$val;;
      box_root|BOX_ROOT) BOX_ROOT=$val;;
      mount_path|MAC_ROOT) MAC_ROOT=$val;;
    esac
  done < "$file"
}

# Write current agents/editor/org/type back to the user config (preserve unknown? rewrite known).
_save_user_config(){
  mkdir -p "$WT_USER_DIR"
  local agents_csv
  agents_csv=$(printf '%s' "$VALID_AGENTS" | tr -s ' ' | sed 's/^ //;s/ $//;s/ /, /g')
  cat > "$WT_USER_CONFIG" <<EOF
# wt user config — values only (parsed, never sourced)
type = ${WT_PROFILE_TYPE}
editor = ${EDITOR_CMD}
default_org = ${DEFAULT_ORG}
agents = ${agents_csv}
EOF
  if [ "$WT_PROFILE_TYPE" = shared ]; then
    cat >> "$WT_USER_CONFIG" <<EOF
box_host = ${BOX_HOST}
box_user = ${BOX_USER}
box_root = ${BOX_ROOT}
mount_path = ${MAC_ROOT}
EOF
  fi
}

_load_user_config

# Legacy shared wt.conf may still set EDITOR_CMD / DEFAULT_ORG (ignore DEFAULT_AGENT).
for c in "$MAC_ROOT/system/config/wt.conf" "$BOX_ROOT/system/config/wt.conf"; do
  if [ -f "$c" ]; then
    local_line=""
    while IFS= read -r local_line || [ -n "$local_line" ]; do
      case "$local_line" in
        EDITOR_CMD=*|DEFAULT_ORG=*|BOX_HOST=*|BOX_USER=*|BOX_ROOT=*|MAC_ROOT=*)
          key=${local_line%%=*}; val=${local_line#*=}
          _config_safe_val "$val" || continue
          case "$key" in
            EDITOR_CMD) EDITOR_CMD=$val;;
            DEFAULT_ORG) DEFAULT_ORG=$val;;
            BOX_HOST) BOX_HOST=$val;;
            BOX_USER) BOX_USER=$val;;
            BOX_ROOT) BOX_ROOT=$val;;
            MAC_ROOT) MAC_ROOT=$val;;
          esac
          ;;
      esac
    done < "$c"
    break
  fi
done

# ---- role ----
# WT_BACKEND=1 forces the backend path (tests, and local-mode cmd_* calls).
# Local profile on Darwin still uses the Mac frontend UI, but runs cmd_* in-process.
if [ "${WT_BACKEND:-0}" = 1 ]; then ON_MAC=0
elif [ "$(uname)" = "Darwin" ]; then ON_MAC=1
else ON_MAC=0
fi

# ---- data root + paths ----
# Local profile: store under WT_USER_DIR (~/.wt or $WT_HOME).
# Shared: Mac mount / box root (unless WT_HOME overrides for tests).
if [ -n "${WT_HOME:-}" ]; then
  ROOT="$WT_HOME"
elif [ "$WT_PROFILE_TYPE" = local ]; then
  ROOT="$WT_USER_DIR"
elif [ "$ON_MAC" = 1 ]; then
  ROOT="$MAC_ROOT"
else
  ROOT="$BOX_ROOT"
  export HOME="$BOX_HOME"
  export GIT_TERMINAL_PROMPT=0
fi
# Canonicalize so our path checks match git's resolved worktree paths on hosts
# where the root is reached through a symlink (macOS /tmp and /var, a symlinked
# ~/.wt). A no-op on the production mounts (/Volumes/Agents, /mnt/agents), which
# are not symlinks — so behavior there is unchanged.
[ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
REPOS="$ROOT/repos"; WORK="$ROOT/workspaces"; LOGDIR="$ROOT/system/logs"

# True when Mac UI should run git verbs in-process (local profile or WT_HOME tests via frontend).
_is_local_store(){
  [ "$WT_PROFILE_TYPE" = local ] || { [ -n "${WT_HOME:-}" ] && [ "${WT_BACKEND:-0}" != 1 ]; }
}
