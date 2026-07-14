#!/usr/bin/env bash
# FRONTEND — the interactive Mac experience. Maps box paths to the local mount
# (shared), or runs cmd_* in-process (local profile). Drives gum UX.

# Dispatch a backend verb: local profile (or WT_HOME) runs in-process; else SSH.
_bx(){
  if [ "${WT_PROFILE_TYPE:-shared}" = local ] || [ -n "${WT_HOME:-}" ]; then
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
  local wc=0; [ -t 1 ] && wc=1
  local cmd="sudo -u $BOX_USER env HOME=$BOX_HOME WT_COLOR=$wc $BOX_ROOT/system/bin/wt"
  local a; for a in "$@"; do cmd+=" $(printf '%q' "$a")"; done
  /usr/bin/ssh "$BOX_HOST" "$cmd"
}
_tomac(){
  if [ "${WT_PROFILE_TYPE:-shared}" = local ] || [ -n "${WT_HOME:-}" ]; then
    printf '%s' "$1"; return 0
  fi
  printf '%s' "$1" | sed "s#^$BOX_ROOT#$MAC_ROOT#"
}
_pick_worktree(){ local rows; rows=$(_bx worktrees); [ -z "$rows" ] && { printf '  %sno worktrees yet%s\n' "$DIM" "$N" >&2; return 1; }
  local -a labels=() paths=(); while IFS=$'\t' read -r ag repo city path br; do [ -n "$path" ] || continue; local f=${br#*/}; [ -n "$f" ] || f=$city; labels+=("$repo / $f   ·   $ag"); paths+=("$path"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-worktree}" "${labels[@]}") || return 1; local i; for i in "${!labels[@]}"; do [ "${labels[i]}" = "$sel" ] && { printf '%s' "${paths[i]}"; return 0; }; done; return 1; }
_resolve_worktree(){ local sel=$1 rows matches count
  case "$sel" in "$MAC_ROOT"/*)
    if [ "${WT_PROFILE_TYPE:-shared}" != local ]; then sel="$BOX_ROOT${sel#"$MAC_ROOT"}"; fi
    ;;
  esac
  case "$sel" in "$ROOT"/*|"$BOX_ROOT"/*|"$MAC_ROOT"/*) printf '%s' "$sel"; return 0;; esac
  rows=$(_bx worktrees)
  matches=$(printf '%s\n' "$rows" | while IFS=$'\t' read -r ag repo city path br; do
    local feature=${br#*/}
    if [ "$sel" = "$city" ] || [ "$sel" = "$br" ] || [ "$sel" = "$ag/$repo/$city" ] || [ "$sel" = "$repo/$feature" ]; then
      printf '%s\n' "$path"
    fi
  done)
  count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" = 1 ] && { printf '%s' "$matches"; return 0; }
  [ "$count" = 0 ] && die "no worktree matching '$sel'"
  die "'$sel' matches multiple worktrees — use agent/repo/city"
}
mac_localdeps(){
  # Local SSD store keeps deps in-tree; cache symlinks are shared-SMB only.
  [ "${WT_PROFILE_TYPE:-shared}" = local ] && return 0
  [ -n "${WT_HOME:-}" ] && return 0
  local wt="${1:-$PWD}"; [ -d "$wt" ] || return 0; local key base; key=$(printf '%s' "$wt" | sed -E 's#^.*/workspaces/##; s#/#_#g'); base="$HOME/.wt-cache/$key"
  local d; for d in $CACHE_DIRS; do [ -L "$wt/$d" ] && continue; mkdir -p "$base/$d"; { [ -e "$wt/$d" ] && [ ! -L "$wt/$d" ] && rm -rf "$wt/$d"; }; ln -s "$base/$d" "$wt/$d"; done; }

mac_init(){
  banner "init"
  if [ -f "$WT_USER_CONFIG" ] && [ "${WT_PROFILE_TYPE:-}" = local ]; then
    ok "local profile already at ${GRN}$WT_USER_DIR${N}"
    return 0
  fi
  WT_PROFILE_TYPE=local
  mkdir -p "$WT_USER_DIR/repos" "$WT_USER_DIR/workspaces" "$WT_USER_DIR/system/logs"
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
  e=$(_input "editor command" "$EDITOR_CMD"); EDITOR_CMD=${e:-$EDITOR_CMD}
  o=$(_input "default github org" "$DEFAULT_ORG"); DEFAULT_ORG=${o:-$DEFAULT_ORG}
  _save_user_config
  ROOT="$WT_USER_DIR"
  [ -d "$ROOT" ] && ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
  REPOS="$ROOT/repos"; WORK="$ROOT/workspaces"; LOGDIR="$ROOT/system/logs"
  ok "local profile ready  ${DIM}$WT_USER_DIR${N}"
  if [ -d "$MAC_ROOT/repos" ] || [ -d "$MAC_ROOT/workspaces" ]; then
    printf '  %shint:%s shared store detected at %s — keep using a shared profile later via config if needed%s\n' "$DIM" "$N" "$MAC_ROOT" "$N"
  fi
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
  _bx rename "$wt" "$feature" && { [ "${WT_PROFILE_TYPE:-shared}" = local ] || printf '  %s(box is authoritative; local git may show the old name briefly — SMB cache)%s\n' "$DIM" "$N"; }; }
