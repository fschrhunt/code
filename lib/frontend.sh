#!/usr/bin/env bash
# FRONTEND — interactive Mac UX. Local profile runs cmd_* in-process; shared
# forwards to the box via SSH and maps paths through the mount.

_bx(){
  if _is_local_store; then
    local verb="${1:-}"; shift || true
    case "$verb" in
      new) cmd_new "$@";; rename) cmd_rename "$@";; clone) cmd_clone "$@";; delrepo) cmd_delrepo "$@";;
      list|ls) cmd_list "$@";; sync) cmd_sync "$@";; clean) cmd_clean "$@";;
      archive) cmd_archive "$@";; archived) cmd_archived "$@";; restore) cmd_restore "$@";; rmbranch) cmd_rmbranch "$@";;
      status) cmd_status "$@";; doctor) cmd_doctor "$@";; repos) cmd_repos "$@";; worktrees) cmd_worktrees "$@";;
      *) die "unknown backend verb: $verb";;
    esac
    return $?
  fi
  _require_shared_stack
  local wc=0; [ -t 1 ] && wc=1
  local cmd="sudo -u $BOX_USER env HOME=$BOX_HOME WT_COLOR=$wc WT_BACKEND=1 WT_HOME=$BOX_ROOT"
  [ -n "$VALID_AGENTS" ] && cmd+=" WT_VALID_AGENTS=$(printf '%q' "$VALID_AGENTS")"
  cmd+=" $BOX_ROOT/system/bin/wt"
  local a; for a in "$@"; do cmd+=" $(printf '%q' "$a")"; done
  /usr/bin/ssh "$BOX_HOST" "$cmd"
}
_tomac(){
  if _is_local_store; then
    printf '%s' "$1"; return 0
  fi
  printf '%s' "$1" | sed "s#^$BOX_ROOT#$MAC_ROOT#"
}
_pick_worktree(){ local rows; rows=$(_bx worktrees); [ -z "$rows" ] && { printf '  %sno worktrees yet%s\n' "$DIM" "$N" >&2; return 1; }
  local -a labels=() paths=(); while IFS=$'\t' read -r ag repo city path br; do [ -n "$path" ] || continue; local f=${br#*/}; [ -n "$f" ] || f=$city; labels+=("$repo / $f   ·   $ag"); paths+=("$path"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-worktree}" "${labels[@]}") || return 1; local i; for i in "${!labels[@]}"; do [ "${labels[i]}" = "$sel" ] && { printf '%s' "${paths[i]}"; return 0; }; done; return 1; }
_resolve_worktree(){ local sel=$1 rows matches count
  if [ -n "$MAC_ROOT" ]; then
    case "$sel" in "$MAC_ROOT"/*)
      if ! _is_local_store; then sel="$BOX_ROOT${sel#"$MAC_ROOT"}"; fi
      ;;
    esac
  fi
  rows=$(_bx worktrees)
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
mac_localdeps(){
  _is_local_store && return 0
  local wt="${1:-$PWD}"; [ -d "$wt" ] || return 0; local key base; key=$(printf '%s' "$wt" | sed -E 's#^.*/workspaces/##; s#/#_#g'); base="$HOME/.wt-cache/$key"
  local d; for d in $CACHE_DIRS; do [ -L "$wt/$d" ] && continue; mkdir -p "$base/$d"; { [ -e "$wt/$d" ] && [ ! -L "$wt/$d" ] && rm -rf "$wt/$d"; }; ln -s "$base/$d" "$wt/$d"; done; }

_ask_agents_and_prefs(){
  if ! _agents_configured; then
    printf '  %sAdd agent identities you will choose from on %swt new%s.%s\n' "$DIM" "$GRN" "$N" "$N"
    printf '  %ssuggested:%s %s\n\n' "$DIM" "$N" "$SUGGESTED_AGENTS"
    local first
    first=$(_input "first agent name" "cursor")
    if [ -n "$first" ]; then
      first=$(printf '%s' "$first" | tr '[:upper:]' '[:lower:]')
      _agent_name_ok "$first" || die "invalid agent name '$first'"
      VALID_AGENTS="$first"
    fi
  fi
  local e o
  e=$(_input "editor command" "$EDITOR_CMD"); e=${e:-$EDITOR_CMD}
  o=$(_input "default github org" "$DEFAULT_ORG"); o=${o:-$DEFAULT_ORG}
  _config_safe_val "$e" || die "unsafe editor value"
  _config_safe_val "$o" || die "unsafe org value"
  EDITOR_CMD=$e; DEFAULT_ORG=$o
}

_ask_shared_stack(){
  printf '  %sShared store lives on a box and is mounted locally.%s\n' "$DIM" "$N"
  printf '  %sLeave blank to keep the current value (if any).%s\n\n' "$DIM" "$N"
  local v
  v=$(_input "SSH host (ssh config Host or hostname)" "${BOX_HOST:-my-box}"); [ -n "$v" ] && BOX_HOST=$v
  v=$(_input "box address for probes (IP/hostname)" "${BOX_ADDR:-${BOX_HOST:-my-box.example}}"); [ -n "$v" ] && BOX_ADDR=$v
  v=$(_input "SSH / sudo user on the box" "${BOX_USER:-wt}"); [ -n "$v" ] && BOX_USER=$v
  v=$(_input "remote store root on the box" "${BOX_ROOT:-/mnt/wt}"); [ -n "$v" ] && BOX_ROOT=$v
  v=$(_input "local mount path" "${MAC_ROOT:-/Volumes/wt}"); [ -n "$v" ] && MAC_ROOT=$v
  v=$(_input "SMB share name" "${SHARE_NAME:-wt}"); [ -n "$v" ] && SHARE_NAME=$v
  [ -n "$BOX_HOST" ] && [ -n "$BOX_USER" ] && [ -n "$BOX_ROOT" ] && [ -n "$MAC_ROOT" ] \
    || die "shared stack needs box_host, box_user, box_root, and mount_path"
  _config_safe_val "$BOX_HOST" && _config_safe_val "$BOX_ADDR" && _config_safe_val "$BOX_USER" \
    && _config_safe_val "$BOX_ROOT" && _config_safe_val "$MAC_ROOT" && _config_safe_val "$SHARE_NAME" \
    || die "unsafe shared-stack value"
  _sync_box_home
}

mac_init(){
  banner "init"
  local mode="${1:-}"
  case "$mode" in
    --shared|shared) mode=shared; shift || true;;
    --local|local|"") mode="";;
    -h|--help) printf 'usage: wt init [--local|--shared]\n'; return 0;;
  esac
  if [ -z "$mode" ]; then
    if [ -t 0 ] && [ -t 1 ]; then
      mode=$(_choose "where should worktrees live?" \
        "local    on this machine (~/.wt) — default" \
        "shared   on a box, mounted locally (fleet)") || return 0
      case "$mode" in local*) mode=local;; shared*) mode=shared;; esac
    else
      mode=local
    fi
  fi

  if [ "$mode" = local ]; then
    if [ -f "$WT_USER_CONFIG" ] && [ "${WT_PROFILE_TYPE:-}" = local ]; then
      ok "local profile already at ${GRN}$WT_USER_DIR${N}"
      return 0
    fi
    WT_PROFILE_TYPE=local
    mkdir -p "$WT_USER_DIR/repos" "$WT_USER_DIR/workspaces" "$WT_USER_DIR/system/logs"
    _ask_agents_and_prefs
    _save_user_config
    ROOT="$WT_USER_DIR"
    [ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
    REPOS="$ROOT/repos"; WORK="$ROOT/workspaces"; LOGDIR="$ROOT/system/logs"
    ok "local profile ready  ${DIM}$WT_USER_DIR${N}"
    return 0
  fi

  # shared — all host/path values come from prompts (or existing ~/.wt/config)
  WT_PROFILE_TYPE=shared
  mkdir -p "$WT_USER_DIR"
  _ask_shared_stack
  _ask_agents_and_prefs
  _save_user_config
  ROOT="$MAC_ROOT"
  REPOS="$ROOT/repos"; WORK="$ROOT/workspaces"; LOGDIR="$ROOT/system/logs"
  ok "shared profile saved  ${DIM}$WT_USER_CONFIG${N}"
  printf '  %smount:%s %s  %sbox:%s %s:%s\n' "$DIM" "$N" "$MAC_ROOT" "$DIM" "$N" "$BOX_HOST" "$BOX_ROOT"
  printf '  %snext:%s ensure the share is mounted, then %swt doctor%s\n' "$DIM" "$N" "$GRN" "$N"
}

