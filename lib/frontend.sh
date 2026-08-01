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
      archive) cmd_archive "$@";; archived) cmd_archived "$@";; restore) cmd_restore "$@";; rmbranch) cmd_rmbranch "$@";;
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
  # Forward Mac agent list so the box honors `workframe agents` (see config.sh).
  [ -n "$VALID_AGENTS" ] && cmd+=" WORKFRAME_VALID_AGENTS=$(printf '%q' "$VALID_AGENTS")"
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
_pick_worktree(){ local rows; rows=$(_bx_list worktrees); [ -z "$rows" ] && { printf '  %sno worktrees yet%s\n' "$DIM" "$N" >&2; return 1; }
  local -a labels=() paths=(); while IFS=$'\t' read -r ag repo city path br; do [ -n "$path" ] || continue; local f=${br#*/}; [ -n "$f" ] || f=$city; labels+=("$repo / $f   ·   $ag"); paths+=("$path"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-worktree}" "${labels[@]}") || return 1; local i; for i in "${!labels[@]}"; do [ "${labels[i]}" = "$sel" ] && { printf '%s' "${paths[i]}"; return 0; }; done; return 1; }
_resolve_worktree(){ local sel=$1 rows matches count
  if [ -n "$MAC_ROOT" ]; then
    case "$sel" in "$MAC_ROOT"/*)
      if ! _is_local_store; then sel="$BOX_ROOT${sel#"$MAC_ROOT"}"; fi
      ;;
    esac
  fi
  rows=$(_bx_list worktrees)
  matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r ag repo city path br; do
    local feature=${br#*/}
    if [ "$path" = "$sel" ] || [ "$sel" = "$city" ] || [ "$sel" = "$br" ] || [ "$sel" = "$ag/$repo/$city" ] || [ "$sel" = "$repo/$feature" ]; then
      printf '%s\n' "$path"
    fi
  done)
  count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" = 1 ] && { printf '%s' "$matches"; return 0; }
  [ "$count" = 0 ] && die "no worktree matching '$sel'"
  die "'$sel' matches multiple worktrees — use agent/repo/city"
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
  [ -t 0 ] && [ -t 1 ] || return 0
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
  if ! _agents_configured; then
    printf '    %sadd an agent in the Workframe wizard%s\n' "$GRN" "$N"
  fi
  printf '    %schoose Repositories to add a repository%s\n' "$GRN" "$N"
  printf '    %schoose Workspaces to create your first workspace%s\n' "$GRN" "$N"
}

# The product surface is a guided session. Individual mac_* functions remain
# available for compatibility and automation, but normal interactive use starts
# with an intent (start, continue, manage, configure), never a verb to recall.
_wizard_screen(){
  _header
  printf '\n  %s%s%s\n' "$W" "$1" "$N"
  [ -n "${2:-}" ] && printf '  %s%s%s\n' "$DIM" "$2" "$N"
  printf '\n'
}

_wizard_profile_summary(){
  if _is_local_store; then
    printf '  %sLocal store%s  %s\n' "$GRN" "$N" "$ROOT"
  else
    printf '  %sShared store%s  %s → %s\n' "$GRN" "$N" "$BOX_HOST" "$MAC_ROOT"
  fi
}

_wizard_agents(){
  local choice name
  while :; do
    _wizard_screen "Agents" "Agents name branch namespaces and keep work isolated."
    choice=$(_choose "manage agent identities" \
      "show configured agents" \
      "add an agent" \
      "remove an agent" \
      "back") || return 0
    case "$choice" in
      "show configured agents") agents_list;;
      "add an agent")
        name=$(_input "agent name (letters, numbers, . _ -)" "")
        [ -n "$name" ] && agents_add "$name"
        ;;
      "remove an agent")
        if ! _agents_configured; then
          warn "no agents configured"
          continue
        fi
        _agents_array
        name=$(_choose "remove which agent?" "${AGENTS_ARR[@]}") || continue
        _confirm "remove agent '$name'? Active workspaces prevent removal." && agents_remove "$name"
        ;;
      back) return 0;;
    esac
    printf '\n'
  done
}

