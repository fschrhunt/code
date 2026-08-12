#!/usr/bin/env bash
# FRONTEND — small, scriptable local interface over Workframe's Git backend.
# stdout is data; commands neither mutate shell state nor open programs.

_json_escape(){
  local value=$1
  value=${value//\\/\\\\}; value=${value//\"/\\\"}; value=${value//$'\n'/\\n}; value=${value//$'\r'/\\r}; value=${value//$'\t'/\\t}
  printf '%s' "$value"
}
_json_string(){ printf '"'; _json_escape "$1"; printf '"'; }

# Resolve only explicit, stable identities: repo/task, branch, or an exact path.
# City labels are deliberately not selectors: they are random implementation detail.
_resolve_worktree(){
  local selector=$1 rows matches count repo city path branch
  rows=$(cmd_worktrees)
  matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r repo city path branch; do
    [ "$path" = "$selector" ] || [ "$branch" = "$selector" ] || [ "$selector" = "$repo/$branch" ] || continue
    printf '%s\n' "$path"
  done)
  count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" = 1 ] && { printf '%s' "$matches"; return 0; }
  [ "$count" = 0 ] && die "no Workframe workspace matching '$selector'"
  die "'$selector' matches multiple Workframe workspaces — use repo/task or path"
}

_resolve_archived(){
  local repo=$1 branch=$2
  _managed_branch "$repo" "$branch" || die "branch is not managed by Workframe"
  git -C "$(_canon "$repo")" show-ref --verify --quiet "refs/heads/$branch" || die "no such branch: $repo/$branch"
}

_setup_usage(){ printf 'usage: workframe setup --root <path> [--org <name>]\n'; }

