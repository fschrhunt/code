#!/usr/bin/env bash
# CONFIG — local store selection and values-only configuration parsing.
# A Workframe store is local; remote mounts, SSH, editors, and shell hooks are
# deliberately outside this CLI's responsibility.

_config_safe_val(){ case "$1" in *[\`\$\(\)\;\|\&\<\>\\\'\"]*) return 1;; esac; }
_root_path_ok(){
  local path=${1:-}
  case "$path" in ""|/|[!/]*) return 1;; *$'\n'*|*$'\r'*) return 1;; esac
  _config_safe_val "$path"
}

DEFAULT_ORG=""
# Read only to migrate pre-2.0 agent-scoped stores. Never write it back.
LEGACY_AGENTS=""
WORKFRAME_ROOT_POINTER="${XDG_CONFIG_HOME:-${HOME}/.config}/workframe/root"
# shellcheck disable=SC2034
WORKFRAME_ROOT_SELECTED=0

if [ -n "${WORKFRAME_HOME:-}" ]; then
  WORKFRAME_USER_DIR=$WORKFRAME_HOME
else
  WORKFRAME_USER_DIR="$HOME/workframe"
  if [ -f "$WORKFRAME_ROOT_POINTER" ]; then
    IFS= read -r _workframe_root < "$WORKFRAME_ROOT_POINTER" || _workframe_root=""
    _workframe_root=${_workframe_root#"${_workframe_root%%[![:space:]]*}"}
    _workframe_root=${_workframe_root%"${_workframe_root##*[![:space:]]}"}
    if _root_path_ok "$_workframe_root"; then
      WORKFRAME_USER_DIR=${_workframe_root%/}
      # shellcheck disable=SC2034
      WORKFRAME_ROOT_SELECTED=1
    fi
    unset _workframe_root
  fi
fi

_set_config_paths(){
  WORKFRAME_LEGACY_CONFIG="$WORKFRAME_USER_DIR/config"
  WORKFRAME_USER_CONFIG="$WORKFRAME_USER_DIR/system/config/workframe.conf"
}
_set_local_root(){
  local root=$1
  _root_path_ok "$root" || return 1
  WORKFRAME_USER_DIR=${root%/}
  _set_config_paths
  _refresh_runtime_paths
}
_refresh_runtime_paths(){
  ROOT=${WORKFRAME_HOME:-$WORKFRAME_USER_DIR}
  [ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
  # Consumed by backend.sh after config is sourced.
  # shellcheck disable=SC2034
  REPOS="$ROOT/repos"
  # shellcheck disable=SC2034
  WORK="$ROOT/workspaces"
  # shellcheck disable=SC2034
  LOGDIR="$ROOT/system/logs"
}
_set_config_paths
_refresh_runtime_paths

_load_user_config(){
  local file=${1:-$WORKFRAME_USER_CONFIG} line key val
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%#*}; line=${line#"${line%%[![:space:]]*}"}; line=${line%"${line##*[![:space:]]}"}
    case "$line" in *=*) ;; *) continue;; esac
    key=${line%%=*}; val=${line#*=}
    key=${key#"${key%%[![:space:]]*}"}; key=${key%"${key##*[![:space:]]}"}
    val=${val#"${val%%[![:space:]]*}"}; val=${val%"${val##*[![:space:]]}"}
    _config_safe_val "$val" || continue
    case "$key" in
      default_org|DEFAULT_ORG) DEFAULT_ORG=$val;;
      agents|VALID_AGENTS)
        LEGACY_AGENTS=$(printf '%s' "$val" | tr ',;' '  ' | tr -s ' ')
        LEGACY_AGENTS=${LEGACY_AGENTS# }; LEGACY_AGENTS=${LEGACY_AGENTS% }
        ;;
    esac
  done < "$file"
}
_load_selected_user_config(){
  if [ -f "$WORKFRAME_USER_CONFIG" ]; then _load_user_config "$WORKFRAME_USER_CONFIG"
  else _load_user_config "$WORKFRAME_LEGACY_CONFIG"; fi
}
_user_config_exists(){ [ -f "$WORKFRAME_USER_CONFIG" ] || [ -f "$WORKFRAME_LEGACY_CONFIG" ]; }
_load_selected_user_config

_save_user_config(){
  local dir=${WORKFRAME_USER_CONFIG%/*} tmp
  mkdir -p "$dir" || return 1
  tmp=$(umask 077; mktemp "$dir/.workframe.conf.XXXXXX") || return 1
  {
    printf '# Workframe configuration — values only\n'
    printf 'default_org = %s\n' "$DEFAULT_ORG"
  } > "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f "$tmp" "$WORKFRAME_USER_CONFIG" || { rm -f -- "$tmp"; return 1; }
  [ "$WORKFRAME_LEGACY_CONFIG" = "$WORKFRAME_USER_CONFIG" ] || rm -f -- "$WORKFRAME_LEGACY_CONFIG" || return 1
}
_save_root_pointer(){
  [ -n "${WORKFRAME_HOME:-}" ] && return 0
  local dir=${WORKFRAME_ROOT_POINTER%/*} tmp
  mkdir -p "$dir" || return 1
  tmp=$(umask 077; mktemp "$dir/.root.XXXXXX") || return 1
  printf '%s\n' "$WORKFRAME_USER_DIR" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$WORKFRAME_ROOT_POINTER" || { rm -f -- "$tmp"; return 1; }
}

_ensure_store_guide(){
  local root target source
  root=${1:-$ROOT}; target="$root/WORKFRAME.md"; source="${WORKFRAME_LIB:-}/WORKFRAME.md"
  [ -e "$target" ] && return 0
  [ -r "$source" ] || return 1
  mkdir -p "$root" || return 1
  (set -C; umask 022; command cat "$source" > "$target") 2>/dev/null || [ -e "$target" ]
}

# Kept as a defensive boundary for historical config and direct callers.
_cache_dir_ok(){ case "$1" in ""|.|..|*/*|*\\*) return 1;; *[!A-Za-z0-9._-]*) return 1;; esac; }
_sanitize_cache_dirs(){ local out='' d; for d in $1; do _cache_dir_ok "$d" && out="$out $d"; done; printf '%s' "${out# }"; }
# Consumed by backend.sh after config is sourced.
# shellcheck disable=SC2034
CACHE_DIRS=""