_wizard_start_workspace(){
  local repos choice
  repos=$(_bx_list repos) || return $?
  if [ -z "$repos" ]; then
    _wizard_screen "Start a workspace" "A repository is needed before Workframe can create isolated work."
    choice=$(_choose "no repositories are available" "add a repository" "back") || return 0
    [ "$choice" = "add a repository" ] && mac_clone "$@"
    return 0
  fi
  mac_new "$@"
}

_wizard_lifecycle(){
  local choice
  while :; do
    _wizard_screen "Workspace lifecycle" "Archive is reversible. Permanent deletion is kept separate."
    choice=$(_choose "choose a workspace action" \
      "browse active workspaces" \
      "rename a workspace" \
      "archive a workspace" \
      "restore archived work" \
      "browse archived work" \
      "permanently delete archived work" \
      "back") || return 0
    case "$choice" in
      "browse active workspaces") mac_list "$@";;
      "rename a workspace") mac_rename "$@";;
      "archive a workspace") mac_archive "$@";;
      "restore archived work") mac_restore "$@";;
      "browse archived work") mac_archived;;
      "permanently delete archived work") mac_rmbranch;;
      back) return 0;;
    esac
    printf '\n'
  done
}

_wizard_repositories(){
  local choice
  while :; do
    _wizard_screen "Repositories" "Each repository has one canonical clone and any number of isolated workspaces."
    choice=$(_choose "manage repositories" \
      "add a repository" \
      "browse repositories" \
      "sync repositories" \
      "clean stale worktrees" \
      "permanently delete a repository" \
      "back") || return 0
    case "$choice" in
      "add a repository") mac_clone "$@";;
      "browse repositories") banner "repositories"; _bx repos;;
      "sync repositories") mac_sync "$@";;
      "clean stale worktrees") mac_clean "$@";;
      "permanently delete a repository") mac_delrepo;;
      back) return 0;;
    esac
    printf '\n'
  done
}

_wizard_profile(){
  local choice
  _wizard_screen "Choose a profile" "Local keeps everything on this machine. Shared uses a remote store and mounted path."
  choice=$(_choose "where should Workframe operate?" \
    "local    this machine ($WORKFRAME_USER_DIR)" \
    "shared   remote box and mounted workspace") || return 0
  case "$choice" in
    local*)
      WORKFRAME_PROFILE_TYPE=local
      _save_user_config || die "could not save Workframe configuration"
      _activate_profile
      ok "now using local store  ${DIM}$ROOT${N}"
      ;;
    shared*)
      WORKFRAME_PROFILE_TYPE=shared
      _ask_shared_stack
      _save_user_config || die "could not save Workframe configuration"
      _activate_profile
      ok "now using shared store  ${DIM}$BOX_HOST${N}"
      ;;
  esac
}

_wizard_settings(){
  local choice
  while :; do
    _wizard_screen "Settings" "Configure the store and the tools Workframe uses for your work."
    _wizard_profile_summary
    printf '\n'
    choice=$(_choose "what would you like to configure?" \
      "editor and github defaults" \
      "agents" \
      "profile (local or shared)" \
      "shared connection details" \
      "run setup again" \
      "back") || return 0
    case "$choice" in
      "editor and github defaults")
        _ask_prefs
        _save_user_config || die "could not save Workframe configuration"
        ok "preferences saved"
        ;;
      agents) _wizard_agents;;
      "profile (local or shared)") _wizard_profile;;
      "shared connection details")
        WORKFRAME_PROFILE_TYPE=shared
        _ask_shared_stack
        _save_user_config || die "could not save Workframe configuration"
        _activate_profile
        ok "shared connection saved"
        ;;
      "run setup again") mac_setup;;
      back) return 0;;
    esac
    printf '\n'
  done
}

_wizard_health(){
  local choice
  while :; do
    _wizard_screen "System health" "Use status for a quick check and diagnostics when something needs attention."
    choice=$(_choose "choose a system task" \
      "show status" \
      "run diagnostics" \
      "update workframe" \
      "back") || return 0
    case "$choice" in
      "show status") mac_status;;
      "run diagnostics") mac_doctor;;
      "update workframe") mac_update "$@";;
      back) return 0;;
    esac
    printf '\n'
  done
}