mac_agents(){
  local sub="${1:-list}"; shift || true
  case "$sub" in
    ""|list|ls) agents_list;;
    add) agents_add "$@";;
    remove|rm) agents_remove "$@";;
    *) die "usage: wt agents [list|add <name>|remove <name>]";;
  esac
}

mac_list(){
  local sub="${1:-}"
  case "$sub" in
    archived|--archived) mac_archived;;
    ""|active) banner "worktrees"; _bx list;;
    *) die "usage: wt list [archived]";;
  esac
}

mac_new(){ local agent="" repo="" feature=""
  while [ $# -gt 0 ]; do case "$1" in --agent) agent=$2; shift 2;; *) if [ -z "$repo" ]; then repo=$1; elif [ -z "$feature" ]; then feature=$1; fi; shift;; esac; done
  agent=$(_resolve_agent "$agent") || return 1
  if [ -z "$repo" ]; then if [ -t 0 ] && [ -t 1 ]; then repo=$(_choose "which repo?" $(_bx repos)) || return 0; else die "usage: wt new <repo> [feature] --agent <name>"; fi; fi
  [ -n "$repo" ] || return 0
  local all; all=$(_bx repos); if ! printf '%s\n' "$all" | grep -qx "$repo"; then local m; m=$(printf '%s\n' "$all" | grep -i "$repo" | head -1); [ -n "$m" ] && repo=$m || die "no repo matching '$repo'"; fi
  [ -n "$feature" ] && feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  _spin_run "creating $agent/${feature:-worktree}" _bx new "$agent" "$repo" "$feature" || exit 1; local out="$SPIN_OUT"
  local boxpath branch macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); branch=$(printf '%s' "$out" | sed -n 's/^branch: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"; ok "created ${GRN}$branch${N}  ${DIM}$macpath${N}"
  if [ -t 1 ] && command -v "$EDITOR_CMD" >/dev/null 2>&1 && _confirm "open in $EDITOR_CMD?"; then _editor_open "$macpath"; fi; }
mac_rename(){ local sel="${1:-}" feature="${2:-}" wt
  if [ -n "$sel" ]; then wt=$(_resolve_worktree "$sel") || return 1
  else wt=$(_pick_worktree "rename which worktree?") || return 0; fi
  [ -z "$feature" ] && feature=$(_input "new feature name" "dark-mode"); [ -n "$feature" ] || { warn "cancelled"; return 0; }
  _spin_run "renaming branch" _bx rename "$wt" "$feature" || return 1
  _is_local_store || printf '  %s(box is authoritative; local git may show the old name briefly — SMB cache)%s\n' "$DIM" "$N"
  ok "renamed to ${GRN}$feature${N}"; }
mac_ide(){ local wt="${1:-}"
  if [ -z "$wt" ]; then wt=$(_pick_worktree "open in $EDITOR_CMD") || return 0
  else wt=$(_resolve_worktree "$wt") || return 1; fi
  wt=$(_tomac "$wt")
  _editor_open "$wt"; ok "opened $wt"; }
mac_cdpath(){ local wt="${1:-}"
  if [ -z "$wt" ]; then wt=$(_pick_worktree "jump to") || return 1
  else wt=$(_resolve_worktree "$wt") || return 1; fi
  _tomac "$wt"; }
mac_archive(){ local wt; wt=$(_pick_worktree "archive which worktree?") || return 0
  _confirm "archive $(basename "$wt")? (keeps the branch — restorable)" || { warn "cancelled"; return 0; }
  local out rc; banner "archive $(basename "$wt")"
  _progress_run "archiving worktree" _bx archive "$wt"; rc=$?; out="$PROGRESS_OUT"
  if [ "$rc" = 3 ]; then printf '  %s%s%s\n' "$YEL" "$out" "$N"; _confirm "discard uncommitted changes and archive anyway?" \
    && { _progress_run "archiving worktree" _bx archive "$wt" --yes; ok "archived (uncommitted discarded)"; } \
    || warn "cancelled"
  elif [ "$rc" = 0 ]; then ok "archived ${GRN}${out#archived: }${N}  ${DIM}— restore with: wt restore${N}"; else printf '%s\n' "$out"; fi; }
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
mac_restore(){ _pick_archived "restore which?" || return 0
  _spin_run "restoring ${A_BRANCHES[A_IDX]}" _bx restore "${A_REPOS[A_IDX]}" "${A_BRANCHES[A_IDX]}" || return 1; local out="$SPIN_OUT"
  local boxpath macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"; ok "restored ${GRN}${A_BRANCHES[A_IDX]}${N}  ${DIM}$macpath${N}"; }
mac_remove(){ local what; what=$(_choose "permanently remove what?" "an archived worktree (deletes its branch)" "a whole repo (deletes everything)") || return 0
  case "$what" in
    an\ archived*) _pick_archived "delete which archived branch?" || return 0
      _confirm "permanently delete branch ${A_BRANCHES[A_IDX]}? cannot be undone" || { warn "cancelled"; return 0; }
      banner "delete ${A_BRANCHES[A_IDX]}"
      _progress_run "deleting branch" _bx rmbranch "${A_REPOS[A_IDX]}" "${A_BRANCHES[A_IDX]}" && ok "deleted ${A_BRANCHES[A_IDX]}" || warn "cancelled";;
    a\ whole*) mac_delrepo;;
  esac; }
