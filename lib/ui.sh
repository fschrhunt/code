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

# Help layout: the interactive product surface with its small support interface.
_help(){
  _header
  printf '\n\n  %sWorkframe is an interactive workspace wizard.%s\n' "$W" "$N"
  printf '  %sRun %sworkframe%s or %swf%s in a terminal. Start with the outcome you want, then answer only the needed prompts.%s\n' "$DIM" "$GRN" "$N" "$GRN" "$N" "$N"
  printf '\n  %sThe home screen guides you to:%s\n' "$W" "$N"
  printf '    %s•%s start or continue a workspace\n' "$GRN" "$N"
  printf '    %s•%s manage its reversible lifecycle\n' "$GRN" "$N"
  printf '    %s•%s manage repositories, settings, and agents\n' "$GRN" "$N"
  printf '    %s•%s check health or update Workframe\n' "$GRN" "$N"
  printf '\n  %sSupport:%s  %sworkframe help%s  %sworkframe version%s\n' \
    "$DIM" "$N" "$GRN" "$N" "$GRN" "$N"
  printf '  %sAutomation uses the internal backend interface; see the configuration reference.%s\n' "$DIM" "$N"
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
_temp_output_file(){
  local tmpdir=${TMPDIR:-/tmp}
  [ -d "$tmpdir" ] || return 1
  (umask 077; mktemp "$tmpdir/workframe.XXXXXX.out")
}

_progress_run(){
  local label=$1; shift
  local tmp
  tmp=$(_temp_output_file 2>/dev/null) || {
    err "could not create a secure temporary file"
    return 1
  }
  { "$@" 2>&1 | tr '\r' '\n' | _progress_filter "$label"; } >"$tmp"
  local rc=${PIPESTATUS[0]}
  # shellcheck disable=SC2034
  PROGRESS_OUT=$(cat "$tmp" 2>/dev/null); rm -f -- "$tmp"
  return "$rc"
}

_spin_run(){ local msg=$1; shift; local tmp
  tmp=$(_temp_output_file 2>/dev/null) || {
    err "could not create a secure temporary file"
    return 1
  }
  ( "$@" >"$tmp" 2>&1 ) & local pid=$! i=0 fr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  if [ -t 1 ]; then printf '\e[?25l'; while kill -0 "$pid" 2>/dev/null; do printf '\r\e[2K  %s%s%s %s' "$GRN" "${fr:$((i%10)):1}" "$N" "$msg"; i=$((i+1)); sleep 0.08; done; printf '\r\e[2K\e[?25h'; fi
  wait "$pid"; local rc=$?
  # shellcheck disable=SC2034
  SPIN_OUT=$(cat "$tmp" 2>/dev/null); rm -f -- "$tmp"; return $rc; }
