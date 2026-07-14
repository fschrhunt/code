#!/usr/bin/env bash
# UI: logo + landing, help text, gum helpers (with a plain fallback), progress.

# ---- logo + landing (isometric wt) ----
LOGO=(
'      ___           ___     '
'     /\__\         /\  \    '
'    /:/ _/_        \:\  \   '
'   /:/ /\__\        \:\  \  '
'  /:/ /:/ _/_       /::\  \ '
' /:/_/:/ /\__\     /:/\:\__\'
' \:\/:/ /:/  /    /:/  \/__/'
'  \::/_/:/  /    /:/  /     '
'   \:\/:/  /     \/__/      '
'    \::/  /                 '
'     \/__/                  '
)
_header(){
  local -a T=()
  local ver="${WT_VERSION:-0.0.0}"
  local status
  if [ "${WT_PROFILE_TYPE:-shared}" = local ]; then
    status="Local store at ${ROOT:-$HOME/.wt}"
  else
    status="Shared profile — agents choose · editor opens the IDE"
  fi
  T[4]="${GRN}wt${N} ${DIM}v${ver}${N}"
  T[6]="${W}Isolated git worktrees from your terminal.${N}"
  T[7]="${DIM}${status}${N}"
  echo; local i; for i in "${!LOGO[@]}"; do printf '  %s%-28s%s  %s\n' "$GRN" "${LOGO[i]}" "$N" "${T[i]:-}"; done; echo
}
_help(){
  _header
  printf '  %sEXAMPLES%s\n' "$W" "$N"
  ex(){ printf '  %s%-28s%s %s\n' "$GRN" "$1" "$N" "$2"; }
  ex "wt new <repo>" "Start a worktree (picks agent interactively)."
  ex "wt open" "Open a worktree in a new $EDITOR_CMD window."
  ex "wt archive" "Put a worktree away — keeps the branch, restorable."
  ex "wt agents add <name>" "Add an agent identity to your config."
  echo
  printf '  %sCOMMANDS%s\n' "$W" "$N"
  cm(){ printf '  %s%-10s%s %s\n' "$GRN" "$1" "$N" "$2"; }
  cm new      "Start a new worktree to work in."
  cm open     "Open a worktree in $EDITOR_CMD (new IDE window)."
  cm cd       "Jump into a worktree in the terminal."
  cm list     "List your active worktrees."
  cm archive  "Put a worktree away — keeps the branch."
  cm restore  "Bring an archived worktree back."
  cm clone    "Add a repo from GitHub to the store."
  cm agents   "List, add, or remove configured agents."
  cm config   "Edit editor, org, and related settings."
  cm init     "Create a local ~/.wt profile (first run)."
  cm doctor   "Check that everything's working."
  echo
  printf '  %sMore%s %s— rename, archived, sync, clean, remove, update%s\n' "$W" "$N" "$DIM" "$N"
  echo
}

# ---- gum helpers (glamorous, with a plain fallback) ----
_has_gum(){ command -v gum >/dev/null 2>&1; }
_choose(){ local h=$1; shift; local -a o=("$@")
  if _has_gum; then printf '%s\n' "${o[@]}" | gum choose --header "$h" --cursor "❯ " --cursor.foreground "$GUMC" --header.foreground 244 --height 18; return; fi
  { printf '  %s%s%s\n' "$DIM" "$h" "$N"; local i=1 x; for x in "${o[@]}"; do printf '  %s%2d%s %s\n' "$GRN" "$i" "$N" "$x"; i=$((i+1)); done; printf '  %s#%s ' "$DIM" "$N"; } >&2
  local n; read -r n; [ -n "$n" ] && [ "$n" -ge 1 ] 2>/dev/null && printf '%s' "${o[$((n-1))]}"; }
_input(){ if _has_gum; then gum input --header "$1" --placeholder "${2:-}" --prompt "❯ " --prompt.foreground "$GUMC"; else printf '  %s%s%s ' "$B" "$1" "$N" >&2; local v; read -r v; printf '%s' "$v"; fi; }
_confirm(){ if _has_gum; then gum confirm "$1"; else printf '  %s %s[y/N]%s ' "$1" "$DIM" "$N" >&2; local a; read -r a; case "$a" in y|Y) return 0;; *) return 1;; esac; fi; }

# ---- progress bar + spinner ----
_bar(){ local label=$1 pct=${2:-0} w=26 i filled bar=''; [ "$pct" -gt 100 ] 2>/dev/null && pct=100; filled=$(( pct * w / 100 ))
  for ((i=0;i<w;i++)); do [ $i -lt $filled ] && bar+='█' || bar+='░'; done
  printf '\r\e[2K  %s%s%s  %s%s%s %s%3s%%%s' "$DIM" "$label" "$N" "$GRN" "$bar" "$N" "$B" "$pct" "$N"; }
_spin_run(){ local msg=$1; shift; local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/wt.$$.out")
  ( "$@" >"$tmp" 2>/dev/null ) & local pid=$! i=0 fr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  if [ -t 1 ]; then printf '\e[?25l'; while kill -0 "$pid" 2>/dev/null; do printf '\r\e[2K  %s%s%s %s' "$GRN" "${fr:$((i%10)):1}" "$N" "$msg"; i=$((i+1)); sleep 0.08; done; printf '\r\e[2K\e[?25h'; fi
  wait "$pid"; local rc=$?; SPIN_OUT=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"; return $rc; }