mac_delrepo(){ local repos; repos=$(_bx repos); [ -z "$repos" ] && { warn "no repos"; return 0; }
  local repo; repo=$(_choose "delete which repo?" $repos) || return 0
  _confirm "delete repo '$repo' and ALL its worktrees? cannot be undone" || { warn "cancelled"; return 0; }
  local out rc; banner "delete $repo"
  _progress_run "deleting $repo" _bx delrepo "$repo"; rc=$?; out="$PROGRESS_OUT"
  if [ "$rc" = 3 ]; then printf '%s\n' "$out"; _confirm "force delete anyway (loses that work)?" \
    && { _progress_run "deleting $repo" _bx delrepo "$repo" --force; ok "repo deleted: $repo"; } \
    || warn "cancelled"
  elif [ "$rc" = 0 ]; then ok "repo deleted: $repo"; else printf '%s\n' "$out"; fi; }
mac_clone(){ local spec="${1:-}"; [ -n "$spec" ] || spec=$(_input "repo to clone" "owner/repo"); [ -n "$spec" ] || return 0
  local name; name=$(basename "${spec%.git}"); banner "clone $name"
  local out; out=$(_bx clone "$spec" 2>&1 | tr '\r' '\n' | _progress_filter "cloning $name")
  case "$out" in
    *cloned:*) ok "$(printf '%s' "$out" | sed -n 's/.*cloned: //p' | head -1)";;
    *REFUSED*|*"already have"*|*"clone failed"*|*fatal:*) err "$out";;
    *) [ -n "$out" ] && printf '%s\n' "$out";;
  esac; }