# Configure a local store. Humans choose one absolute path interactively;
# automation supplies the same path explicitly with --root.
mac_setup(){
  local root="" org=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --root) [ $# -ge 2 ] || die 'missing value for --root'; root=$2; shift 2;;
      --org) [ $# -ge 2 ] || die 'missing value for --org'; org=$2; shift 2;;
      -h|--help) _setup_usage; return 0;;
      *) die "$(_setup_usage)";;
    esac
  done
  if [ -z "$root" ]; then
    [ -t 0 ] && [ -t 2 ] || die 'usage: workframe setup --root <path> [--org <name>]'
    printf 'Where should Workframe store repositories and workspaces?\nEnter path> ' >&2
    IFS= read -r root || die 'setup cancelled'
  fi
  root=${root%/}
  _root_path_ok "$root" || die "invalid root '$root' — use an absolute path other than /"
  # setup chooses the persistent store; a test/one-shot WORKFRAME_HOME override
  # must not silently replace the path the operator just entered.
  unset WORKFRAME_HOME
  _set_local_root "$root" || die "invalid root '$root'"
  # Used by config/backend after this frontend module returns.
  # shellcheck disable=SC2034
  [ -z "$org" ] || { _config_safe_val "$org" || die 'unsafe org value'; DEFAULT_ORG=$org; }
  # shellcheck disable=SC2034
  WORKFRAME_PROFILE_TYPE=local
  mkdir -p "$WORKFRAME_USER_DIR/repos" "$WORKFRAME_USER_DIR/workspaces" "$WORKFRAME_USER_DIR/system/logs"
  _ensure_store_guide "$WORKFRAME_USER_DIR" || die "could not create Workframe guide at $WORKFRAME_USER_DIR/WORKFRAME.md"
  _save_user_config || die "could not save Workframe config at $WORKFRAME_USER_CONFIG"
  _save_root_pointer || die "could not remember Workframe root"
  _refresh_runtime_paths
  printf 'initialized: %s\n' "$WORKFRAME_USER_DIR"
}
mac_new(){
  [ $# -eq 2 ] || die 'usage: workframe new <repo> <task>'
  cmd_new "$@"
}

_print_worktrees_json(){
  local rows=$1 first=1 repo city path branch dirty
  printf '['
  while IFS=$'\t' read -r repo city path branch; do
    [ -n "$path" ] || continue
    dirty=false; [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && dirty=true
    [ "$first" = 1 ] || printf ','; first=0
    printf '{"repo":'; _json_string "$repo"
    printf ',"task":'; _json_string "$branch"
    printf ',"path":'; _json_string "$path"
    printf ',"dirty":%s}' "$dirty"
  done <<< "$rows"
  printf ']\n'
}

mac_list(){
  local archived=0 repo="" dirty=0 json=0 rows out="" r city path branch is_dirty first=1
  while [ $# -gt 0 ]; do
    case "$1" in
      archived|--archived) archived=1; shift;;
      --repo) [ $# -ge 2 ] || die 'missing value for --repo'; repo=$2; shift 2;;
      --dirty) dirty=1; shift;;
      --json) json=1; shift;;
      *) die 'usage: workframe list [archived] [--repo <name>] [--dirty] [--json]';;
    esac
  done
  if [ "$archived" = 1 ]; then
    rows=$(cmd_archived)
    if [ "$json" = 1 ]; then
      printf '['
      while IFS=$'\t' read -r r branch _when; do
        : "$_when"
        [ -n "$branch" ] || continue; [ -z "$repo" ] || [ "$repo" = "$r" ] || continue
        [ "$first" = 1 ] || printf ','; first=0
        printf '{"repo":'; _json_string "$r"; printf ',"task":'; _json_string "$branch"; printf '}'
      done <<< "$rows"
      printf ']\n'; return
    fi
    while IFS=$'\t' read -r r branch _when; do
      : "$_when"
      [ -n "$branch" ] || continue; [ -z "$repo" ] || [ "$repo" = "$r" ] || continue
      printf '%s/%s\n' "$r" "$branch"
    done <<< "$rows"
    return
  fi
  rows=$(cmd_worktrees)
  while IFS=$'\t' read -r r city path branch; do
    [ -n "$path" ] || continue; [ -z "$repo" ] || [ "$repo" = "$r" ] || continue
    is_dirty=0; [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && is_dirty=1
    [ "$dirty" = 0 ] || [ "$is_dirty" = 1 ] || continue
    out+="$r"$'\t'"$city"$'\t'"$path"$'\t'"$branch"$'\n'
  done <<< "$rows"
  [ "$json" = 1 ] && { _print_worktrees_json "$out"; return; }
  while IFS=$'\t' read -r r city path branch; do
    [ -n "$path" ] || continue
    is_dirty=no; [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && is_dirty=yes
    printf '%-28s %-5s %s\n' "$r/$branch" "$is_dirty" "$path"
  done <<< "$out"
}

mac_worktrees(){
  case "${1:-}" in
    '') cmd_worktrees;;
    --json) [ $# -eq 1 ] || die 'usage: workframe worktrees [--json]'; _print_worktrees_json "$(cmd_worktrees)";;
    *) die 'usage: workframe worktrees [--json]';;
  esac
}
mac_repos(){ [ $# -eq 0 ] || die 'usage: workframe repos'; cmd_repos; }
mac_sync(){ cmd_sync "$@"; }
# Re-run the verified release installer. The installer replaces only Workframe's
# versioned payload and command links; it never changes a configured store.
mac_update(){
  [ $# -eq 0 ] || die 'usage: workframe update'
  command -v curl >/dev/null 2>&1 || die 'curl is required to update Workframe'
  curl -fsSL "${WORKFRAME_INSTALLER_URL:-https://raw.githubusercontent.com/fschrhunt/workframe/main/scripts/install.sh}" | sh
}
mac_path(){ [ $# -eq 1 ] || die 'usage: workframe path <repo/task|branch|path>'; _resolve_worktree "$1"; printf '\n'; }
mac_current(){
  [ $# -eq 0 ] || die 'usage: workframe current'
  local here; here=$(pwd -P)
  while IFS=$'\t' read -r repo city path branch; do
    case "$here" in "$path"|"$path"/*) printf '%s/%s\n' "$repo" "$branch"; return 0;; esac
  done < <(cmd_worktrees)
  die 'not inside a Workframe workspace'
}
mac_run(){
  [ $# -ge 3 ] && [ "$2" = -- ] || die 'usage: workframe run <repo/task|branch|path> -- <command> [args...]'
  local path; path=$(_resolve_worktree "$1"); shift 2
  (cd "$path" && "$@")
}
mac_archive(){
  local selector="" force="" yes=""
  while [ $# -gt 0 ]; do
    case "$1" in --force) force=--force; shift;; --yes) yes=--yes; shift;; *) [ -z "$selector" ] || die 'usage: workframe archive <selector> --yes [--force]'; selector=$1; shift;; esac
  done
  [ -n "$selector" ] && [ "$yes" = --yes ] || die 'usage: workframe archive <selector> --yes [--force]'
  local path; path=$(_resolve_worktree "$selector")
  cmd_archive "$path" $force
}
mac_restore(){
  [ $# -eq 2 ] || die 'usage: workframe restore <repo> <task>'
  _resolve_archived "$1" "$2"
  cmd_restore "$1" "$2"
}
mac_remove(){
  [ "${1:-}" = branch ] || die 'usage: workframe remove branch <repo> <task> --yes'
  shift
  [ $# -eq 3 ] && [ "$3" = --yes ] || die 'usage: workframe remove branch <repo> <task> --yes'
  _resolve_archived "$1" "$2"
  cmd_rmbranch "$1" "$2"
}
mac_clone(){ [ $# -eq 1 ] || die 'usage: workframe clone <owner/repo|url|path>'; cmd_clone "$1"; }
mac_migrate(){ cmd_migrate "$@"; }
mac_status(){
  [ $# -eq 0 ] || die 'usage: workframe status'
  local active archived
  active=$(cmd_worktrees | sed '/^$/d' | wc -l | tr -d ' ')
  archived=$(cmd_archived | sed '/^$/d' | wc -l | tr -d ' ')
  # ROOT is assigned by config.sh.
  # shellcheck disable=SC2153
  printf 'root: %s\nactive: %s\narchived: %s\n' "$ROOT" "$active" "$archived"
}
mac_doctor(){
  [ $# -eq 0 ] || die 'usage: workframe doctor'
  cmd_doctor
}
