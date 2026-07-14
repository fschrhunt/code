#!/usr/bin/env bash
# wt configuration: defaults, user-owned config under ~/.wt (or $WT_HOME), and
# role + path resolution.
#
# Values only. User config is parsed (never sourced). Known keys only; values
# with shell metacharacters are rejected.

# ---- built-in defaults (product name: wt) ----
# New shared profiles suggest /Volumes/wt + /mnt/wt. Existing fleets still on
# /Volumes/Agents are auto-detected below when no user config exists yet.
BOX_HOST=server
BOX_ADDR=100.65.233.79   # IP/hostname for reachability probes (SSH Host may differ)
BOX_USER=agents
BOX_ROOT=/mnt/wt
BOX_HOME=/mnt/wt/.home
MAC_ROOT=/Volumes/wt
SHARE_NAME=wt            # SMB share name on the box
# Suggested names for `wt init` / first `agents add` — not a silent default for `new`.
SUGGESTED_AGENTS="claude codex cursor grok devin opencode"
VALID_AGENTS=""
DEFAULT_ORG=intuitumxyz
EDITOR_CMD=cursor
CACHE_DIRS="node_modules .next .turbo dist build"
CITIES="accra amman athens austin bali berlin bogota cairo dakar denver dublin geneva hanoi havana kyoto lagos lima lisbon luanda lusaka madrid manila maputo nairobi osaka oslo porto prague quito rabat reno riga rome seoul sofia taipei tokyo toledo tunis turin vienna warsaw zagreb"
WT_PROFILE_TYPE=shared   # flipped to local by `wt init` (default product path)

# User/data directory: $WT_HOME for tests/local override, else ~/.wt
if [ -n "${WT_HOME:-}" ]; then
  WT_USER_DIR="$WT_HOME"
else
  WT_USER_DIR="${HOME}/.wt"
fi
WT_USER_CONFIG="$WT_USER_DIR/config"

_config_safe_val(){
  case "$1" in *[\`\$\(\)\;\|\&\<\>\\\'\"]*) return 1;; esac
  return 0
}

_sync_box_home(){ BOX_HOME="${BOX_ROOT%/}/.home"; }

# Prefer legacy Agents mount when present and no user config yet (fleet backcompat).
_detect_legacy_agents_paths(){
  [ -f "$WT_USER_CONFIG" ] && return 0
  if [ -d /Volumes/Agents ] && [ ! -d /Volumes/wt ]; then
    MAC_ROOT=/Volumes/Agents
    BOX_ROOT=/mnt/agents
    SHARE_NAME=Agents
    _sync_box_home
  fi
}

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
      box_addr|BOX_ADDR) BOX_ADDR=$val;;
      box_user|BOX_USER) BOX_USER=$val;;
      box_root|BOX_ROOT) BOX_ROOT=$val; _sync_box_home;;
      mount_path|MAC_ROOT) MAC_ROOT=$val;;
      share_name|SHARE_NAME) SHARE_NAME=$val;;
    esac
  done < "$file"
}

_save_user_config(){
  mkdir -p "$WT_USER_DIR"
  local agents_csv
  agents_csv=$(printf '%s' "$VALID_AGENTS" | tr -s ' ' | sed 's/^ //;s/ $//;s/ /, /g')
  _sync_box_home
  {
    printf '# wt user config — values only (parsed, never sourced)\n'
    printf 'type = %s\n' "$WT_PROFILE_TYPE"
    printf 'editor = %s\n' "$EDITOR_CMD"
    printf 'default_org = %s\n' "$DEFAULT_ORG"
    printf 'agents = %s\n' "$agents_csv"
  } > "$WT_USER_CONFIG"
  if [ "$WT_PROFILE_TYPE" = shared ]; then
    {
      printf 'box_host = %s\n' "$BOX_HOST"
      printf 'box_addr = %s\n' "$BOX_ADDR"
      printf 'box_user = %s\n' "$BOX_USER"
      printf 'box_root = %s\n' "$BOX_ROOT"
      printf 'mount_path = %s\n' "$MAC_ROOT"
      printf 'share_name = %s\n' "$SHARE_NAME"
    } >> "$WT_USER_CONFIG"
  fi
}

_detect_legacy_agents_paths
_load_user_config

# Legacy shared wt.conf may still set editor/org + box knobs (ignore DEFAULT_AGENT).
for c in "$MAC_ROOT/system/config/wt.conf" "$BOX_ROOT/system/config/wt.conf" \
         /Volumes/Agents/system/config/wt.conf /mnt/agents/system/config/wt.conf; do
  if [ -f "$c" ]; then
    local_line=""
    while IFS= read -r local_line || [ -n "$local_line" ]; do
      case "$local_line" in
        EDITOR_CMD=*|DEFAULT_ORG=*|BOX_HOST=*|BOX_USER=*|BOX_ROOT=*|MAC_ROOT=*|BOX_ADDR=*|SHARE_NAME=*)
          key=${local_line%%=*}; val=${local_line#*=}
          _config_safe_val "$val" || continue
          case "$key" in
            EDITOR_CMD) EDITOR_CMD=$val;;
            DEFAULT_ORG) DEFAULT_ORG=$val;;
            BOX_HOST) BOX_HOST=$val;;
            BOX_ADDR) BOX_ADDR=$val;;
            BOX_USER) BOX_USER=$val;;
            BOX_ROOT) BOX_ROOT=$val; _sync_box_home;;
            MAC_ROOT) MAC_ROOT=$val;;
            SHARE_NAME) SHARE_NAME=$val;;
          esac
          ;;
      esac
    done < "$c"
    break
  fi
done

# ---- role ----
if [ "${WT_BACKEND:-0}" = 1 ]; then ON_MAC=0
elif [ "$(uname)" = "Darwin" ]; then ON_MAC=1
else ON_MAC=0
fi

# ---- data root + paths ----
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
[ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
REPOS="$ROOT/repos"; WORK="$ROOT/workspaces"; LOGDIR="$ROOT/system/logs"

_is_local_store(){
  [ "${WT_PROFILE_TYPE:-shared}" = local ]
}

_box_reachable(){
  local host="${BOX_ADDR:-$BOX_HOST}"
  /usr/bin/nc -z -G 2 "$host" 22 2>/dev/null
}