mac_wizard(){
  if ! { [ -t 0 ] && [ -t 1 ]; }; then
    _help
    return 0
  fi

  # A first run (or a selected root that is currently unavailable) begins with
  # setup, then returns to this same guided session.
  if ! _user_config_exists || { [ "${WORKFRAME_ROOT_SELECTED:-0}" = 1 ] && [ ! -d "$WORKFRAME_USER_DIR" ]; }; then
    _wizard_screen "Welcome to Workframe" "Set up a home for repositories and isolated workspaces."
    mac_setup || return $?
    _user_config_exists || return 0
  fi

  local choice
  while :; do
    _wizard_screen "Workframe" "Choose the next outcome. Workframe will ask only for the details it needs."
    _wizard_profile_summary
    printf '\n'
    choice=$(_choose "what do you want to do?" \
      "start a new workspace" \
      "continue working in a workspace" \
      "manage workspace lifecycle" \
      "manage repositories" \
      "settings and agents" \
      "system health" \
      "exit workframe") || return 0
    case "$choice" in
      "start a new workspace") _wizard_start_workspace "$@";;
      "continue working in a workspace") mac_ide "$@";;
      "manage workspace lifecycle") _wizard_lifecycle "$@";;
      "manage repositories") _wizard_repositories "$@";;
      "settings and agents") _wizard_settings;;
      "system health") _wizard_health "$@";;
      "exit workframe") return 0;;
    esac
    printf '\n'
  done
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

_setup_add_agents(){
  local raw=${1:-} name
  raw=$(printf '%s' "$raw" | tr ',;' '  ')
  for name in $raw; do
    name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
    _agent_name_ok "$name" || die "invalid agent name '$name' (use [a-z0-9._-]+)"
    _is_agent "$name" && continue
    VALID_AGENTS=$(printf '%s %s' "$VALID_AGENTS" "$name" | tr -s ' ')
    VALID_AGENTS=${VALID_AGENTS# }
  done
}

_ask_setup_agents(){
  local current entered
  current=$(printf '%s' "$VALID_AGENTS" | tr -s ' ' | sed 's/^ //;s/ $//;s/ /, /g')
  printf '  %sAgent identities become branch namespaces and choices when creating a workspace.%s\n\n' "$DIM" "$N"
  entered=$(_input "agent names (comma separated)" "$current")
  [ -n "$entered" ] || die "need at least one agent name"
  VALID_AGENTS=""
  _setup_add_agents "$entered"
  _agents_configured || die "need at least one agent name"
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
  printf 'usage: workframe setup [--local|--shared] [--root <path>] [--agent <name>] [--editor <command>] [--org <name>]\n'
}

mac_setup(){
  banner "setup"
  local mode="" requested_root="" agents_to_add="" editor="" org=""
  local interactive=0 explicit=0
  [ -t 0 ] && [ -t 1 ] && interactive=1

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
      --agent)
        [ $# -ge 2 ] || die "missing value for --agent"
        agents_to_add=$(printf '%s %s' "$agents_to_add" "$2"); explicit=1; shift 2
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
      _ask_setup_agents
      _ask_prefs
    else
      [ -n "$agents_to_add" ] && _setup_add_agents "$agents_to_add"
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
    _ask_setup_agents
    _ask_prefs
  else
    [ -n "$agents_to_add" ] && _setup_add_agents "$agents_to_add"
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
  warn "'workframe init' was renamed to 'workframe setup'"
  mac_setup "$@"
}

# Shared profile: inspect box worktrees, not the mount (may be stale/down).
_list_agent_worktrees(){
  if ! _is_local_store; then
    _bx_list worktrees 2>/dev/null || true
  else
    cmd_worktrees 2>/dev/null || true
  fi
}

mac_agents(){
  local sub="${1:-list}"; shift || true
  case "$sub" in
    ""|list|ls) agents_list;;
    add) agents_add "$@";;
    remove|rm) agents_remove "$@";;
    *) die "usage: workframe agents [list|add <name>|remove <name>]";;
  esac
}

