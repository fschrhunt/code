#!/usr/bin/env bash
# FRONTEND — user-facing CLI (any OS). Local profile runs cmd_* in-process;
# shared forwards to the box via SSH and maps paths through the mount.
# Store verbs alone run under WORKFRAME_BACKEND=1 (tests + box).

_bx(){
  if _is_local_store; then
    local verb="${1:-}"; shift || true
    case "$verb" in
      new) cmd_new "$@";; rename) cmd_rename "$@";; clone) cmd_clone "$@";; delrepo) cmd_delrepo "$@";;
      list|ls) cmd_list "$@";; sync) cmd_sync "$@";; clean) cmd_clean "$@";;
      archive) cmd_archive "$@";; archived) cmd_archived "$@";; restore) cmd_restore "$@";; rmbranch) cmd_rmbranch "$@";; migrate) cmd_migrate "$@";;
      status) cmd_status "$@";; doctor) cmd_doctor "$@";; guide) cmd_guide "$@";; repos) cmd_repos "$@";; worktrees) cmd_worktrees "$@";;
      *) die "unknown backend verb: $verb";;
    esac
    return $?
  fi
  _require_shared_stack
  local wc=0; [ -t 1 ] && wc=1
  local cmd; cmd=$(_bx_remote_cmd "$wc" "$@")
  # Reuse one SSH connection across resolve+act in the same process.
  local mux="$WORKFRAME_USER_DIR/ssh"
  mkdir -p "$mux" 2>/dev/null || true
  /usr/bin/ssh \
    -o ControlMaster=auto \
    -o "ControlPath=$mux/%C" \
    -o ControlPersist=120 \
    "$BOX_HOST" "$cmd"
}

# Build the command string that runs on the far side of ssh. Split out of _bx so
# it can be asserted on without a box. $1 is WORKFRAME_COLOR; the rest are workframe args.
#
# Every interpolated value is %q-quoted, because a shell on the box re-parses
# this string and box_user/box_root/box_home come from config, where
# _config_safe_val permits spaces. Unquoted, a box_root of "/mnt/my workframe" splits
# into two words and the remote command is silently malformed.
_bx_remote_cmd(){
  local wc=$1; shift
  local cmd
  # BOX_HOME is assigned in config.sh (linted as a separate top-level file).
  # shellcheck disable=SC2153
  cmd="sudo -u $(printf '%q' "$BOX_USER") env HOME=$(printf '%q' "$BOX_HOME") WORKFRAME_COLOR=$wc WORKFRAME_BACKEND=1 WORKFRAME_HOME=$(printf '%q' "$BOX_ROOT")"
  cmd+=" $(printf '%q' "$BOX_ROOT/system/bin/workframe")"
  local a; for a in "$@"; do cmd+=" $(printf '%q' "$a")"; done
  printf '%s' "$cmd"
}

# Process-local cache for list verbs (one SSH/worktrees fetch per invocation).
_BX_HAVE_WORKFRAME=0; _BX_CACHE_WORKFRAME=""
_BX_HAVE_REPOS=0; _BX_CACHE_REPOS=""
_bx_invalidate(){ _BX_HAVE_WORKFRAME=0; _BX_CACHE_WORKFRAME=""; _BX_HAVE_REPOS=0; _BX_CACHE_REPOS=""; }
_activate_profile(){
  _refresh_runtime_paths
  _bx_invalidate
}
_bx_list(){
  case "$1" in
    worktrees)
      if [ "$_BX_HAVE_WORKFRAME" = 1 ]; then printf '%s' "$_BX_CACHE_WORKFRAME"; return 0; fi
      _BX_CACHE_WORKFRAME=$(_bx worktrees) || return $?
      _BX_HAVE_WORKFRAME=1
      printf '%s' "$_BX_CACHE_WORKFRAME"
      ;;
    repos)
      if [ "$_BX_HAVE_REPOS" = 1 ]; then printf '%s' "$_BX_CACHE_REPOS"; return 0; fi
      _BX_CACHE_REPOS=$(_bx repos) || return $?
      _BX_HAVE_REPOS=1
      printf '%s' "$_BX_CACHE_REPOS"
      ;;
    *) die "internal: _bx_list $1";;
  esac
}
_tomac(){
  if _is_local_store; then
    printf '%s' "$1"; return 0
  fi
  printf '%s' "$1" | sed "s#^$BOX_ROOT#$MAC_ROOT#"
}
# Pickers return 2 for "no terminal to prompt with" and 1 for cancelled/none, so
# a caller can treat an interactive cancel as success while a missing selector
# under automation stays an error. `die` cannot be used: pickers are captured
# with $( ), where exit only ends the subshell.
_PICK_NOTTY=2
_pick_worktree(){ local rows
  _interactive || { err "no selector given and no terminal to prompt — pass <worktree|repo/task|city>"; return $_PICK_NOTTY; }
  rows=$(_bx_list worktrees); [ -z "$rows" ] && { printf '  %sno worktrees yet%s\n' "$DIM" "$N" >&2; return 1; }
  local -a labels=() paths=(); while IFS=$'\t' read -r repo city path br; do [ -n "$path" ] || continue; labels+=("$repo / $br   ·   $city"); paths+=("$path"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-worktree}" "${labels[@]}") || return 1; local i; for i in "${!labels[@]}"; do [ "${labels[i]}" = "$sel" ] && { printf '%s' "${paths[i]}"; return 0; }; done; return 1; }
_resolve_worktree(){ local sel=$1 rows matches count
  if [ -n "$MAC_ROOT" ]; then
    case "$sel" in "$MAC_ROOT"/*)
      if ! _is_local_store; then sel="$BOX_ROOT${sel#"$MAC_ROOT"}"; fi
      ;;
    esac
  fi
  rows=$(_bx_list worktrees)
  matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r repo city path br; do
    if [ "$path" = "$sel" ] || [ "$sel" = "$city" ] || [ "$sel" = "$br" ] || [ "$sel" = "$repo/$br" ]; then
      printf '%s\n' "$path"
    fi
  done)
  count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" = 1 ] && { printf '%s' "$matches"; return 0; }
  [ "$count" = 0 ] && die "no worktree matching '$sel'"
  die "'$sel' matches multiple worktrees — use repo/city"
}
_offer_shell_cd_hook(){
  local shell_rc="" has_hook=0 has_short=0
  case "${SHELL:-}" in
    */zsh) shell_rc="$HOME/.zshrc";;
    */bash) shell_rc="$HOME/.bashrc";;
  esac
  [ -n "$shell_rc" ] || return 0
  grep -q 'workframe cd shell integration' "$shell_rc" 2>/dev/null && has_hook=1
  grep -q 'wf() { workframe' "$shell_rc" 2>/dev/null && has_short=1
  [ "$has_hook" = 1 ] && [ "$has_short" = 1 ] && return 0
  _interactive || return 0
  echo
  # An earlier install may carry the wrapper without the short name; top it up
  # rather than defining `workframe` twice in the same rc file.
  if [ "$has_hook" = 1 ]; then
    if _confirm "add the 'wf' shortcut to $shell_rc?"; then
      cat >> "$shell_rc" <<'ZF'

