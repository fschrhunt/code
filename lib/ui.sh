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
  printf '  %sScripts and coding agents:%s  %sworkframe help --agent%s\n' "$DIM" "$N" "$GRN" "$N"
}

# The non-interactive surface, in full. Coding agents and scripts get the same
# capabilities as a person driving the wizard; this is where they discover them.
# Keep it accurate — it is the only command catalogue Workframe ships.
_help_agent(){
  printf '\n  %sWorkframe — non-interactive interface%s\n' "$W" "$N"
  printf '  %sEvery wizard action has a command form. Set WORKFRAME_COLOR=0 for plain output.%s\n' "$DIM" "$N"
  printf '  %swf is the same executable — every command below works under either name.%s\n' "$DIM" "$N"

  printf '\n  %sSet up%s\n' "$W" "$N"
  printf '    %sworkframe setup --local --root <path> --agent <name> [--editor <cmd>] [--org <name>]%s\n' "$GRN" "$N"
  printf '    %sworkframe agents [list | add <name> | remove <name>]%s\n' "$GRN" "$N"

  printf '\n  %sRepositories%s\n' "$W" "$N"
  printf '    %sworkframe clone <owner/repo | url | path>%s\n' "$GRN" "$N"
  printf '    %sworkframe repos%s                        %sone canonical repo name per line%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe sync [<repo> | --all]%s\n' "$GRN" "$N"
  printf '    %sworkframe remove repo <repo> --yes [--force]%s\n' "$GRN" "$N"

  printf '\n  %sWorkspaces%s\n' "$W" "$N"
  printf '    %sworkframe new <repo> <feature> --agent <name>%s\n' "$GRN" "$N"
  printf '    %sworkframe list [archived]%s\n' "$GRN" "$N"
  printf '    %sworkframe worktrees%s                    %sTSV: agent, repo, city, path, branch%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe path <selector>%s              %sprints the workspace path%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe rename <selector> <feature>%s\n' "$GRN" "$N"
  printf '    %sworkframe open <selector>%s              %sopens the configured editor%s\n' "$GRN" "$N" "$DIM" "$N"

  printf '\n  %sLifecycle%s  %s(archive is reversible; the rest are permanent)%s\n' "$W" "$N" "$DIM" "$N"
  printf '    %sworkframe archive <selector> --yes [--force]%s  %s--force discards uncommitted work%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe restore <repo> <branch>%s\n' "$GRN" "$N"
  printf '    %sworkframe remove branch <repo> <branch> --yes%s\n' "$GRN" "$N"
  printf '    %sworkframe clean [--yes]%s                %sno --yes is a dry run%s\n' "$GRN" "$N" "$DIM" "$N"

  printf '\n  %sHealth%s\n' "$W" "$N"
  printf '    %sworkframe status%s  %sworkframe doctor%s  %sworkframe update%s  %sworkframe version%s\n' \
    "$GRN" "$N" "$GRN" "$N" "$GRN" "$N" "$GRN" "$N"

  printf '\n  %sSelectors%s  %s(a workspace, named any of these ways)%s\n' "$W" "$N" "$DIM" "$N"
  printf '    %s<city>%s  %s<repo>/<feature>%s  %s<agent>/<feature>%s  %s<agent>/<repo>/<city>%s  %s<absolute path>%s\n' \
    "$GRN" "$N" "$GRN" "$N" "$GRN" "$N" "$GRN" "$N" "$GRN" "$N"

  printf '\n  %sNotes%s\n' "$W" "$N"
  printf '    %s• Destructive verbs require --yes without a terminal; they never assume consent.%s\n' "$DIM" "$N"
  printf '    %s• --agent is required for new; WORKFRAME_AGENT sets it for a whole session.%s\n' "$DIM" "$N"
  printf '    %s• Exit 0 success, 3 refused-because-dirty, other non-zero failure.%s\n' "$DIM" "$N"
  printf '    %s• Use path, not cd: the optional shell integration makes cd change%s\n' "$DIM" "$N"
  printf '      %sdirectory instead of printing, under both names. path is never intercepted.%s\n' "$DIM" "$N"
  printf '    %s• Full reference: docs/reference/automation.md%s\n' "$DIM" "$N"
}

# ---- gum helpers (TTY fill-in when a flag/arg is missing) ----
# Can we prompt? Prompts read stdin and render to stderr (gum draws its UI on
# stderr; the plain fallback writes its menu there too). stdout is deliberately
# NOT tested: prompting functions are routinely captured with $( ), which makes
# stdout a pipe even in a fully interactive session. Rendering that targets
# stdout (progress bars, spinners, cursor control) still checks `-t 1`.
_interactive(){ [ -t 0 ] && [ -t 2 ]; }
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
    # A non-zero exit means cancelled (Esc/Ctrl-C) or crashed. Discard whatever
    # landed on stdout either way — a gum panic trace must never be mistaken for
    # something the user typed.
    v=$(_gum_env gum input --header "$header" --placeholder "${default}" --prompt "❯ " --prompt.foreground "$GUMC") || v=""
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
  if _interactive; then
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