mac_open(){ local wt="${1:-}"
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
  local out rc; out=$(_bx archive "$wt"); rc=$?
  if [ "$rc" = 3 ]; then printf '  %s%s%s\n' "$YEL" "$out" "$N"; _confirm "discard uncommitted changes and archive anyway?" && _bx archive "$wt" --yes >/dev/null && ok "archived (uncommitted discarded)" || warn "cancelled"
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
      _confirm "permanently delete branch ${A_BRANCHES[A_IDX]}? cannot be undone" && _bx rmbranch "${A_REPOS[A_IDX]}" "${A_BRANCHES[A_IDX]}" >/dev/null && ok "deleted ${A_BRANCHES[A_IDX]}" || warn "cancelled";;
    a\ whole*) mac_delrepo;;
  esac; }
mac_delrepo(){ local repos; repos=$(_bx repos); [ -z "$repos" ] && { warn "no repos"; return 0; }
  local repo; repo=$(_choose "delete which repo?" $repos) || return 0
  _confirm "delete repo '$repo' and ALL its worktrees? cannot be undone" || { warn "cancelled"; return 0; }
  local out rc; out=$(_bx delrepo "$repo"); rc=$?
  if [ "$rc" = 3 ]; then printf '%s\n' "$out"; _confirm "force delete anyway (loses that work)?" && _bx delrepo "$repo" --force >/dev/null && ok "repo deleted: $repo" || warn "cancelled"
  elif [ "$rc" = 0 ]; then ok "repo deleted: $repo"; else printf '%s\n' "$out"; fi; }
mac_clone(){ local spec="${1:-}"; [ -n "$spec" ] || spec=$(_input "repo to clone" "owner/repo"); [ -n "$spec" ] || return 0
  local name; name=$(basename "${spec%.git}"); banner "clone $name"
  _bx clone "$spec" 2>&1 | tr '\r' '\n' | while IFS= read -r line; do case "$line" in
    cloned:*) printf '\r\e[2K'; ok "${line#cloned: }";;
    REFUSED*|*"already have"*|*"clone failed"*|*fatal:*) printf '\r\e[2K'; err "${line#*✗ }";;
    *%*) p=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tail -1 | tr -d '%'); [ -n "$p" ] && _bar "cloning $name" "$p";; esac; done; }
mac_status(){ banner "status"
  if [ "${WT_PROFILE_TYPE:-shared}" = local ]; then
    ok "local profile  ${DIM}$ROOT${N}"
  else
    mount | grep -q " on $MAC_ROOT " && ok "mount up  ${DIM}$MAC_ROOT${N}" || err "mount DOWN — run ~/.local/bin/mount-agents.sh"
    /usr/bin/nc -z -G 2 100.65.233.79 22 2>/dev/null && ok "box reachable" || warn "box not reachable"
  fi
  _bx status; }
mac_doctor(){ banner "doctor"
  if [ "${WT_PROFILE_TYPE:-shared}" = local ]; then
    ok "local profile  ${DIM}$ROOT${N}"
    command -v gum >/dev/null 2>&1 && ok "gum (pretty UI) installed" || warn "gum missing — optional for prettier menus"
    _bx doctor
    return
  fi
  mount | grep -q " on $MAC_ROOT " && ok "mount up" || err "mount DOWN"
  /usr/bin/nc -z -G 2 100.65.233.79 22 2>/dev/null && ok "box reachable" || err "box unreachable"
  command -v gum >/dev/null 2>&1 && ok "gum (pretty UI) installed" || warn "gum missing — run: wt update"
  _bx doctor; }
mac_config(){ banner "settings"
  printf '  %sYour personal settings. Agents are managed with %swt agents%s.%s\n\n' "$DIM" "$GRN" "$N" "$N"
  printf '  %sWhich editor should '\''wt open'\'' launch?%s\n' "$W" "$N"
  local e; e=$(_input "editor command, e.g. cursor or code" "$EDITOR_CMD"); e=${e:-$EDITOR_CMD}
  echo; printf '  %sDefault GitHub org?%s  %sso '\''wt clone site'\'' means '\''org/site'\'' without typing the owner%s\n' "$W" "$N" "$DIM" "$N"
  local o; o=$(_input "github org" "$DEFAULT_ORG"); o=${o:-$DEFAULT_ORG}
  EDITOR_CMD=$e; DEFAULT_ORG=$o
  _save_user_config
  echo; ok "saved — editor ${GRN}$e${N}, org ${GRN}$o${N}"
  printf '  %sagents:%s %s\n' "$DIM" "$N" "${VALID_AGENTS:-none — wt agents add <name>}"
  local zrc="$HOME/.zshrc"
  if ! grep -q 'wt cd shell integration' "$zrc" 2>/dev/null; then
    echo; printf '  %s'\''wt cd'\'' can drop your terminal straight into a worktree, but that needs a\n  one-line helper added to your ~/.zshrc.%s\n' "$DIM" "$N"
    if _confirm "add the 'wt cd' shortcut to ~/.zshrc?"; then
      cat >> "$zrc" <<'ZF'

# wt cd shell integration
wt() { if [ "$1" = "cd" ]; then local d; d="$(command wt __cdpath "${@:2}")" && [ -d "$d" ] && cd "$d"; return; fi; command wt "$@"; }
ZF
      ok "added — restart your shell or run: source ~/.zshrc"; fi
  fi; }