# workframe cd shell integration (short name)
wf() { workframe "$@"; }
ZF
      ok "added — restart your shell or: source $shell_rc"
    fi
    return 0
  fi
  if _confirm "add the 'workframe cd' shortcut to $shell_rc?"; then
    cat >> "$shell_rc" <<'ZF'

# workframe cd shell integration
workframe() { if [ "$1" = "cd" ]; then local d; d="$(command workframe __cdpath "${@:2}")" && [ -d "$d" ] && cd "$d"; return; fi; command workframe "$@"; }
wf() { workframe "$@"; }
ZF
    ok "added — restart your shell or: source $shell_rc"
  fi
}

_print_next_steps(){
  printf '\n  %snext:%s\n' "$DIM" "$N"
  printf '    %sworkframe clone <owner/repo | url | path>%s\n' "$GRN" "$N"
  printf '    %sworkframe new <repo> <task>%s\n' "$GRN" "$N"
}

# Shared opt-in: replace CACHE_DIRS with symlinks into ~/.workframe-cache (localdeps=1).
mac_localdeps(){
  _is_local_store && return 0
  [ "${LOCALDEPS:-0}" = 1 ] || return 0
  local worktree="${1:-$PWD}"; [ -d "$worktree" ] || return 0
  local key base linked=0 d
  key=$(printf '%s' "$worktree" | sed -E 's#^.*/workspaces/##; s#/#_#g')
  base="$HOME/.workframe-cache/$key"
  for d in $CACHE_DIRS; do
    # Belt and braces: config parsing already filters these, but CACHE_DIRS can
    # also arrive from the environment, and this loop rm -rf's what it is given.
    _cache_dir_ok "$d" || continue
    [ -L "$worktree/$d" ] && continue
    mkdir -p "$base/$d"
    { [ -e "$worktree/$d" ] && [ ! -L "$worktree/$d" ] && rm -rf "${worktree:?}/${d:?}"; }
    ln -s "$base/$d" "$worktree/$d"
    linked=1
  done
  [ "$linked" = 1 ] && printf '  %slinked cache dirs → %s%s\n' "$DIM" "$base" "$N"
}

_ask_prefs(){
  local e o
  e=$(_input "editor command" "$EDITOR_CMD"); e=${e:-$EDITOR_CMD}
  o=$(_input "default github org" "$DEFAULT_ORG"); o=${o:-$DEFAULT_ORG}
  _config_safe_val "$e" || die "unsafe editor value"
  _config_safe_val "$o" || die "unsafe org value"
  EDITOR_CMD=$e; DEFAULT_ORG=$o
}

_ask_shared_stack(){
  printf '  %sShared store lives on a box and is mounted locally.%s\n' "$DIM" "$N"
  printf '  %sFill each field (Enter keeps an existing value shown in [brackets]).%s\n\n' "$DIM" "$N"
  local v
  v=$(_input "SSH host" "${BOX_HOST:-}"); BOX_HOST=$v
  v=$(_input "box address for probes (optional)" "${BOX_ADDR:-}"); BOX_ADDR=$v
  v=$(_input "SSH / sudo user on the box" "${BOX_USER:-}"); BOX_USER=$v
  v=$(_input "remote store root on the box" "${BOX_ROOT:-}"); BOX_ROOT=$v
  v=$(_input "local mount path" "${MAC_ROOT:-}"); MAC_ROOT=$v
  v=$(_input "SMB share name" "${SHARE_NAME:-}"); SHARE_NAME=$v
  [ -n "$BOX_HOST" ] && [ -n "$BOX_USER" ] && [ -n "$BOX_ROOT" ] && [ -n "$MAC_ROOT" ] \
    || die "shared stack needs box_host, box_user, box_root, and mount_path"
  _config_safe_val "$BOX_HOST" && _config_safe_val "$BOX_ADDR" && _config_safe_val "$BOX_USER" \
    && _config_safe_val "$BOX_ROOT" && _config_safe_val "$MAC_ROOT" && _config_safe_val "$SHARE_NAME" \
    || die "unsafe shared-stack value"
  _sync_box_home
}

_setup_usage(){
  printf 'usage: workframe setup [--local|--shared] [--root <path>] [--editor <command>] [--org <name>]\n'
}