mac_list(){
  local sub="${1:-}"
  case "$sub" in
    archived|--archived) mac_archived;;
    ""|active) banner "worktrees"; _bx list;;
    *) die "usage: workframe list [archived]";;
  esac
}

mac_new(){ local agent="" repo="" feature=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) agent=$2; shift 2;;
      -h|--help) printf 'usage: workframe new <repo> <feature> [--agent <name>]\n'; return 0;;
      -*) die "unknown flag: $1 (usage: workframe new <repo> <feature> [--agent <name>])";;
      *) if [ -z "$repo" ]; then repo=$1; elif [ -z "$feature" ]; then feature=$1; else die "usage: workframe new <repo> <feature> [--agent <name>]"; fi; shift;;
    esac
  done
  agent=$(_resolve_agent "$agent") || return 1
  local all matches mcount
  all=$(_bx_list repos)
  if [ -z "$all" ]; then
    die "no repositories yet — add one from the Repositories menu"
  fi
  if [ -z "$repo" ]; then
    if [ -t 0 ] && [ -t 1 ]; then repo=$(_choose "which repo?" $all) || return 0
    else die "usage: workframe new <repo> <feature> --agent <name>"; fi
  fi
  [ -n "$repo" ] || return 0
  if ! printf '%s\n' "$all" | grep -qx "$repo"; then
    matches=$(printf '%s\n' "$all" | grep -i -F "$repo" || true)
    mcount=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$mcount" = 1 ]; then
      repo=$(printf '%s\n' "$matches" | sed '/^$/d' | head -1)
    elif [ "$mcount" = 0 ]; then
      die "no repository matching '$repo' — add one from the Repositories menu"
    else
      printf '  %sambiguous repo %s — matches:%s\n' "$YEL" "'$repo'" "$N" >&2
      printf '%s\n' "$matches" | sed '/^$/d' | sed 's/^/    /' >&2
      die "use an exact repo name"
    fi
  fi
  if [ -z "$feature" ]; then
    if [ -t 0 ] && [ -t 1 ]; then
      # No default applied — empty cancels (hint only in the label).
      feature=$(_input "feature name (e.g. dark-mode)" "")
      [ -n "$feature" ] || { warn "cancelled"; return 0; }
    else
      die "usage: workframe new <repo> <feature> --agent <name>"
    fi
  fi
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  if ! _spin_run "creating $agent/$feature" _bx new "$agent" "$repo" "$feature"; then
    err "${SPIN_OUT:-create failed}"; return 1
  fi
  local out="$SPIN_OUT"
  _bx_invalidate
  local boxpath branch macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); branch=$(printf '%s' "$out" | sed -n 's/^branch: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"; ok "created ${GRN}$branch${N}  ${DIM}$macpath${N}"
  if [ -t 1 ] && command -v "$EDITOR_CMD" >/dev/null 2>&1 && _confirm "open in $EDITOR_CMD?"; then _editor_open "$macpath"; fi; }
mac_rename(){ local sel="${1:-}" feature="${2:-}" worktree
  if [ -n "$sel" ]; then worktree=$(_resolve_worktree "$sel") || return 1
  else worktree=$(_pick_worktree "rename which worktree?") || return 0; fi
  [ -z "$feature" ] && feature=$(_input "new feature name (e.g. dark-mode)" "")
  [ -n "$feature" ] || { warn "cancelled"; return 0; }
  _spin_run "renaming branch" _bx rename "$worktree" "$feature" || return 1
  _bx_invalidate
  _is_local_store || printf '  %s(box is authoritative; local git may show the old name briefly — SMB cache)%s\n' "$DIM" "$N"
  ok "renamed to ${GRN}$feature${N}"; }
mac_ide(){ local worktree="${1:-}"
  if [ -z "$worktree" ]; then worktree=$(_pick_worktree "open in $EDITOR_CMD") || return 0
  else worktree=$(_resolve_worktree "$worktree") || return 1; fi
  worktree=$(_tomac "$worktree")
  _editor_open "$worktree"; ok "opened $worktree"; }