mac_sync(){ local target="${1:---all}"; banner "sync"
  _progress_run "syncing repos" _bx sync "$target"; printf '%s' "$PROGRESS_OUT"; }

mac_clean(){ local force="${1:-}"; banner "clean"
  if [ "$force" = "--yes" ]; then
    _progress_run "cleaning worktrees" _bx clean --yes; printf '%s' "$PROGRESS_OUT"
  else
    _progress_run "scanning repos" _bx clean; printf '%s' "$PROGRESS_OUT"
  fi; }

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
  local which
  if [ -t 0 ] && [ -t 1 ]; then
    which=$(_choose "what to configure?" \
      "prefs     editor, github org" \
      "profile   local vs shared" \
      "shared    box host, mount, share name" \
      "agents    (tip: use wt agents)") || return 0
  else
    which="prefs"
  fi
  case "$which" in
    prefs*)
      printf '  %sEditor / org. Agents: %swt agents%s.%s\n\n' "$DIM" "$GRN" "$N" "$N"
      _ask_agents_and_prefs
      _save_user_config
      ok "saved — editor ${GRN}$EDITOR_CMD${N}, org ${GRN}$DEFAULT_ORG${N}"
      ;;
    profile*)
      local p; p=$(_choose "active profile type?" "local" "shared") || return 0
      WT_PROFILE_TYPE=$p
      if [ "$p" = shared ]; then _ask_shared_stack; fi
      _save_user_config
      ok "profile ${GRN}$p${N}"
      ;;
    shared*)
      WT_PROFILE_TYPE=shared
      _ask_shared_stack
      _save_user_config
      ok "shared stack saved"
      printf '  %s%s @ %s → %s (share %s)%s\n' "$DIM" "$BOX_HOST" "$BOX_ROOT" "$MAC_ROOT" "$SHARE_NAME" "$N"
      ;;
    agents*)
      printf '  %suse:%s wt agents add|remove|list\n' "$DIM" "$N"
      agents_list
      ;;
  esac
  local zrc="$HOME/.zshrc"
  if ! grep -q 'wt cd shell integration' "$zrc" 2>/dev/null; then
    echo
    if _confirm "add the 'wt cd' shortcut to ~/.zshrc?"; then
      cat >> "$zrc" <<'ZF'

