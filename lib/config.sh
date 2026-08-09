#!/usr/bin/env bash
# workframe configuration: defaults, user-owned store config, persistent local
# root selection, and role + path resolution.
#
# Values only. User config is parsed (never sourced). Known keys only; values
# with shell metacharacters are rejected.
#
# Product defaults are neutral. Shared-stack hosts/paths/org live in the selected
# store's config (filled by `workframe setup --shared` / `workframe config`), not
# in this file.

_config_safe_val(){
  case "$1" in *[\`\$\(\)\;\|\&\<\>\\\'\"]*) return 1;; esac
  return 0
}

_root_path_ok(){
  local path=${1:-}
  case "$path" in
    ""|/|[!/]*) return 1;;
    *$'\n'*|*$'\r'*) return 1;;
  esac
  _config_safe_val "$path"
}

# ---- built-in defaults (neutral product) ----
BOX_HOST=""
BOX_ADDR=""
BOX_USER=""
BOX_ROOT=""
BOX_HOME=""
MAC_ROOT=""
SHARE_NAME=""
VALID_AGENTS=""
DEFAULT_ORG=""
# Cursor-oriented default; override with editor= in the selected store config.
EDITOR_CMD=cursor
# Optional worktree exclude list (override via cache_dirs= in config).
CACHE_DIRS="node_modules .next .turbo dist build"
# Shared-only: link CACHE_DIRS into ~/.workframe-cache (off by default — opt in).
LOCALDEPS=0
# Local until the user opts into shared via setup/config (or an existing config).
WORKFRAME_PROFILE_TYPE=local

# WORKFRAME_HOME is an explicit process override used by tests and backend
# execution. Otherwise, a small per-user locator remembers a root selected by
# `workframe setup`; existing installs still fall back to ~/workframe.
WORKFRAME_ROOT_POINTER="${XDG_CONFIG_HOME:-${HOME}/.config}/workframe/root"
# Used by the entry point and frontend module (linted separately).
# shellcheck disable=SC2034
WORKFRAME_ROOT_SELECTED=0
if [ -n "${WORKFRAME_HOME:-}" ]; then
  WORKFRAME_USER_DIR="$WORKFRAME_HOME"
else
  WORKFRAME_USER_DIR="${HOME}/workframe"
  if [ -f "$WORKFRAME_ROOT_POINTER" ]; then
    IFS= read -r _workframe_selected_root < "$WORKFRAME_ROOT_POINTER" || _workframe_selected_root=""
    _workframe_selected_root=${_workframe_selected_root#"${_workframe_selected_root%%[![:space:]]*}"}
    _workframe_selected_root=${_workframe_selected_root%"${_workframe_selected_root##*[![:space:]]}"}
    if _root_path_ok "$_workframe_selected_root"; then
      WORKFRAME_USER_DIR=${_workframe_selected_root%/}
      # shellcheck disable=SC2034
      WORKFRAME_ROOT_SELECTED=1
    fi
    unset _workframe_selected_root
  fi
fi

_set_config_paths(){
  WORKFRAME_LEGACY_CONFIG="$WORKFRAME_USER_DIR/config"
  WORKFRAME_USER_CONFIG="$WORKFRAME_USER_DIR/system/config/workframe.conf"
}
_set_config_paths

_set_local_root(){
  local root=${1:-}
  _root_path_ok "$root" || return 1
  root=${root%/}
  WORKFRAME_USER_DIR=$root
  _set_config_paths
  ROOT=$root
  [ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
  REPOS="$ROOT/repos"
  WORK="$ROOT/workspaces"
  LOGDIR="$ROOT/system/logs"
}

_save_root_pointer(){
  [ -n "${WORKFRAME_HOME:-}" ] && return 0
  _root_path_ok "$WORKFRAME_USER_DIR" || return 1
  local pointer_dir tmp
  pointer_dir=${WORKFRAME_ROOT_POINTER%/*}
  mkdir -p "$pointer_dir" || return 1
  tmp=$(umask 077; mktemp "$pointer_dir/.root.XXXXXX") || return 1
  printf '%s\n' "$WORKFRAME_USER_DIR" > "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f "$tmp" "$WORKFRAME_ROOT_POINTER" || { rm -f -- "$tmp"; return 1; }
}

# Install the product-owned store guide exactly once. Noclobber protects an
# existing user file even if another initializer creates it between the first
# existence check and the write.
_ensure_store_guide(){
  local root=${1:-${ROOT:-}} guide source
  [ -n "$root" ] || return 1
  guide="$root/WORKFRAME.md"
  source="${WORKFRAME_LIB:-}/WORKFRAME.md"
  [ -e "$guide" ] && return 0
  [ -r "$source" ] || return 1
  mkdir -p "$root" || return 1
  if (
    set -C
    umask 022
    command cat "$source" > "$guide"
  ) 2>/dev/null; then
    return 0
  fi
  [ -e "$guide" ]
}

# A cache dir must be a single path segment directly under the worktree.
# mac_localdeps does `rm -rf "$worktree/$d"` for each entry, so a value containing a
# slash or dot-dot escapes the worktree: cache_dirs="../other-worktree" would
# delete a sibling worktree's contents. _config_safe_val only screens shell
# metacharacters, not path traversal. Same rules as _repo_name_ok.
_cache_dir_ok(){
  case "$1" in
    ""|"."|".."|*/*|*\\*) return 1;;
    *[!A-Za-z0-9._-]*) return 1;;
  esac
  return 0
}
# Drop any entry that is not a safe single segment. Silently — a bad value in a
# config file should degrade to "not cached", never to a destructive path.
_sanitize_cache_dirs(){
  local out='' d
  for d in $1; do _cache_dir_ok "$d" && out="$out $d"; done
  printf '%s' "${out# }"
}

_sync_box_home(){
  [ -n "$BOX_ROOT" ] && BOX_HOME="${BOX_ROOT%/}/.home" || BOX_HOME=""
}

_load_user_config(){
  local file="${1:-$WORKFRAME_USER_CONFIG}"
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
      type|profile_type) WORKFRAME_PROFILE_TYPE=$val;;
      editor|EDITOR_CMD) EDITOR_CMD=$val;;
      default_org|DEFAULT_ORG) DEFAULT_ORG=$val;;
      agents|VALID_AGENTS)
        VALID_AGENTS=$(printf '%s' "$val" | tr ',;' '  ' | tr -s ' ')
        VALID_AGENTS=${VALID_AGENTS# }
        VALID_AGENTS=${VALID_AGENTS% }
        ;;
      cache_dirs|CACHE_DIRS)
        CACHE_DIRS=$(printf '%s' "$val" | tr ',;' '  ' | tr -s ' ')
        CACHE_DIRS=${CACHE_DIRS# }
        CACHE_DIRS=${CACHE_DIRS% }
        CACHE_DIRS=$(_sanitize_cache_dirs "$CACHE_DIRS")
        ;;
      localdeps|LOCALDEPS)
        case "$val" in
          1|true|yes|on) LOCALDEPS=1;;
          *) LOCALDEPS=0;;
        esac
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

_load_selected_user_config(){
  if [ -f "$WORKFRAME_USER_CONFIG" ]; then
    _load_user_config "$WORKFRAME_USER_CONFIG"
  elif [ -f "$WORKFRAME_LEGACY_CONFIG" ]; then
    _load_user_config "$WORKFRAME_LEGACY_CONFIG"
  fi
}

_user_config_exists(){
  [ -f "$WORKFRAME_USER_CONFIG" ] || [ -f "$WORKFRAME_LEGACY_CONFIG" ]
}

_save_user_config(){
  local agents_csv cache_csv config_dir tmp
  config_dir=${WORKFRAME_USER_CONFIG%/*}
  mkdir -p "$config_dir"
  agents_csv=$(printf '%s' "$VALID_AGENTS" | tr -s ' ' | sed 's/^ //;s/ $//;s/ /, /g')
  cache_csv=$(printf '%s' "$CACHE_DIRS" | tr -s ' ' | sed 's/^ //;s/ $//;s/ /, /g')
  _sync_box_home
  tmp=$(umask 077; mktemp "$config_dir/.workframe.conf.XXXXXX") || return 1
  {
    printf '# workframe user config — values only (parsed, never sourced)\n'
    printf 'type = %s\n' "$WORKFRAME_PROFILE_TYPE"
    printf 'editor = %s\n' "$EDITOR_CMD"
    printf 'default_org = %s\n' "$DEFAULT_ORG"
    printf 'agents = %s\n' "$agents_csv"
    printf 'cache_dirs = %s\n' "$cache_csv"
    printf 'localdeps = %s\n' "$LOCALDEPS"
    if [ "$WORKFRAME_PROFILE_TYPE" = shared ]; then
      printf 'box_host = %s\n' "$BOX_HOST"
      printf 'box_addr = %s\n' "$BOX_ADDR"
      printf 'box_user = %s\n' "$BOX_USER"
      printf 'box_root = %s\n' "$BOX_ROOT"
      printf 'mount_path = %s\n' "$MAC_ROOT"
      printf 'share_name = %s\n' "$SHARE_NAME"
    fi
  } > "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f "$tmp" "$WORKFRAME_USER_CONFIG" || { rm -f -- "$tmp"; return 1; }
  if [ "$WORKFRAME_LEGACY_CONFIG" != "$WORKFRAME_USER_CONFIG" ] && [ -f "$WORKFRAME_LEGACY_CONFIG" ]; then
    rm -f -- "$WORKFRAME_LEGACY_CONFIG" || return 1
  fi
}

_load_selected_user_config

# Optional overlay from the active store's workframe.conf (values only), after user config
# has established MAC_ROOT / BOX_ROOT. Never clobber editor/org; only fill empty
# shared-stack fields so a fleet workframe.conf cannot stomp user preferences.
for c in \
  ${MAC_ROOT:+"$MAC_ROOT/system/config/workframe.conf"} \
  ${BOX_ROOT:+"$BOX_ROOT/system/config/workframe.conf"}; do
  [ -n "$c" ] && [ -f "$c" ] || continue
  local_line=""
  while IFS= read -r local_line || [ -n "$local_line" ]; do
    case "$local_line" in
      BOX_HOST=*|BOX_USER=*|BOX_ROOT=*|MAC_ROOT=*|BOX_ADDR=*|SHARE_NAME=*)
        key=${local_line%%=*}; val=${local_line#*=}
        _config_safe_val "$val" || continue
        case "$key" in
          BOX_HOST) [ -z "$BOX_HOST" ] && BOX_HOST=$val;;
          BOX_ADDR) [ -z "$BOX_ADDR" ] && BOX_ADDR=$val;;
          BOX_USER) [ -z "$BOX_USER" ] && BOX_USER=$val;;
          BOX_ROOT) [ -z "$BOX_ROOT" ] && { BOX_ROOT=$val; _sync_box_home; };;
          MAC_ROOT) [ -z "$MAC_ROOT" ] && MAC_ROOT=$val;;
          SHARE_NAME) [ -z "$SHARE_NAME" ] && SHARE_NAME=$val;;
        esac
        ;;
    esac
  done < "$c"
  break
done

# Mac shared frontend injects the agent list over SSH (see _bx). Takes precedence
# for the box process so `workframe agents add` on the Mac is authoritative.
if [ -n "${WORKFRAME_VALID_AGENTS:-}" ]; then
  VALID_AGENTS=$(printf '%s' "$WORKFRAME_VALID_AGENTS" | tr ',;' '  ' | tr -s ' ')
  VALID_AGENTS=${VALID_AGENTS# }
  VALID_AGENTS=${VALID_AGENTS% }
fi

# ---- data root + paths ----
# Re-evaluate these whenever setup or config changes profile. Keeping this in
# one function prevents an interactive session from using the previous store.
_refresh_runtime_paths(){
  _sync_box_home
  # Frontend (any OS) keeps the user's HOME and uses the local mount path.
  # Only the WORKFRAME_BACKEND=1 store process remaps HOME to BOX_HOME and
  # disables Git prompts for the shared box.
  if [ -n "${WORKFRAME_HOME:-}" ]; then
    ROOT="$WORKFRAME_HOME"
  elif [ "$WORKFRAME_PROFILE_TYPE" = local ]; then
    ROOT="$WORKFRAME_USER_DIR"
  elif [ "${WORKFRAME_BACKEND:-0}" = 1 ]; then
    ROOT="${BOX_ROOT:-$WORKFRAME_USER_DIR}"
    [ -n "$BOX_HOME" ] && export HOME="$BOX_HOME"
    export GIT_TERMINAL_PROMPT=0
  else
    ROOT="${MAC_ROOT:-$WORKFRAME_USER_DIR}"
  fi
  [ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
  # Used by backend/frontend modules (linted separately from this file).
  # shellcheck disable=SC2034
  REPOS="$ROOT/repos"
  # shellcheck disable=SC2034
  WORK="$ROOT/workspaces"
  # shellcheck disable=SC2034
  LOGDIR="$ROOT/system/logs"
}
_refresh_runtime_paths

_is_local_store(){
  [ "${WORKFRAME_PROFILE_TYPE}" = local ]
}

_require_shared_stack(){
  [ -n "$BOX_HOST" ] && [ -n "$BOX_USER" ] && [ -n "$BOX_ROOT" ] && [ -n "$MAC_ROOT" ] || \
    die "shared profile incomplete — run: workframe config  (need box_host, box_user, box_root, mount_path)"
}

_box_reachable(){
  local host="${BOX_ADDR:-$BOX_HOST}" nc="${NC_BIN:-/usr/bin/nc}"
  [ -n "$host" ] || return 1
  [ -x "$nc" ] || nc=$(command -v nc 2>/dev/null) || return 1
  # macOS nc uses -G for connect timeout; Linux/OpenBSD nc uses -w.
  case "$(uname)" in
    Darwin) "$nc" -z -G 2 "$host" 22 2>/dev/null;;
    *) "$nc" -z -w 2 "$host" 22 2>/dev/null;;
  esac
}