mac_setup(){
  banner "setup"
  local mode="" requested_root="" editor="" org=""
  local interactive=0 explicit=0
  if [ "${WORKFRAME_SETUP_NONINTERACTIVE:-0}" != 1 ] && _interactive; then
    interactive=1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --local|local)
        [ -z "$mode" ] || [ "$mode" = local ] || die "choose only one profile type"
        mode=local; explicit=1; shift
        ;;
      --shared|shared)
        [ -z "$mode" ] || [ "$mode" = shared ] || die "choose only one profile type"
        mode=shared; explicit=1; shift
        ;;
      --root)
        [ $# -ge 2 ] || die "missing value for --root"
        requested_root=$2; explicit=1; shift 2
        ;;
      --editor)
        [ $# -ge 2 ] || die "missing value for --editor"
        editor=$2; explicit=1; shift 2
        ;;
      --org)
        [ $# -ge 2 ] || die "missing value for --org"
        org=$2; explicit=1; shift 2
        ;;
      -h|--help)
        _setup_usage
        return 0
        ;;
      -*)
        die "unknown flag: $1 ($(_setup_usage))"
        ;;
      *)
        die "$(_setup_usage)"
        ;;
    esac
  done

  if [ -z "$mode" ]; then
    if [ "$interactive" = 1 ]; then
      mode=$(_choose "where should worktrees live?" \
        "local    on this machine ($WORKFRAME_USER_DIR)" \
        "shared   on a box, mounted locally") || return 0
      case "$mode" in local*) mode=local;; shared*) mode=shared;; esac
    else
      mode=${WORKFRAME_PROFILE_TYPE:-local}
    fi
  fi
  [ "$mode" = shared ] && [ -n "$requested_root" ] && die "--root is for local profiles"

  if [ "$mode" = local ]; then
    local old_root=$WORKFRAME_USER_DIR old_config=$WORKFRAME_USER_CONFIG
    local old_legacy_config=$WORKFRAME_LEGACY_CONFIG moved=0 parent old_physical=""
    [ -d "$old_root" ] && old_physical=$(cd "$old_root" 2>/dev/null && pwd -P || true)
    if [ "$interactive" = 1 ] && [ -z "$requested_root" ]; then
      requested_root=$(_input "Workframe root" "$WORKFRAME_USER_DIR")
    fi
    if [ "${WORKFRAME_ROOT_SELECTED:-0}" = 1 ] && [ ! -d "$WORKFRAME_USER_DIR" ] \
      && [ -z "$requested_root" ]; then
      die "selected Workframe root is unavailable: $WORKFRAME_USER_DIR (attach the volume or pass --root <path>)"
    fi
    if [ -n "$requested_root" ]; then
      case "$requested_root" in
        "~") requested_root=$HOME;;
        \~/*) requested_root="$HOME/${requested_root#\~/}";;
      esac
      requested_root=${requested_root%/}
      _root_path_ok "$requested_root" || die "invalid root '$requested_root' — use an absolute path other than /"
      if [ ! -d "$requested_root" ]; then
        parent=${requested_root%/*}; [ -n "$parent" ] || parent=/
        [ -d "$parent" ] || die "root parent does not exist: $parent"
      fi
      [ "$requested_root" != "$old_root" ] && moved=1
      _set_local_root "$requested_root" || die "invalid root: $requested_root"
      [ -n "$old_physical" ] && [ "$ROOT" = "$old_physical" ] && moved=0
      if [ "$WORKFRAME_USER_CONFIG" != "$old_config" ] && _user_config_exists; then
        _load_selected_user_config
      fi
    fi
    mkdir -p "$WORKFRAME_USER_DIR/repos" "$WORKFRAME_USER_DIR/workspaces" "$WORKFRAME_USER_DIR/system/logs"
    _ensure_store_guide "$WORKFRAME_USER_DIR" || die "could not create Workframe guide at $WORKFRAME_USER_DIR/WORKFRAME.md"
    if [ "$interactive" = 0 ] && [ "$explicit" = 0 ] && _user_config_exists \
      && [ "${WORKFRAME_PROFILE_TYPE:-}" = local ]; then
      if [ ! -f "$WORKFRAME_USER_CONFIG" ] && [ -f "$WORKFRAME_LEGACY_CONFIG" ]; then
        _save_user_config || die "could not migrate Workframe config to $WORKFRAME_USER_CONFIG"
        ok "config moved  ${DIM}$WORKFRAME_USER_CONFIG${N}"
      fi
      _save_root_pointer || die "could not remember Workframe root in $WORKFRAME_ROOT_POINTER"
      ok "local profile already at ${GRN}$WORKFRAME_USER_DIR${N}"
      return 0
    fi
    WORKFRAME_PROFILE_TYPE=local
    if [ "$interactive" = 1 ]; then
      _ask_prefs
    else
      if [ -n "$editor" ]; then _config_safe_val "$editor" || die "unsafe editor value"; EDITOR_CMD=$editor; fi
      if [ -n "$org" ]; then _config_safe_val "$org" || die "unsafe org value"; DEFAULT_ORG=$org; fi
    fi
    _save_user_config || die "could not save Workframe config at $WORKFRAME_USER_CONFIG"
    _save_root_pointer || die "could not remember Workframe root in $WORKFRAME_ROOT_POINTER"
    _set_local_root "$WORKFRAME_USER_DIR"
    _activate_profile
    ok "local profile ready  ${DIM}$WORKFRAME_USER_DIR${N}"
    if [ "$moved" = 1 ] && { [ -f "$old_config" ] || [ -f "$old_legacy_config" ] \
      || [ -d "$old_root/repos" ] || [ -d "$old_root/workspaces" ]; }; then
      warn "selected a new root; existing data was not moved from $old_root"
    fi
    _print_next_steps
    _offer_shell_cd_hook
    return 0
  fi

  # shared — all host/path values come from prompts (or the selected store config)
  if [ "${WORKFRAME_ROOT_SELECTED:-0}" = 1 ] && [ ! -d "$WORKFRAME_USER_DIR" ]; then
    die "selected Workframe root is unavailable: $WORKFRAME_USER_DIR (attach the volume or select a local root first)"
  fi
  WORKFRAME_PROFILE_TYPE=shared
  mkdir -p "$WORKFRAME_USER_DIR"
  _ask_shared_stack
  if [ "$interactive" = 1 ]; then
    _ask_prefs
  else
    if [ -n "$editor" ]; then _config_safe_val "$editor" || die "unsafe editor value"; EDITOR_CMD=$editor; fi
    if [ -n "$org" ]; then _config_safe_val "$org" || die "unsafe org value"; DEFAULT_ORG=$org; fi
  fi
  _save_user_config || die "could not save Workframe config at $WORKFRAME_USER_CONFIG"
  _save_root_pointer || die "could not remember Workframe root in $WORKFRAME_ROOT_POINTER"
  _activate_profile
  ok "shared profile saved  ${DIM}$WORKFRAME_USER_CONFIG${N}"
  if _box_reachable; then
    if _bx guide >/dev/null 2>&1; then
      ok "Workframe guide ready  ${DIM}$MAC_ROOT/WORKFRAME.md${N}"
    else
      warn "Workframe guide pending — reopen Workframe once the box is reachable"
    fi
  else
    warn "Workframe guide pending — reopen Workframe when the box is reachable"
  fi
  printf '  %smount:%s %s  %sbox:%s %s:%s\n' "$DIM" "$N" "$MAC_ROOT" "$DIM" "$N" "$BOX_HOST" "$BOX_ROOT"
  printf '  %sthen:%s mount the share and run %sworkframe doctor%s\n' "$DIM" "$N" "$GRN" "$N"
  _print_next_steps
  _offer_shell_cd_hook
}

mac_init(){
  local -a args=(--local)
  while [ $# -gt 0 ]; do
    case "$1" in
      --root|--editor|--org) [ $# -ge 2 ] || die "missing value for $1"; args+=("$1" "$2"); shift 2;;
      -h|--help)
        printf 'usage: workframe init [--root <path>] [--editor <command>] [--org <name>]\n'
        return 0
        ;;
      *) die "usage: workframe init [--root <path>] [--editor <command>] [--org <name>]";;
    esac
  done
  WORKFRAME_SETUP_NONINTERACTIVE=1 mac_setup "${args[@]}"
}

# JSON is deliberately implemented without jq so every supported Workframe
# installation can consume the machine-readable commands.
_json_escape(){
  local value=$1
  value=${value//\\/\\\\}; value=${value//\"/\\\"}; value=${value//$'\n'/\\n}; value=${value//$'\r'/\\r}; value=${value//$'\t'/\\t}
  printf '%s' "$value"
}
_json_string(){ printf '"'; _json_escape "$1"; printf '"'; }

_worktree_is_dirty(){
  local path; path=$(_tomac "$1")
  [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]
}

_print_worktree_json(){
  local rows=$1 first=1 repo city path br dirty
  printf '['
  while IFS=$'\t' read -r repo city path br; do
    [ -n "$path" ] || continue
    dirty=false; _worktree_is_dirty "$path" && dirty=true
    [ "$first" = 1 ] || printf ','; first=0
    printf '{"repo":'; _json_string "$repo"
    printf ',"city":'; _json_string "$city"; printf ',"path":'; _json_string "$(_tomac "$path")"
    printf ',"branch":'; _json_string "$br"; printf ',"dirty":%s}' "$dirty"
  done <<< "$rows"
  printf ']\n'
}

mac_list(){
  local archived=0 repo="" dirty="" json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      archived|--archived) archived=1; shift;;
      --repo) [ $# -ge 2 ] || die "missing value for $1"; repo=$2; shift 2;;
      --dirty) dirty=1; shift;;
      --json) json=1; shift;;
      -h|--help) printf 'usage: workframe list [archived] [--repo <name>] [--dirty] [--json]\n'; return 0;;
      *) die "usage: workframe list [archived] [--repo <name>] [--dirty] [--json]";;
    esac
  done
  if [ "$archived" = 1 ]; then
    local rows out="" r br when first=1
    rows=$(_bx archived)
    while IFS=$'\t' read -r r br when; do
      [ -n "$br" ] || continue; [ -n "$repo" ] && [ "$repo" != "$r" ] && continue
      out+="$r"$'\t'"$br"$'\t'"$when"$'\n'
    done <<< "$rows"
    if [ "$json" = 1 ]; then
      printf '['; while IFS=$'\t' read -r r br when; do [ -n "$br" ] || continue; [ "$first" = 1 ] || printf ','; first=0; printf '{"repo":'; _json_string "$r"; printf ',"branch":'; _json_string "$br"; printf ',"archived":'; _json_string "$when"; printf '}'; done <<< "$out"; printf ']\n'; return
    fi
    [ -n "$out" ] || { printf '  %snothing archived%s\n' "$DIM" "$N"; return; }
    printf '  %s%-12s %-24s %s%s\n' "$W" REPO BRANCH WHEN "$N"
    while IFS=$'\t' read -r r br when; do [ -n "$br" ] || continue; printf '  %-12s %s%-24s%s %s%s%s\n' "$r" "$W" "$br" "$N" "$DIM" "$when" "$N"; done <<< "$out"
    return
  fi
  local rows out="" r city path br is_dirty
  rows=$(_bx_list worktrees)
  while IFS=$'\t' read -r r city path br; do
    [ -n "$path" ] || continue; [ -n "$repo" ] && [ "$repo" != "$r" ] && continue
    is_dirty=0; _worktree_is_dirty "$path" && is_dirty=1; [ -n "$dirty" ] && [ "$is_dirty" != 1 ] && continue
    out+="$r"$'\t'"$city"$'\t'"$path"$'\t'"$br"$'\n'
  done <<< "$rows"
  [ "$json" = 1 ] && { _print_worktree_json "$out"; return; }
  printf '  %s%-12s %-22s %-6s %s%s\n' "$W" REPO TASK DIRTY CITY "$N"
  [ -n "$out" ] || { printf '  %sno matching worktrees%s\n' "$DIM" "$N"; return; }
  while IFS=$'\t' read -r r city path br; do
    [ -n "$path" ] || continue; local task=$br d="-" dc=$DIM; _worktree_is_dirty "$path" && { d=yes; dc=$YEL; }
    printf '  %-12s %s%-22s%s %s%-6s%s %s%s%s\n' "$r" "$W" "${task:0:22}" "$N" "$dc" "$d" "$N" "$DIM" "$city" "$N"
  done <<< "$out"
}

mac_repos(){
  [ "${1:-}" != --json ] || { [ $# -eq 1 ] || die 'usage: workframe repos [--json]'; local first=1 repo; printf '['; while read -r repo; do [ -n "$repo" ] || continue; [ "$first" = 1 ] || printf ','; first=0; _json_string "$repo"; done < <(_bx_list repos); printf ']\n'; return; }
  [ $# -eq 0 ] || die 'usage: workframe repos [--json]'
  _bx_list repos
}

mac_worktrees(){
  case "${1:-}" in
    "") _bx_list worktrees;;
    --json) [ $# -eq 1 ] || die 'usage: workframe worktrees [--json]'; _print_worktree_json "$(_bx_list worktrees)";;
    *) die 'usage: workframe worktrees [--json]';;
  esac
}

mac_new(){ local repo="" feature=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) printf 'usage: workframe new <repo> <task>\n'; return 0;;
      -*) die "unknown flag: $1 (usage: workframe new <repo> <task>)";;
      *) if [ -z "$repo" ]; then repo=$1; elif [ -z "$feature" ]; then feature=$1; else die "usage: workframe new <repo> <task>"; fi; shift;;
    esac
  done
  local all matches mcount
  all=$(_bx_list repos)
  if [ -z "$all" ]; then
    die "no repositories yet — add one with: workframe clone <owner/repo | url | path>"
  fi
  if [ -z "$repo" ]; then
    if _interactive; then repo=$(_choose "which repo?" $all) || return 0
    else die "usage: workframe new <repo> <task>"; fi
  fi
  [ -n "$repo" ] || return 0
  if ! printf '%s\n' "$all" | grep -qx "$repo"; then
    matches=$(printf '%s\n' "$all" | grep -i -F "$repo" || true)
    mcount=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$mcount" = 1 ]; then
      repo=$(printf '%s\n' "$matches" | sed '/^$/d' | head -1)
    elif [ "$mcount" = 0 ]; then
      die "no repository matching '$repo' — add one with: workframe clone <owner/repo | url | path>"
    else
      printf '  %sambiguous repo %s — matches:%s\n' "$YEL" "'$repo'" "$N" >&2
      printf '%s\n' "$matches" | sed '/^$/d' | sed 's/^/    /' >&2
      die "use an exact repo name"
    fi
  fi
  if [ -z "$feature" ]; then
    if _interactive; then
      # No default applied — empty cancels (hint only in the label).
      feature=$(_input "feature name (e.g. dark-mode)" "")
      [ -n "$feature" ] || { warn "cancelled"; return 0; }
    else
      die "usage: workframe new <repo> <task>"
    fi
  fi
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  if ! _spin_run "creating $feature" _bx new "$repo" "$feature"; then
    err "${SPIN_OUT:-create failed}"; return 1
  fi
  local out="$SPIN_OUT"
  _bx_invalidate
  local boxpath branch macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); branch=$(printf '%s' "$out" | sed -n 's/^branch: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"; ok "created ${GRN}$branch${N}  ${DIM}$macpath${N}"
  if _interactive && command -v "$EDITOR_CMD" >/dev/null 2>&1 && _confirm "open in $EDITOR_CMD?"; then _editor_open "$macpath"; fi; }
mac_rename(){ local sel="${1:-}" feature="${2:-}" worktree
  if [ -n "$sel" ]; then worktree=$(_resolve_worktree "$sel") || return 1
  else worktree=$(_pick_worktree "rename which worktree?") || { [ $? = "$_PICK_NOTTY" ] && return 1; return 0; }; fi
  [ -z "$feature" ] && feature=$(_input "new feature name (e.g. dark-mode)" "")
  [ -n "$feature" ] || { warn "cancelled"; return 0; }
  _spin_run "renaming branch" _bx rename "$worktree" "$feature" || return 1
  _bx_invalidate
  _is_local_store || printf '  %s(box is authoritative; local git may show the old name briefly — SMB cache)%s\n' "$DIM" "$N"
  ok "renamed to ${GRN}$feature${N}"; }
mac_ide(){ local worktree="${1:-}"
  if [ -z "$worktree" ]; then worktree=$(_pick_worktree "open in $EDITOR_CMD") || { [ $? = "$_PICK_NOTTY" ] && return 1; return 0; }
  else worktree=$(_resolve_worktree "$worktree") || return 1; fi
  worktree=$(_tomac "$worktree")
  _editor_open "$worktree"; ok "opened $worktree"; }
mac_cdpath(){ local worktree="${1:-}"
  if [ -z "$worktree" ]; then worktree=$(_pick_worktree "jump to") || return 1
  else worktree=$(_resolve_worktree "$worktree") || return 1; fi
  # Newline-terminated: $( ) strips it, and redirected output stays well-formed.
  _tomac "$worktree"; printf '\n'; }

_current_worktree(){
  local here row repo city path br local_path
  here=$(pwd -P) || return 1
  while IFS=$'\t' read -r repo city path br; do
    [ -n "$path" ] || continue
    local_path=$(_tomac "$path")
    case "$here" in "$local_path"|"$local_path"/*) printf '%s\t%s\t%s\t%s\n' "$repo" "$city" "$path" "$br"; return 0;; esac
  done < <(_bx_list worktrees; printf '\n')
  return 1
}

mac_current(){
  local json=0
  case "${1:-}" in "") ;; --json) json=1;; -h|--help) printf 'usage: workframe current [--json]\n'; return 0;; *) die 'usage: workframe current [--json]';; esac
  local row repo city path br
  row=$(_current_worktree) || die 'not inside a Workframe workspace'
  IFS=$'\t' read -r repo city path br <<< "$row"
  if [ "$json" = 1 ]; then
    printf '{"repo":'; _json_string "$repo"; printf ',"city":'; _json_string "$city"; printf ',"path":'; _json_string "$(_tomac "$path")"; printf ',"branch":'; _json_string "$br"; printf '}\n'
  else
    printf 'workspace: %s\nrepo: %s\nbranch: %s\ncity: %s\n' "$(_tomac "$path")" "$repo" "$br" "$city"
  fi
}

mac_run(){
  local selector="" found=0
  while [ $# -gt 0 ]; do
    if [ "$1" = -- ]; then found=1; shift; break; fi
    [ -z "$selector" ] || die 'usage: workframe run <selector> -- <command> [args...]'
    selector=$1; shift
  done
  [ -n "$selector" ] && [ "$found" = 1 ] && [ $# -gt 0 ] || die 'usage: workframe run <selector> -- <command> [args...]'
  local worktree; worktree=$(_resolve_worktree "$selector") || return 1
  worktree=$(_tomac "$worktree")
  [ -d "$worktree" ] || die "workspace is unavailable locally: $worktree"
  (cd "$worktree" && "$@")
}

mac_resume(){
  local selector="${1:-}" active=""
  [ $# -le 1 ] || die 'usage: workframe resume <selector>'
  if [ -z "$selector" ]; then
    if _interactive; then active=$(_pick_worktree 'resume which workspace?') || return 0; else die 'usage: workframe resume <selector>'; fi
  else
    active=$(_resolve_worktree "$selector" 2>/dev/null || true)
  fi
  if [ -n "$active" ]; then
    mac_ide "$active"
  else
    mac_restore "$selector"
  fi
}

mac_dashboard(){
  [ $# -eq 0 ] || die 'usage: workframe dashboard'
  local rows repos active dirty=0 repo city path br
  rows=$(_bx_list worktrees); repos=$(_bx_list repos)
  active=$(printf '%s\n' "$rows" | sed '/^$/d' | wc -l | tr -d ' ')
  while IFS=$'\t' read -r repo city path br; do [ -n "$path" ] || continue; _worktree_is_dirty "$path" && dirty=$((dirty + 1)); done <<< "$rows"
  banner "dashboard"
  printf '  %sprofile%s  %s\n' "$DIM" "$N" "${WORKFRAME_PROFILE_TYPE:-local}"
  printf '  %srepos%s     %s\n' "$DIM" "$N" "$(printf '%s\n' "$repos" | sed '/^$/d' | wc -l | tr -d ' ')"
  printf '  %sactive%s    %s\n' "$DIM" "$N" "$active"
  printf '  %sdirty%s     %s\n' "$DIM" "$N" "$dirty"
  if [ "$active" = 0 ]; then printf '\n  %snext%s  workframe clone <owner/repo>  then  workframe new <repo> <task>\n' "$DIM" "$N"; else printf '\n  %snext%s  workframe list --dirty  |  workframe resume <selector>\n' "$DIM" "$N"; fi
}
mac_archive(){
  local sel="" yes="" force="" json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) yes=--yes; shift;;
      --force|-f) force=--force; shift;;
      --json) json=1; shift;;
      -h|--help) printf 'usage: workframe archive <worktree|repo/feature|city> [--yes] [--force]\n'; return 0;;
      -*) die "unknown flag: $1 (usage: workframe archive <sel> [--yes] [--force])";;
      *) [ -z "$sel" ] || die "usage: workframe archive <worktree|repo/feature|city> [--yes] [--force]"; sel=$1; shift;;
    esac
  done
  local worktree
  if [ -n "$sel" ]; then
    worktree=$(_resolve_worktree "$sel") || return 1
  elif _interactive; then
    worktree=$(_pick_worktree "archive which worktree?") || return 0
  else
    die "usage: workframe archive <worktree|repo/feature|city> [--yes] [--force]"
  fi
  # --yes skips soft confirm only. Dirty discard requires --force (never auto via --yes).
  _confirm_yes "archive $(basename "$worktree")? (keeps the branch — restorable)" "$yes" || { warn "cancelled"; return 0; }
  local out rc
  [ "$json" = 1 ] || banner "archive $(basename "$worktree")"
  # Pass --force on the first call when set — no scare + second SSH.
  if [ "$force" = "--force" ]; then
    _progress_run "archiving worktree" _bx archive "$worktree" --force; rc=$?; out="$PROGRESS_OUT"
    if [ "$rc" = 0 ]; then
      _bx_invalidate
      if [ "$json" = 1 ]; then printf '{"action":"archived","workspace":'; _json_string "$(_tomac "$worktree")"; printf ',"branch":'; _json_string "${out#archived: }"; printf '}\n'; else ok "archived ${GRN}${out#archived: }${N}  ${DIM}— restore with: workframe restore <repo> <branch>${N}"; fi
    else
      err "${out:-archive failed}"; return "$rc"
    fi
    return 0
  fi
  _progress_run "archiving worktree" _bx archive "$worktree"; rc=$?; out="$PROGRESS_OUT"
  if [ "$rc" = 3 ]; then
    printf '  %s%s%s\n' "$YEL" "$out" "$N"
    if _interactive; then
      _confirm "discard uncommitted changes and archive anyway?" || { warn "cancelled"; return 0; }
    else
      err "refusing — pass --force to discard dirty work"; return 3
    fi
    if _progress_run "archiving worktree" _bx archive "$worktree" --force; then
      _bx_invalidate
      if [ "$json" = 1 ]; then printf '{"action":"archived","workspace":'; _json_string "$(_tomac "$worktree")"; printf ',"branch":'; _json_string "${PROGRESS_OUT#archived: }"; printf ',"forced":true}\n'; else ok "archived (uncommitted discarded)"; fi
    else
      err "${PROGRESS_OUT:-archive failed}"; return 1
    fi
  elif [ "$rc" = 0 ]; then
    _bx_invalidate
    if [ "$json" = 1 ]; then printf '{"action":"archived","workspace":'; _json_string "$(_tomac "$worktree")"; printf ',"branch":'; _json_string "${out#archived: }"; printf '}\n'; else ok "archived ${GRN}${out#archived: }${N}  ${DIM}— restore with: workframe restore <repo> <branch>${N}"; fi
  else
    err "${out:-archive failed}"; return "$rc"
  fi
}
mac_archived(){ banner "archived"; local rows; rows=$(_bx archived)
  [ -z "$rows" ] && { printf '  %snothing archived%s\n' "$DIM" "$N"; return; }
  printf '  %s%-12s %-24s %s%s\n' "$W" REPO BRANCH WHEN "$N"
  printf '%s\n' "$rows" | while IFS=$'\t' read -r repo br when; do
    printf '  %-12s %s%-24s%s %s%s%s\n' "$repo" "$W" "$br" "$N" "$DIM" "$when" "$N"; done; }
_pick_archived(){ local rows
  _interactive || { err "no selector given and no terminal to prompt — pass <repo> <branch>"; return $_PICK_NOTTY; }
  rows=$(_bx archived); [ -z "$rows" ] && { printf '  %snothing archived%s\n' "$DIM" "$N" >&2; return 1; }
  A_LABELS=(); A_REPOS=(); A_BRANCHES=(); local repo br when
  while IFS=$'\t' read -r repo br when; do [ -n "$br" ] || continue; A_LABELS+=("$repo / $br   ${DIM}$when${N}"); A_REPOS+=("$repo"); A_BRANCHES+=("$br"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-archived worktree}" "${A_LABELS[@]}") || return 1
  local i; for i in "${!A_LABELS[@]}"; do [ "${A_LABELS[i]}" = "$sel" ] && { A_IDX=$i; return 0; }; done; return 1; }
# Resolve an archived branch from repo + branch, or a single selector (branch / repo/feature).
_resolve_archived(){
  local a="${1:-}" b="${2:-}" rows matches count
  rows=$(_bx archived)
  [ -z "$rows" ] && die "nothing archived"
  if [ -n "$a" ] && [ -n "$b" ]; then
    matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r repo br when; do
      [ "$repo" = "$a" ] && [ "$br" = "$b" ] && printf '%s\t%s\n' "$repo" "$br"
    done)
  else
    matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r repo br when; do
      if [ "$br" = "$a" ] || [ "$a" = "$repo/$br" ]; then
        printf '%s\t%s\n' "$repo" "$br"
      fi
    done)
  fi
  count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" = 1 ] || {
    [ "$count" = 0 ] && die "no archived branch matching '${b:-$a}'"
    die "'${b:-$a}' matches multiple archived branches"
  }
  A_REPO=$(printf '%s\n' "$matches" | head -1 | cut -f1)
  A_BRANCH=$(printf '%s\n' "$matches" | head -1 | cut -f2)
}
mac_restore(){
  local json=0; [ "${1:-}" = --json ] && { json=1; shift; }
  local repo="${1:-}" branch="${2:-}"
  if [ -n "$repo" ] && [ -n "$branch" ]; then
    _resolve_archived "$repo" "$branch" || return 1
  elif [ -n "$repo" ] && [ -z "$branch" ]; then
    _resolve_archived "$repo" || return 1
  elif _interactive; then
    _pick_archived "restore which?" || return 0
    A_REPO=${A_REPOS[A_IDX]}; A_BRANCH=${A_BRANCHES[A_IDX]}
  else
    die "usage: workframe restore <repo> <branch>"
  fi
  _spin_run "restoring $A_BRANCH" _bx restore "$A_REPO" "$A_BRANCH" || return 1; local out="$SPIN_OUT"
  _bx_invalidate
  local boxpath macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"
  if [ "$json" = 1 ]; then printf '{"action":"restored","workspace":'; _json_string "$macpath"; printf ',"branch":'; _json_string "$A_BRANCH"; printf '}\n'; else ok "restored ${GRN}$A_BRANCH${N}  ${DIM}$macpath${N}"; fi
}
mac_remove(){
  local sub="${1:-}"
  case "$sub" in
    branch|rmbranch) shift || true; mac_rmbranch "$@";;
    repo|delrepo)    shift || true; mac_delrepo "$@";;
    *) die "usage: workframe remove branch <repo> <branch> [--yes]
       workframe remove repo <repo> [--force] [--yes]";;
  esac
}
mac_rmbranch(){
  local repo="" branch="" yes=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) yes=--yes; shift;;
      -*) die "unknown flag: $1 (usage: workframe remove branch <repo> <branch> [--yes])";;
      *) if [ -z "$repo" ]; then repo=$1; elif [ -z "$branch" ]; then branch=$1; else die "usage: workframe remove branch <repo> <branch> [--yes]"; fi; shift;;
    esac
  done
  if [ -n "$repo" ] && [ -n "$branch" ]; then
    _resolve_archived "$repo" "$branch" || return 1
    repo=$A_REPO; branch=$A_BRANCH
  elif [ -n "$repo" ] && [ -z "$branch" ]; then
    _resolve_archived "$repo" || return 1
    repo=$A_REPO; branch=$A_BRANCH
  elif _interactive; then
    _pick_archived "delete which archived branch?" || return 0
    repo=${A_REPOS[A_IDX]}; branch=${A_BRANCHES[A_IDX]}
  else
    die "usage: workframe remove branch <repo> <branch> [--yes]"
  fi
  _confirm_yes "permanently delete branch $branch? cannot be undone" "$yes" || { warn "cancelled"; return 0; }
  banner "delete $branch"
  if _progress_run "deleting branch" _bx rmbranch "$repo" "$branch"; then
    _bx_invalidate
    ok "deleted $branch"
  else
    err "${PROGRESS_OUT:-delete failed}"; return 1
  fi
}
mac_delrepo(){
  local repo="" force="" yes=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=--force; shift;;
      --yes|-y) yes=--yes; shift;;
      -h|--help) printf 'usage: workframe remove repo <repo> [--force] [--yes]\n'; return 0;;
      -*) die "unknown flag: $1 (usage: workframe remove repo <repo> [--force] [--yes])";;
      *) [ -z "$repo" ] || die "usage: workframe remove repo <repo> [--force] [--yes]"; repo=$1; shift;;
    esac
  done
  if [ -z "$repo" ]; then
    if _interactive; then
      local repos; repos=$(_bx_list repos); [ -z "$repos" ] && { warn "no repos"; return 0; }
      repo=$(_choose "delete which repo?" $repos) || return 0
    else
      die "usage: workframe remove repo <repo> [--force] [--yes]"
    fi
  fi
  _confirm_yes "delete repo '$repo' and ALL its worktrees? cannot be undone" "$yes" || { warn "cancelled"; return 0; }
  local out rc; banner "delete $repo"
  _progress_run "deleting $repo" _bx delrepo "$repo" $force; rc=$?; out="$PROGRESS_OUT"
  if [ "$rc" = 3 ]; then
    printf '%s\n' "$out"
    # --yes only skips the soft confirm; at-risk worktrees still need --force.
    # (force already on the first call never returns 3 — this is the confirm path.)
    if _interactive; then
      _confirm "force delete anyway?" || { warn "cancelled"; return 0; }
    else
      # The backend printed the specific reason above. --force discards at-risk
      # work in the store, but never deletes worktrees outside it.
      err "refusing — pass --force to proceed"; return 3
    fi
    if _progress_run "deleting $repo" _bx delrepo "$repo" --force; then
      _bx_invalidate
      ok "repo deleted: $repo"
    else
      err "${PROGRESS_OUT:-delete failed}"; return 1
    fi
  elif [ "$rc" = 0 ]; then
    _bx_invalidate
    ok "repo deleted: $repo"
  else
    err "${out:-delete failed}"; return "$rc"
  fi
}
mac_clone(){ local spec="${1:-}"
  case "$spec" in -h|--help) printf 'usage: workframe clone <owner/repo|url|path>\n'; return 0;; esac
  [ -n "$spec" ] || spec=$(_input "repo to clone (owner/repo)" "")
  [ -n "$spec" ] || return 0
  local name; name=$(_clone_repo_name "$spec"); [ -n "$name" ] || name=$spec
  banner "clone $name"
  local out; out=$(_bx clone "$spec" 2>&1 | tr '\r' '\n' | _progress_filter "cloning $name")
  case "$out" in
    *cloned:*)
      _bx_invalidate
      ok "$(printf '%s' "$out" | sed -n 's/.*cloned: //p' | head -1)"
      ;;
    *REFUSED*|*"already have"*|*"clone failed"*|*fatal:*|*"no default org"*|*"invalid repo"*)
      err "$out"
      ;;
    *) [ -n "$out" ] && printf '%s\n' "$out";;
  esac; }

mac_sync(){ local target="${1:---all}"; banner "sync"
  _progress_run "syncing repos" _bx sync "$target"; printf '%s\n' "$PROGRESS_OUT"; }

mac_clean(){
  local yes=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) yes=--yes; shift;;
      -h|--help) printf 'usage: workframe clean [--yes]\n'; return 0;;
      -*) die "unknown flag: $1 (usage: workframe clean [--yes])";;
      *) die "usage: workframe clean [--yes]";;
    esac
  done
  banner "clean"
  if [ "$yes" = "--yes" ]; then
    _progress_run "cleaning worktrees" _bx clean --yes; printf '%s\n' "$PROGRESS_OUT"
    _bx_invalidate
    return 0
  fi
  _progress_run "scanning repos" _bx clean; printf '%s\n' "$PROGRESS_OUT"
  if _interactive; then
    case "$PROGRESS_OUT" in
      *orphan*|*remote\ gone*)
        _confirm_yes "apply clean (delete listed orphans / remote-gone worktrees)?" "" || { warn "cancelled"; return 0; }
        _progress_run "cleaning worktrees" _bx clean --yes; printf '%s\n' "$PROGRESS_OUT"
        _bx_invalidate
        ;;
    esac
  fi
}

mac_migrate(){
  case "${1:-}" in
    ""|--yes|-y) ;;
    -h|--help) printf 'usage: workframe migrate [--yes]\n'; return 0;;
    *) die 'usage: workframe migrate [--yes]';;
  esac
  if [ "${1:-}" = --yes ] || [ "${1:-}" = -y ]; then
    _confirm_yes 'migrate legacy agent workspaces and branches?' --yes || return 0
    _progress_run 'migrating legacy workspaces' _bx migrate --yes || { err "${PROGRESS_OUT:-migration failed}"; return 1; }
    _bx_invalidate
    ok "${PROGRESS_OUT:-migration complete}"
  else
    _bx migrate
  fi
}

# Cheap glance — counts + tip commits. Full probes live under `workframe doctor`.
mac_status(){
  if [ "${1:-}" = --json ]; then
    [ $# -eq 1 ] || die 'usage: workframe status [--json]'
    local rows repos active dirty=0 repo city path br
    rows=$(_bx_list worktrees); repos=$(_bx_list repos)
    active=$(printf '%s\n' "$rows" | sed '/^$/d' | wc -l | tr -d ' ')
    while IFS=$'\t' read -r repo city path br; do [ -n "$path" ] || continue; _worktree_is_dirty "$path" && dirty=$((dirty + 1)); done <<< "$rows"
    printf '{"profile":'; _json_string "${WORKFRAME_PROFILE_TYPE:-local}"; printf ',"root":'; _json_string "$ROOT"; printf ',"worktrees":%s,"repos":%s,"dirty":%s}\n' "$active" "$(printf '%s\n' "$repos" | sed '/^$/d' | wc -l | tr -d ' ')" "$dirty"
    return
  fi
  [ $# -eq 0 ] || die 'usage: workframe status [--json]'
  banner "status"
  if _is_local_store; then
    ok "profile  ${GRN}local${N}  ${DIM}$ROOT${N}"
  else
    ok "profile  ${GRN}shared${N}"
    if mount | grep -q " on $MAC_ROOT "; then ok "mount up"
    else warn "mount down at $MAC_ROOT — try: workframe doctor"; fi
  fi
  _bx status
  local rows repo city path br dirty=0 unpushed=0 count
  rows=$(_bx_list worktrees)
  while IFS=$'\t' read -r repo city path br; do
    [ -n "$path" ] || continue
    _worktree_is_dirty "$path" && dirty=$((dirty + 1))
    count=$(git -C "$(_tomac "$path")" log "$br" --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
    [ "${count:-0}" -gt 0 ] 2>/dev/null && unpushed=$((unpushed + 1))
  done <<< "$rows"
  [ "$dirty" = 0 ] || warn "$dirty dirty workspace(s) — inspect: workframe list --dirty"
  [ "$unpushed" = 0 ] || warn "$unpushed workspace(s) have local-only commits — push before archive/remove"
  command -v "$EDITOR_CMD" >/dev/null 2>&1 || warn "configured editor '$EDITOR_CMD' is not on PATH — update with: workframe config"
}

_doctor_fix_local(){
  mkdir -p "$WORKFRAME_USER_DIR/repos" "$WORKFRAME_USER_DIR/workspaces" "$WORKFRAME_USER_DIR/system/logs" || die 'could not repair store directories'
  _ensure_store_guide "$WORKFRAME_USER_DIR" || die 'could not repair WORKFRAME.md'
  if _user_config_exists; then _save_root_pointer || die 'could not refresh the selected-root locator'; fi
  local repo
  for repo in $(_repos_all); do git -C "$(_canon "$repo")" worktree prune --expire=now >/dev/null 2>&1 || warn "could not prune $repo"; _ensure_relpaths "$repo"; done
  ok "safe repairs applied"
}

mac_doctor(){
  local fix=0
  case "${1:-}" in "") ;; --fix) fix=1;; -h|--help) printf 'usage: workframe doctor [--fix]\n'; return 0;; *) die 'usage: workframe doctor [--fix]';; esac
  [ "$fix" = 0 ] || { _is_local_store || die 'doctor --fix is only available for a local store'; _doctor_fix_local; }
  banner "doctor"
  if _is_local_store; then
    ok "profile  ${GRN}local${N}  ${DIM}$ROOT${N}"
    command -v gum >/dev/null 2>&1 && ok "gum installed" || warn "gum missing — optional"
    _bx doctor
    return
  fi
  ok "profile  ${GRN}shared${N}"
  printf '  %smount%s %s\n' "$DIM" "$N" "$MAC_ROOT"
  printf '  %sbox%s   %s %s(%s)%s → %s\n' "$DIM" "$N" "$BOX_HOST" "$DIM" "$BOX_ADDR" "$N" "$BOX_ROOT"
  mount | grep -q " on $MAC_ROOT " && ok "mount up" || err "mount DOWN — mount the '$SHARE_NAME' share at $MAC_ROOT"
  _box_reachable && ok "box reachable" || err "box unreachable at ${BOX_ADDR:-$BOX_HOST}:22"
  command -v gum >/dev/null 2>&1 && ok "gum installed" || warn "gum missing — optional"
  _bx doctor
  _bx status
}

mac_config(){ banner "config"
  local which refresh_paths=0
  if _interactive; then
    which=$(_choose "what to configure?" \
      "prefs     editor, github org" \
      "profile   local vs shared" \
      "shared    box host, mount, share name") || return 0
  else
    die "usage: workframe config   (interactive — editor, org, profile, shared stack)"
  fi
  case "$which" in
    prefs*)
      printf '  %sEditor / org.%s\n\n' "$DIM" "$N"
      _ask_prefs
      _save_user_config
      ok "saved — editor ${GRN}$EDITOR_CMD${N}, org ${GRN}$DEFAULT_ORG${N}"
      ;;
    profile*)
      local p; p=$(_choose "active profile type?" "local" "shared") || return 0
      WORKFRAME_PROFILE_TYPE=$p
      if [ "$p" = shared ]; then _ask_shared_stack; fi
      _save_user_config
      refresh_paths=1
      ok "profile ${GRN}$p${N}"
      ;;
    shared*)
      WORKFRAME_PROFILE_TYPE=shared
      _ask_shared_stack
      _save_user_config
      refresh_paths=1
      ok "shared stack saved"
      printf '  %s%s @ %s → %s (share %s)%s\n' "$DIM" "$BOX_HOST" "$BOX_ROOT" "$MAC_ROOT" "$SHARE_NAME" "$N"
      ;;
  esac
  if [ "$refresh_paths" = 1 ]; then
    _activate_profile
  fi
  _offer_shell_cd_hook
}

_stable_commit_with_tree(){
  local target=${1:-} wanted_tree=${2:-} commit tree
  while read -r commit tree; do
    if [ "$tree" = "$wanted_tree" ]; then
      printf '%s\n' "$commit"
      return 0
    fi
  done < <(git -C "$WORKFRAME_PREFIX" log --format='%H %T' "$target")
  return 1
}

_update_checkout(){
  command -v git >/dev/null 2>&1 || { err "git is required to update Workframe"; return 1; }
  git -C "$WORKFRAME_PREFIX" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    { err "Workframe is not installed from a Git checkout — reinstall it from the repository"; return 1; }
  [ -z "$(git -C "$WORKFRAME_PREFIX" status --porcelain)" ] ||
    { err "Workframe checkout has local changes — commit or stash them before updating"; return 1; }

  local branch remote stable before before_tree matching after after_tree version
  branch=$(git -C "$WORKFRAME_PREFIX" symbolic-ref --quiet --short HEAD) ||
    { err "Workframe checkout has a detached HEAD — switch to a branch before updating"; return 1; }
  remote=$(git -C "$WORKFRAME_PREFIX" config --get "branch.$branch.remote" 2>/dev/null || true)
  if [ -z "$remote" ] || [ "$remote" = "." ]; then
    git -C "$WORKFRAME_PREFIX" remote get-url origin >/dev/null 2>&1 ||
      { err "Workframe checkout has no 'origin' remote — reinstall it from the repository"; return 1; }
    remote=origin
  fi
  stable="$remote/main"
  before=$(git -C "$WORKFRAME_PREFIX" rev-parse HEAD) || return 1
  before_tree=$(git -C "$WORKFRAME_PREFIX" rev-parse "$before^{tree}") || return 1

  warn "updating $branch from $stable"
  git -C "$WORKFRAME_PREFIX" fetch --prune "$remote" \
    "+refs/heads/main:refs/remotes/$remote/main" || {
    err "could not fetch the stable Workframe branch '$stable'"
    return 1
  }

  if git -C "$WORKFRAME_PREFIX" merge-base --is-ancestor "$before" "$stable"; then
    git -C "$WORKFRAME_PREFIX" merge --ff-only --quiet "$stable" || {
      err "could not fast-forward '$branch' to '$stable'"
      return 1
    }
  else
    matching=$(_stable_commit_with_tree "$stable" "$before_tree") || {
      err "Workframe checkout contains commits not represented on '$stable'"
      err "reinstall from main or reconcile the checkout manually; no files were changed"
      return 1
    }
    git -C "$WORKFRAME_PREFIX" update-ref -m "workframe update: recover onto $stable" \
      "refs/heads/$branch" "$matching" "$before" || {
      err "could not recover '$branch' onto '$stable'; no files were changed"
      return 1
    }
    git -C "$WORKFRAME_PREFIX" merge --ff-only --quiet "$stable" || {
      err "could not fast-forward the recovered checkout to '$stable'"
      return 1
    }
  fi

  git -C "$WORKFRAME_PREFIX" branch --set-upstream-to="$stable" "$branch" >/dev/null 2>&1 ||
    warn "updated, but could not record '$stable' as the checkout upstream"
  after=$(git -C "$WORKFRAME_PREFIX" rev-parse HEAD) || return 1
  after_tree=$(git -C "$WORKFRAME_PREFIX" rev-parse "$after^{tree}") || return 1
  version=$(cat "$WORKFRAME_PREFIX/VERSION" 2>/dev/null || printf 'unknown')
  if [ "$before" = "$after" ]; then
    ok "Workframe $version is already current"
  elif [ "$before_tree" = "$after_tree" ]; then
    ok "Workframe $version is current (recovered onto $stable)"
  else
    ok "updated Workframe $version"
  fi
}

mac_update(){ banner "update"
  [ $# -eq 0 ] || die "usage: workframe update"
  _update_checkout
}

mac_completion(){
  local shell="${1:-}"
  case "$shell" in
    bash) cat "$WORKFRAME_PREFIX/contrib/completions/workframe.bash";;
    zsh) cat "$WORKFRAME_PREFIX/contrib/completions/_workframe";;
    fish) cat "$WORKFRAME_PREFIX/contrib/completions/workframe.fish";;
    -h|--help|"") printf 'usage: workframe completion <bash|zsh|fish>\n';;
    *) die 'usage: workframe completion <bash|zsh|fish>';;
  esac
}