mac_update(){ banner "update"
  if [ "${WT_PROFILE_TYPE:-shared}" = local ]; then
    warn "local profile — update via git install / re-run install.sh for now"
    return 0
  fi
  mount | grep -q " on $MAC_ROOT " || ~/.local/bin/mount-agents.sh >/dev/null 2>&1
  mount | grep -q " on $MAC_ROOT " || { err "mount is down — could not bring it up"; return 1; }; ok "mount up"
  local S="$MAC_ROOT/system/setup"; if [ -d "$S" ]; then mkdir -p ~/.local/bin ~/.local/state ~/Library/LaunchAgents
    [ -f "$S/mount-agents.sh" ] && install -m 0755 "$S/mount-agents.sh" ~/.local/bin/mount-agents.sh && ok "mount script refreshed"
    [ -f "$S/wt-wrapper" ] && install -m 0755 "$S/wt-wrapper" ~/.local/bin/wt && ok "wt wrapper refreshed"
    [ -f "$S/gum" ] && install -m 0755 "$S/gum" ~/.local/bin/gum && ok "gum (pretty UI) installed"
    [ -f "$S/agents-mount.plist" ] && install -m 0644 "$S/agents-mount.plist" ~/Library/LaunchAgents/com.fschrhunt.agents-mount.plist && ok "auto-mount refreshed"
  else warn "no system/setup on the mount"; fi
  local zrc="$HOME/.zshrc"; grep -q WATCHPACK_POLLING "$zrc" 2>/dev/null || printf '\n# hot-reload over SMB\nexport WATCHPACK_POLLING=true\nexport CHOKIDAR_USEPOLLING=true\n' >> "$zrc"
  grep -q 'wt cd shell integration' "$zrc" 2>/dev/null || printf '\n# wt cd shell integration\nwt() { if [ "$1" = "cd" ]; then local d; d="$(command wt __cdpath "${@:2}")" && [ -d "$d" ] && cd "$d"; return; fi; command wt "$@"; }\n' >> "$zrc"
  launchctl bootout gui/"$(id -u)"/com.fschrhunt.agents-mount 2>/dev/null; launchctl bootstrap gui/"$(id -u)" ~/Library/LaunchAgents/com.fschrhunt.agents-mount.plist 2>/dev/null && ok "auto-mount reloaded"
  echo; _bx sync --all; echo; mac_doctor; }

_wizard_more(){
  local c; c=$(_choose "more…" \
    "rename    rename a worktree's branch" \
    "archived  list archived worktrees" \
    "sync      pull the latest for every repo" \
    "clean     remove safe remote-deleted worktrees" \
    "remove    permanently delete an archived worktree or repo" \
    "update    update this Mac / install" \
    "status    store status") || return 0
  case "${c%% *}" in
    rename)   mac_rename;;
    archived) mac_archived;;
    sync)     banner "sync"; _bx sync --all;;
    clean)    banner "clean"; _bx clean;;
    remove)   mac_remove;;
    update)   mac_update;;
    status)   mac_status;;
  esac
}

# ---- wizard: the logo landing + an arrow-key menu (bare `wt`) ----
wizard(){ clear 2>/dev/null
  _header
  local c; c=$(_choose "what would you like to do?" \
    "new       start a new worktree" \
    "open      open a worktree in $EDITOR_CMD" \
    "list      list active worktrees" \
    "archive   put a worktree away (keeps the branch)" \
    "restore   bring an archived worktree back" \
    "clone     add a repo from GitHub" \
    "agents    list / add / remove agents" \
    "config    settings" \
    "doctor    check everything works" \
    "More…     sync, clean, rename, update…") || { echo; return 0; }
  case "${c%% *}" in
    new)      mac_new;;
    open)     mac_open;;
    list)     banner "worktrees"; _bx list;;
    archive)  mac_archive;;
    restore)  mac_restore;;
    clone)    mac_clone;;
    agents)   mac_agents;;
    config)   mac_config;;
    doctor)   mac_doctor;;
    More…)    _wizard_more;;
  esac; }
