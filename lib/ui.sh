#!/usr/bin/env bash
# UI: logo, help text, gum helpers (with a plain fallback), progress.

# ---- logo (8×6 terminal grid derived from assets/logo) ----
LOGO=(
' # ## #'
'#      #'
' #    #'
' #    #'
'#      #'
' # ## #'
)
_header(){
  printf '\n'
  local row cell i
  for row in "${LOGO[@]}"; do
    printf '  '
    for ((i=0; i<${#row}; i++)); do
      cell=${row:i:1}
      if [ "$cell" = "#" ]; then
        if [ -n "$ACID_BG" ]; then
          printf '%s  %s' "$ACID_BG" "$N"
        else
          printf '██'
        fi
      else
        printf '  '
      fi
    done
    printf '\n'
  done
}

# Help layout: onboarding followed by fixed-width command groups.
_help(){
  _header
  sec(){ printf '\n\n  %s%s%s\n\n' "$W" "$1" "$N"; }
  start(){ printf '  %s%-43s%s%s%s%s\n' "$GRN" "$1" "$N" "$DIM" "$2" "$N"; }
  pair(){
    printf '  %s%-10s%s%s%-28s%s%s%-10s%s%s%s%s\n' \
      "$GRN" "$1" "$N" "$DIM" "$2" "$N" \
      "$GRN" "$3" "$N" "$DIM" "$4" "$N"
  }
  single(){ printf '  %s%-10s%s%s%s%s\n' "$GRN" "$1" "$N" "$DIM" "$2" "$N"; }

  printf '\n\n  %sworkframe%s %s<command> [options]%s\n' "$W" "$N" "$DIM" "$N"

  sec "START HERE"
  start "workframe clone owner/repo"               "Add a repository"
  start "workframe new repo feature --agent nova" "Create a workspace"
  start "workframe ide"                            "Open a workspace"

  sec WORKSPACES
  pair new  "Create a worktree" archive "Put one away"
  pair list "Browse worktrees"   restore "Bring one back"
  pair ide  "Open in ${EDITOR_CMD:-editor}" rename "Rename its branch"
  single cd "Print its path"

  sec REPOSITORIES
  pair clone "Add a repository"       sync   "Fetch latest"
  pair clean "Find orphaned worktrees" remove "Delete permanently"

  sec SYSTEM
  pair agents "Manage identities" config "Preferences"
  pair init   "Create a profile"  status "Store overview"
  pair doctor "Run diagnostics"   update "Refresh Workframe"
}

# ---- gum helpers (TTY fill-in when a flag/arg is missing) ----
_has_gum(){ command -v gum >/dev/null 2>&1; }
_gum_env(){ COLORTERM=truecolor CLICOLOR_FORCE=1 "$@"; }
_choose(){ local h=$1; shift; local -a o=("$@")
  if _has_gum; then
    printf '%s\n' "${o[@]}" | _gum_env gum choose --header "$h" --cursor "❯ " \
      --cursor.foreground "$GUM_WHITE" --item.foreground "$GUM_TEAL" \
      --header.foreground "$GUM_GREY" --height 18
    return
  fi
  { printf '  %s%s%s\n' "$DIM" "$h" "$N"; local i=1 x; for x in "${o[@]}"; do printf '  %s%2d%s %s\n' "$CYN" "$i" "$N" "$x"; i=$((i+1)); done; printf '  %s#%s ' "$DIM" "$N"; } >&2
  local n; read -r n; [ -n "$n" ] && [ "$n" -ge 1 ] 2>/dev/null && printf '%s' "${o[$((n-1))]}"; }
# Prompt for a line. DEFAULT is shown as placeholder / [brackets]; Enter keeps it.
# Pass an empty DEFAULT when empty input should stay empty (e.g. cancelable fields).
_input(){
  local header=$1 default=${2:-} v
  if _has_gum; then
    v=$(_gum_env gum input --header "$header" --placeholder "${default}" --prompt "❯ " --prompt.foreground "$GUMC") || true
  else
    if [ -n "$default" ]; then
      printf '  %s%s%s %s[%s]%s ' "$B" "$header" "$N" "$DIM" "$default" "$N" >&2
    else
      printf '  %s%s%s ' "$B" "$header" "$N" >&2
    fi
    read -r v || true
  fi
  printf '%s' "${v:-$default}"
}
_confirm(){ if _has_gum; then _gum_env gum confirm "$1"; else printf '  %s %s[y/N]%s ' "$1" "$DIM" "$N" >&2; local a; read -r a; case "$a" in y|Y) return 0;; *) return 1;; esac; fi; }
# Confirm on TTY, or accept --yes. Non-interactive without --yes refuses.
_confirm_yes(){
  local msg=$1 flag=${2:-}
  [ "$flag" = "--yes" ] && return 0
  if [ -t 0 ] && [ -t 1 ]; then
    _confirm "$msg"
  else
    die "refusing without --yes (non-interactive)"
  fi
}

# ---- progress bar + spinner ----
_bar(){ local label=$1 pct=${2:-0} w=26 i filled bar=''; [ "$pct" -gt 100 ] 2>/dev/null && pct=100; filled=$(( pct * w / 100 ))
  for ((i=0;i<w;i++)); do [ $i -lt $filled ] && bar+='█' || bar+='░'; done
  printf '\r\e[2K  %s%s%s  %s%s%s %s%3s%%%s' "$DIM" "$label" "$N" "$GRN" "$bar" "$N" "$B" "$pct" "$N"; }
_bar_done(){ [ -t 1 ] && printf '\r\e[2K'; }

# Parse workframe-progress:label:pct lines and git-style % updates; pass everything else through.
_progress_filter(){
  local label=$1 line pl pct p
  while IFS= read -r line; do
    case "$line" in
      workframe-progress:*)
        pl=${line#workframe-progress:}; pct=${pl##*:}; pl=${pl%:*}
        [ -t 1 ] && [ -n "$pct" ] && _bar "${pl:-$label}" "$pct"
        ;;
      *%*)
        p=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tail -1 | tr -d '%')
        [ -t 1 ] && [ -n "$p" ] && _bar "$label" "$p"
        ;;
      *) printf '%s\n' "$line";;
    esac
  done
  _bar_done
}

# Run a backend verb with a live progress bar; non-progress stdout → PROGRESS_OUT.
# PROGRESS_OUT / SPIN_OUT are read by frontend callers (separate lint unit).
_progress_run(){
  local label=$1; shift
  local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/workframe.$$.out")
  { "$@" 2>&1 | tr '\r' '\n' | _progress_filter "$label"; } >"$tmp"
  local rc=${PIPESTATUS[0]}
  # shellcheck disable=SC2034
  PROGRESS_OUT=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"
  return "$rc"
}

_spin_run(){ local msg=$1; shift; local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/workframe.$$.out")
  ( "$@" >"$tmp" 2>&1 ) & local pid=$! i=0 fr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  if [ -t 1 ]; then printf '\e[?25l'; while kill -0 "$pid" 2>/dev/null; do printf '\r\e[2K  %s%s%s %s' "$GRN" "${fr:$((i%10)):1}" "$N" "$msg"; i=$((i+1)); sleep 0.08; done; printf '\r\e[2K\e[?25h'; fi
  wait "$pid"; local rc=$?
  # shellcheck disable=SC2034
  SPIN_OUT=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"; return $rc; }