# wt cd shell integration
wt() { if [ "$1" = "cd" ]; then local d; d="$(command wt __cdpath "${@:2}")" && [ -d "$d" ] && cd "$d"; return; fi; command wt "$@"; }
ZF
      ok "added — restart your shell or: source ~/.zshrc"; fi
  fi
}

mac_update(){ banner "update"
  if _is_local_store; then
    warn "local profile — re-run ./install.sh from the wt repo to refresh the binary"
    return 0
  fi
  _require_shared_stack
  local mount_helper=""
  for mount_helper in "$HOME/.local/bin/mount-wt.sh"; do
    [ -x "$mount_helper" ] && break
    mount_helper=""
  done
  mount | grep -q " on $MAC_ROOT " || { [ -n "$mount_helper" ] && "$mount_helper" >/dev/null 2>&1; }
  mount | grep -q " on $MAC_ROOT " || { err "mount is down at $MAC_ROOT"; return 1; }; ok "mount up"
  local S="$MAC_ROOT/system/setup"
  if [ -d "$S" ]; then
    mkdir -p ~/.local/bin ~/.local/state ~/Library/LaunchAgents
    [ -f "$S/mount-wt.sh" ] && install -m 0755 "$S/mount-wt.sh" ~/.local/bin/mount-wt.sh && ok "mount-wt.sh refreshed"
    [ -f "$S/wt-wrapper" ] && install -m 0755 "$S/wt-wrapper" ~/.local/bin/wt && ok "wt wrapper refreshed"
    [ -f "$S/gum" ] && install -m 0755 "$S/gum" ~/.local/bin/gum && ok "gum installed"
  else warn "no system/setup on the mount"; fi
  echo; mac_sync; echo; mac_doctor
}

# Greptile-style sectioned landing: WORK / SETTINGS / MORE (truecolor menu in ui.sh).
wizard(){ clear 2>/dev/null
  _header
  local c
  c=$(
    {
      _wiz_section "WORK"
      _wiz_item new      "start a new worktree"
      _wiz_item ide      "open a worktree in $EDITOR_CMD"
      _wiz_item list     "list active worktrees"
      _wiz_item archive  "put a worktree away (keeps the branch)"
      _wiz_item restore  "bring an archived worktree back"
      _wiz_item clone    "add a repo from GitHub"
      _wiz_section "SETTINGS"
      _wiz_item agents   "list / add / remove agents"
      _wiz_item config   "editor, org, profile, shared stack"
      _wiz_item init     "create or refresh a profile"
      _wiz_item doctor   "check that everything works"
      _wiz_section "MORE"
      _wiz_item rename   "rename a worktree's branch"
      _wiz_item sync     "pull the latest for every repo"
      _wiz_item clean    "remove safe remote-deleted worktrees"
      _wiz_item remove   "permanently delete archived / repo"
      _wiz_item update   "refresh install / sync"
    } | _wizard_pick "what would you like to do?"
  ) || { echo; return 0; }
  case "$c" in
    ""|__hdr__) wizard; return;;
    new)     mac_new;;
    ide|open) mac_ide;;
    list)    mac_list;;
    archive) mac_archive;;
    restore) mac_restore;;
    clone)   mac_clone;;
    agents)  mac_agents;;
    config)  mac_config;;
    init)    mac_init;;
    doctor)  mac_doctor;;
    rename)  mac_rename;;
    sync)    mac_sync;;
    clean)   mac_clean;;
    remove)  mac_remove;;
    update)  mac_update;;
    *)       wizard; return;;
  esac
}
