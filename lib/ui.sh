#!/usr/bin/env bash
# UI: logo, help text, gum helpers (with a plain fallback), progress.

# ---- logo (isometric wt) ----
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
  if [ "${WT_PROFILE_TYPE:-local}" = local ]; then
    status="Local profile · editor ${EDITOR_CMD:-cursor}"
  else
    status="Shared profile · editor ${EDITOR_CMD:-cursor}"
  fi
  # Brand block beside the logo: title, tagline, status.
  T[4]="${GRN}wt${N} ${DIM}v${ver}${N}"
  T[6]="${W}Isolated git worktrees from your terminal.${N}"
  T[7]="${DIM}${status}${N}"
  echo; local i; for i in "${!LOGO[@]}"; do printf '  %s%-28s%s  %s\n' "$GRN" "${LOGO[i]}" "$N" "${T[i]:-}"; done; echo
}

# Help layout: EXAMPLES (full invocations) + COMMANDS (short verbs).
# Keep left columns tight and descriptions short so narrow panes don't wrap junk.
_help(){
  _header
  # Left columns sized so full lines stay ≤ ~72 cols (narrow IDE panes).
  local ex_col=32 cmd_col=10
  sec(){ printf '  %s%s%s\n\n' "$W" "$1" "$N"; }
  ex(){ printf '    %s%-'${ex_col}'s%s  %s%s%s\n' "$CYN" "$1" "$N" "$DIM" "$2" "$N"; }
  cm(){ printf '    %s%-'${cmd_col}'s%s  %s%s%s\n' "$CYN" "$1" "$N" "$DIM" "$2" "$N"; }

  sec EXAMPLES
  ex "wt new repo feat --agent nova"   "Start a worktree for an agent."
  ex "wt list"                         "See active worktrees."
  ex "wt archive <sel> --yes"          "Put a worktree away (keeps branch)."
  ex "wt restore <repo> <branch>"      "Bring an archived branch back."
  ex "wt remove branch <repo> <br>"    "Permanently delete an archived branch."
  echo

  sec COMMANDS
  cm new      "Start a new worktree."
  cm ide      "Open a worktree in $EDITOR_CMD."
  cm cd       "Print a worktree path."
  cm list     "List active or archived worktrees."
  cm archive  "Put a worktree away (keeps branch)."
  cm restore  "Restore an archived branch."
  cm clone    "Add a GitHub repo to the store."
  cm agents   "Manage agent identities."
  cm config   "Editor, org, profile, shared stack."
  cm init     "Create a local or shared profile."
  cm status   "Quick store glance."
  cm doctor   "Deep health check."
  cm rename   "Rename a worktree's branch."
  cm sync     "Fetch latest for every repo."
  cm clean    "Remove orphans (dry-run; --yes applies)."
  cm remove   "Delete a branch or repo permanently."
  cm update   "Refresh install / sync."
  echo
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

# Parse wt-progress:label:pct lines and git-style % updates; pass everything else through.
_progress_filter(){
  local label=$1 line pl pct p
  while IFS= read -r line; do
    case "$line" in
      wt-progress:*)
        pl=${line#wt-progress:}; pct=${pl##*:}; pl=${pl%:*}
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
_progress_run(){
  local label=$1; shift
  local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/wt.$$.out")
  { "$@" 2>&1 | tr '\r' '\n' | _progress_filter "$label"; } >"$tmp"
  local rc=${PIPESTATUS[0]}
  PROGRESS_OUT=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"
  return "$rc"
}

_spin_run(){ local msg=$1; shift; local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/wt.$$.out")
  ( "$@" >"$tmp" 2>&1 ) & local pid=$! i=0 fr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  if [ -t 1 ]; then printf '\e[?25l'; while kill -0 "$pid" 2>/dev/null; do printf '\r\e[2K  %s%s%s %s' "$GRN" "${fr:$((i%10)):1}" "$N" "$msg"; i=$((i+1)); sleep 0.08; done; printf '\r\e[2K\e[?25h'; fi
  wait "$pid"; local rc=$?; SPIN_OUT=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"; return $rc; }
