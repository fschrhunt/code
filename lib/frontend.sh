#!/usr/bin/env bash
# FRONTEND — the interactive Mac experience. Maps box paths to the local mount,
# forwards git verbs to the backend on the box via _bx (ssh), and drives gum.

_bx(){ local wc=0; [ -t 1 ] && wc=1; local cmd="sudo -u $BOX_USER env HOME=$BOX_HOME WT_COLOR=$wc $BOX_ROOT/system/bin/wt"; local a; for a in "$@"; do cmd+=" $(printf '%q' "$a")"; done; /usr/bin/ssh "$BOX_HOST" "$cmd"; }
_tomac(){ printf '%s' "$1" | sed "s#^$BOX_ROOT#$MAC_ROOT#"; }
_pick_worktree(){ local rows; rows=$(_bx worktrees); [ -z "$rows" ] && { printf '  %sno worktrees yet%s\n' "$DIM" "$N" >&2; return 1; }
  local -a labels=() paths=(); while IFS=$'\t' read -r ag repo city path br; do [ -n "$path" ] || continue; local f=${br#*/}; [ -n "$f" ] || f=$city; labels+=("$repo / $f   ·   $ag"); paths+=("$path"); done <<< "$rows"
  local sel; sel=$(_choose "${1:-worktree}" "${labels[@]}") || return 1; local i; for i in "${!labels[@]}"; do [ "${labels[i]}" = "$sel" ] && { printf '%s' "${paths[i]}"; return 0; }; done; return 1; }
_resolve_worktree(){ local sel=$1 rows matches count
  case "$sel" in "$MAC_ROOT"/*) sel="$BOX_ROOT${sel#"$MAC_ROOT"}";; esac
  case "$sel" in "$BOX_ROOT"/*) printf '%s' "$sel"; return 0;; esac
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
mac_localdeps(){ local wt="${1:-$PWD}"; [ -d "$wt" ] || return 0; local key base; key=$(printf '%s' "$wt" | sed -E 's#^.*/workspaces/##; s#/#_#g'); base="$HOME/.wt-cache/$key"
  local d; for d in $CACHE_DIRS; do [ -L "$wt/$d" ] && continue; mkdir -p "$base/$d"; { [ -e "$wt/$d" ] && [ ! -L "$wt/$d" ] && rm -rf "$wt/$d"; }; ln -s "$base/$d" "$wt/$d"; done; }
mac_new(){ local agent="${WT_AGENT:-}" repo="" feature=""
  while [ $# -gt 0 ]; do case "$1" in --agent) agent=$2; shift 2;; *) if [ -z "$repo" ]; then repo=$1; elif [ -z "$feature" ]; then feature=$1; fi; shift;; esac; done
  [ -n "$agent" ] || agent="$DEFAULT_AGENT"; _is_agent "$agent" || die "unknown agent '$agent'"
  if [ -z "$repo" ]; then if [ -t 0 ] && [ -t 1 ]; then repo=$(_choose "which repo?" $(_bx repos)) || return 0; else die "usage: wt new <repo> [feature] [--agent X]"; fi; fi
  [ -n "$repo" ] || return 0
  local all; all=$(_bx repos); if ! printf '%s\n' "$all" | grep -qx "$repo"; then local m; m=$(printf '%s\n' "$all" | grep -i "$repo" | head -1); [ -n "$m" ] && repo=$m || die "no repo matching '$repo'"; fi
  [ -n "$feature" ] && feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  _spin_run "creating $agent/${feature:-worktree}" _bx new "$agent" "$repo" "$feature" || exit 1; local out="$SPIN_OUT"
  local boxpath branch macpath; boxpath=$(printf '%s' "$out" | sed -n 's/^workspace: //p'); branch=$(printf '%s' "$out" | sed -n 's/^branch: //p'); macpath=$(_tomac "$boxpath")
  mac_localdeps "$macpath"; ok "created ${GRN}$branch${N}  ${DIM}$macpath${N}"
  if [ -t 1 ] && command -v "$EDITOR_CMD" >/dev/null 2>&1 && _confirm "open in $EDITOR_CMD?"; then "$EDITOR_CMD" "$macpath" >/dev/null 2>&1 & fi; }
mac_rename(){ local sel="${1:-}" feature="${2:-}" wt
  if [ -n "$sel" ]; then wt=$(_resolve_worktree "$sel") || return 1
  else wt=$(_pick_worktree "rename which worktree?") || return 0; fi
  [ -z "$feature" ] && feature=$(_input "new feature name" "dark-mode"); [ -n "$feature" ] || { warn "cancelled"; return 0; }
  _bx rename "$wt" "$feature" && printf '  %s(box is authoritative; local git may show the old name briefly — SMB cache)%s\n' "$DIM" "$N"; }
mac_open(){ local wt="${1:-}"
  if [ -z "$wt" ]; then wt=$(_pick_worktree "open in $EDITOR_CMD") || return 0
  else wt=$(_resolve_worktree "$wt") || return 1; fi
  wt=$(_tomac "$wt")
  command -v "$EDITOR_CMD" >/dev/null 2>&1 && { "$EDITOR_CMD" "$wt"; ok "opened $wt"; } || die "editor '$EDITOR_CMD' not found"; }
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
mac_status(){ banner "status"; mount | grep -q " on $MAC_ROOT " && ok "mount up  ${DIM}$MAC_ROOT${N}" || err "mount DOWN — run ~/.local/bin/mount-agents.sh"
  /usr/bin/nc -z -G 2 100.65.233.79 22 2>/dev/null && ok "box reachable" || warn "box not reachable"; _bx status; }
mac_doctor(){ banner "doctor"; mount | grep -q " on $MAC_ROOT " && ok "mount up" || err "mount DOWN"; /usr/bin/nc -z -G 2 100.65.233.79 22 2>/dev/null && ok "box reachable" || err "box unreachable"
  command -v gum >/dev/null 2>&1 && ok "gum (pretty UI) installed" || warn "gum missing — run: wt update"; _bx doctor; }
mac_config(){ banner "settings"
  printf '  %sYour personal defaults. Press Enter on any line to keep the %s(current)%s value.%s\n\n' "$DIM" "$DIM" "$DIM" "$N"
  local conf="$MAC_ROOT/system/config/wt.conf"
  printf '  %sWhich agent are you?%s  %sused as the folder + branch prefix when you don'\''t pass --agent%s\n' "$W" "$N" "$DIM" "$N"
  local a; a=$(_input "agent — one of: $VALID_AGENTS" "$DEFAULT_AGENT"); a=${a:-$DEFAULT_AGENT}
  echo; printf '  %sWhich editor should '\''wt open'\'' launch?%s\n' "$W" "$N"
  local e; e=$(_input "editor command, e.g. cursor or code" "$EDITOR_CMD"); e=${e:-$EDITOR_CMD}
  echo; printf '  %sDefault GitHub org?%s  %sso '\''wt clone site'\'' means '\''org/site'\'' without typing the owner%s\n' "$W" "$N" "$DIM" "$N"
  local o; o=$(_input "github org" "$DEFAULT_ORG"); o=${o:-$DEFAULT_ORG}
  printf 'DEFAULT_AGENT=%s\nEDITOR_CMD=%s\nDEFAULT_ORG=%s\n' "$a" "$e" "$o" > "$conf" \
    && { echo; ok "saved — agent ${GRN}$a${N}, editor ${GRN}$e${N}, org ${GRN}$o${N}"; }
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
mac_update(){ banner "update"; mount | grep -q " on $MAC_ROOT " || ~/.local/bin/mount-agents.sh >/dev/null 2>&1
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

# ---- wizard: the logo landing + an arrow-key menu (bare `wt`) ----
wizard(){ clear 2>/dev/null
  _header
  local c; c=$(_choose "what would you like to do?" \
    "new       start a new worktree" \
    "open      open a worktree in $EDITOR_CMD" \
    "rename    rename a worktree's branch" \
    "archive   put a worktree away (keeps the branch)" \
    "restore   bring an archived worktree back" \
    "list      list active worktrees" \
    "archived  list archived worktrees" \
    "clone     add a repo from GitHub" \
    "sync      pull the latest for every repo" \
    "clean     remove safe remote-deleted worktrees" \
    "remove    permanently delete an archived worktree or repo" \
    "config    settings & guided setup" \
    "update    update this Mac" \
    "doctor    check everything works") || { echo; return 0; }
  case "${c%% *}" in
    new)      mac_new;;
    open)     mac_open;;
    rename)   mac_rename;;
    archive)  mac_archive;;
    restore)  mac_restore;;
    list)     banner "worktrees"; _bx list;;
    archived) mac_archived;;
    clone)    mac_clone;;
    sync)     banner "sync"; _bx sync --all;;
    clean)    banner "clean"; _bx clean;;
    remove)   mac_remove;;
    config)   mac_config;;
    update)   mac_update;;
    doctor)   mac_doctor;;
  esac; }