mac_cdpath(){ local worktree="${1:-}"
  if [ -z "$worktree" ]; then worktree=$(_pick_worktree "jump to") || return 1
  else worktree=$(_resolve_worktree "$worktree") || return 1; fi
  _tomac "$worktree"; }
mac_archive(){
  local sel="" yes="" force=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) yes=--yes; shift;;
      --force|-f) force=--force; shift;;
      -h|--help) printf 'usage: workframe archive <worktree|repo/feature|city> [--yes] [--force]\n'; return 0;;
      -*) die "unknown flag: $1 (usage: workframe archive <sel> [--yes] [--force])";;
      *) [ -z "$sel" ] || die "usage: workframe archive <worktree|repo/feature|city> [--yes] [--force]"; sel=$1; shift;;
    esac
  done
  local worktree
  if [ -n "$sel" ]; then
    worktree=$(_resolve_worktree "$sel") || return 1
  elif [ -t 0 ] && [ -t 1 ]; then
    worktree=$(_pick_worktree "archive which worktree?") || return 0
  else
    die "usage: workframe archive <worktree|repo/feature|city> [--yes] [--force]"
  fi
  # --yes skips soft confirm only. Dirty discard requires --force (never auto via --yes).
  _confirm_yes "archive $(basename "$worktree")? (keeps the branch — restorable)" "$yes" || { warn "cancelled"; return 0; }
  local out rc
  banner "archive $(basename "$worktree")"
  # Pass --force on the first call when set — no scare + second SSH.
  if [ "$force" = "--force" ]; then
    _progress_run "archiving worktree" _bx archive "$worktree" --force; rc=$?; out="$PROGRESS_OUT"
    if [ "$rc" = 0 ]; then
      _bx_invalidate
      ok "archived ${GRN}${out#archived: }${N}  ${DIM}— restore with: workframe restore <repo> <branch>${N}"
    else
      err "${out:-archive failed}"; return "$rc"
    fi
    return 0
  fi
  _progress_run "archiving worktree" _bx archive "$worktree"; rc=$?; out="$PROGRESS_OUT"
  if [ "$rc" = 3 ]; then
    printf '  %s%s%s\n' "$YEL" "$out" "$N"
    if [ -t 0 ] && [ -t 1 ]; then
      _confirm "discard uncommitted changes and archive anyway?" || { warn "cancelled"; return 0; }
    else
      err "refusing — pass --force to discard dirty work"; return 3
    fi
    if _progress_run "archiving worktree" _bx archive "$worktree" --force; then
      _bx_invalidate
      ok "archived (uncommitted discarded)"
    else
      err "${PROGRESS_OUT:-archive failed}"; return 1
    fi
  elif [ "$rc" = 0 ]; then
    _bx_invalidate
    ok "archived ${GRN}${out#archived: }${N}  ${DIM}— restore with: workframe restore <repo> <branch>${N}"
  else
    err "${out:-archive failed}"; return "$rc"
  fi
}
mac_archived(){ banner "archived"; local rows; rows=$(_bx archived)
  [ -z "$rows" ] && { printf '  %snothing archived%s\n' "$DIM" "$N"; return; }
  printf '  %s%-8s %-12s %-24s %s%s\n' "$W" AGENT REPO BRANCH WHEN "$N"
  printf '%s\n' "$rows" | while IFS=$'\t' read -r ag repo br when; do
    printf '  %s%-8s%s %-12s %s%-24s%s %s%s%s\n' "$GRN" "$ag" "$N" "$repo" "$W" "${br#*/}" "$N" "$DIM" "$when" "$N"; done; }
_pick_archived(){ local rows; rows=$(_bx archived); [ -z "$rows" ] && { printf '  %snothing archived%s\n' "$DIM" "$N" >&2; return 1; }
  A_LABELS=(); A_REPOS=(); A_BRANCHES=(); local ag repo br when
  while IFS=$'\t' read -r ag repo br when; do [ -n "$br" ] || continue; A_LABELS+=("$repo / ${br#*/}   ·   $ag   ${DIM}$when${N}"); A_REPOS+=("$repo"); A_BRANCHES+=("$br"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-archived worktree}" "${A_LABELS[@]}") || return 1
  local i; for i in "${!A_LABELS[@]}"; do [ "${A_LABELS[i]}" = "$sel" ] && { A_IDX=$i; return 0; }; done; return 1; }
# Resolve an archived branch from repo + branch, or a single selector (branch / repo/feature).
_resolve_archived(){
  local a="${1:-}" b="${2:-}" rows matches count
  rows=$(_bx archived)
  [ -z "$rows" ] && die "nothing archived"
  if [ -n "$a" ] && [ -n "$b" ]; then
    matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r ag repo br when; do
      [ "$repo" = "$a" ] && [ "$br" = "$b" ] && printf '%s\t%s\n' "$repo" "$br"
    done)
  else
    matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r ag repo br when; do
      local feat=${br#*/}
      if [ "$br" = "$a" ] || [ "$a" = "$repo/$feat" ] || [ "$a" = "$ag/$repo/$feat" ]; then
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
  local repo="${1:-}" branch="${2:-}"
  if [ -n "$repo" ] && [ -n "$branch" ]; then
    _resolve_archived "$repo" "$branch" || return 1
  elif [ -n "$repo" ] && [ -z "$branch" ]; then
    _resolve_archived "$repo" || return 1
  elif [ -t 0 ] && [ -t 1 ]; then
    _pick_archived "restore which?" || return 0
    A_REPO=${A_REPOS[A_IDX]}; A_BRANCH=${A_BRANCHES[A_IDX]}
  else
    die "usage: workframe restore <repo> <branch>"
  fi
  _spin_run "restoring $A_BRANCH" _bx restore "$A_REPO" "$A_BRANCH" || return 1; local out="$SPIN_OUT"
  _bx_invalidate
  local boxpath macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"; ok "restored ${GRN}$A_BRANCH${N}  ${DIM}$macpath${N}"
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
  elif [ -t 0 ] && [ -t 1 ]; then
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
    if [ -t 0 ] && [ -t 1 ]; then
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
    if [ -t 0 ] && [ -t 1 ]; then
      _confirm "force delete anyway (loses that work)?" || { warn "cancelled"; return 0; }
    else
      err "refusing — pass --force to delete at-risk worktrees"; return 3
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
  _progress_run "syncing repos" _bx sync "$target"; printf '%s' "$PROGRESS_OUT"; }

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
    _progress_run "cleaning worktrees" _bx clean --yes; printf '%s' "$PROGRESS_OUT"
    _bx_invalidate
    return 0
  fi
  _progress_run "scanning repos" _bx clean; printf '%s' "$PROGRESS_OUT"
  if [ -t 0 ] && [ -t 1 ]; then
    case "$PROGRESS_OUT" in
      *orphan*|*remote\ gone*)
        _confirm_yes "apply clean (delete listed orphans / remote-gone worktrees)?" "" || { warn "cancelled"; return 0; }
        _progress_run "cleaning worktrees" _bx clean --yes; printf '%s' "$PROGRESS_OUT"
        _bx_invalidate
        ;;
    esac
  fi
}

# Cheap glance — counts + tip commits. Full probes live under `workframe doctor`.
mac_status(){
  banner "status"
  if _is_local_store; then
    ok "profile  ${GRN}local${N}  ${DIM}$ROOT${N}"
  else
    ok "profile  ${GRN}shared${N}"
    if mount | grep -q " on $MAC_ROOT "; then ok "mount up"
    else warn "mount down at $MAC_ROOT — try: workframe doctor"; fi
  fi
  _bx status
}

mac_doctor(){ banner "doctor"
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
  if [ -t 0 ] && [ -t 1 ]; then
    which=$(_choose "what to configure?" \
      "prefs     editor, github org" \
      "profile   local vs shared" \
      "shared    box host, mount, share name" \
      "agents    manage identities") || return 0
  else
    die "usage: workframe config   (interactive — editor, org, profile, shared stack)"
  fi
  case "$which" in
    prefs*)
      printf '  %sEditor / org. Agents are managed from the Agents menu.%s\n\n' "$DIM" "$N"
      _ask_agents_and_prefs
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
    agents*)
      _wizard_agents
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
