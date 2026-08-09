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

# Help is the primary product surface: commands first, prompts when helpful.
_help(){
  _header
  printf '\n\n  %sWorkframe — isolated Git worktrees for parallel work.%s\n' "$W" "$N"
  printf '  %sUse %sworkframe%s or %swf%s. Commands prompt for omitted safe details when you are at a terminal.%s\n' "$DIM" "$GRN" "$N" "$GRN" "$N" "$N"

  printf '\n  %sStart here%s\n' "$W" "$N"
  printf '    %sworkframe init%s                          %sbootstrap a local store%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe setup --local%s                 %screate or update a local store%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe clone <owner/repo | url | path>%s\n' "$GRN" "$N"
  printf '    %sworkframe new <repo> <task>%s\n' "$GRN" "$N"

  printf '\n  %sDaily work%s\n' "$W" "$N"
  printf '    %sworkframe list%s                         %sshow active workspaces%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe open <selector>%s              %sopen a workspace in the configured editor%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe path <selector>%s              %sprint a workspace path%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe current%s                      %sshow the current workspace context%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe resume <selector>%s            %sopen active work or restore it%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe archive <selector> --yes%s     %spause work; branch is kept%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe restore <repo> <branch>%s\n' "$GRN" "$N"

  printf '\n  %sManage%s\n' "$W" "$N"
  printf '    %sworkframe repos%s  %sworkframe sync [<repo> | --all]%s\n' "$GRN" "$N" "$GRN" "$N"
  printf '    %sworkframe status%s  %sworkframe doctor%s  %sworkframe config%s\n' "$GRN" "$N" "$GRN" "$N" "$GRN" "$N"
  printf '    %sworkframe dashboard%s                    %sactive work and next actions%s\n' "$GRN" "$N" "$DIM" "$N"

  printf '\n  %sMore%s  %sworkframe help --agent%s  %sfull command reference and scripting notes%s\n' \
    "$W" "$N" "$GRN" "$N" "$DIM" "$N"
}

# The complete command surface. Keep it accurate — this is the detailed
# reference for scripts and coding agents.
_help_agent(){
  printf '\n  %sWorkframe — non-interactive interface%s\n' "$W" "$N"
  printf '  %sSet WORKFRAME_COLOR=0 or NO_COLOR=1 for plain output. WORKFRAME_THEME=light|dark selects a color theme.%s\n' "$DIM" "$N"
  printf '  %swf is the same executable — every command below works under either name.%s\n' "$DIM" "$N"

  printf '\n  %sSet up%s\n' "$W" "$N"
  printf '    %sworkframe setup --local --root <path> [--editor <cmd>] [--org <name>]%s\n' "$GRN" "$N"
  printf '    %sworkframe init [--root <path>] [--editor <cmd>] [--org <name>]%s\n' "$GRN" "$N"

  printf '\n  %sRepositories%s\n' "$W" "$N"
  printf '    %sworkframe clone <owner/repo | url | path>%s\n' "$GRN" "$N"
  printf '    %sworkframe repos%s                        %sone canonical repo name per line%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe sync [<repo> | --all]%s\n' "$GRN" "$N"
  printf '    %sworkframe remove repo <repo> --yes [--force]%s\n' "$GRN" "$N"

  printf '\n  %sWorkspaces%s\n' "$W" "$N"
  printf '    %sworkframe new <repo> <task>%s\n' "$GRN" "$N"
  printf '    %sworkframe list [archived]%s\n' "$GRN" "$N"
  printf '    %sworkframe list [archived] [--repo <name>] [--dirty] [--json]%s\n' "$GRN" "$N"
  printf '    %sworkframe worktrees [--json]%s           %sTSV by default: repo, city, path, branch%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe path <selector>%s              %sprints the workspace path%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe current [--json]%s             %sshows current-directory workspace context%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe run <selector> -- <command>%s  %sruns a command inside a workspace%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe resume <selector>%s            %sopens active work or restores archived work%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe rename <selector> <feature>%s\n' "$GRN" "$N"
  printf '    %sworkframe open <selector>%s              %sopens the configured editor%s\n' "$GRN" "$N" "$DIM" "$N"

  printf '\n  %sLifecycle%s  %s(archive is reversible; the rest are permanent)%s\n' "$W" "$N" "$DIM" "$N"
  printf '    %sworkframe archive <selector> --yes [--force] [--json]%s  %s--force discards uncommitted work%s\n' "$GRN" "$N" "$DIM" "$N"
  printf '    %sworkframe restore [--json] <repo> <branch>%s\n' "$GRN" "$N"
  printf '    %sworkframe remove branch <repo> <branch> --yes%s\n' "$GRN" "$N"
  printf '    %sworkframe clean [--yes]%s                %sno --yes is a dry run%s\n' "$GRN" "$N" "$DIM" "$N"

  printf '\n  %sHealth%s\n' "$W" "$N"
  printf '    %sworkframe status%s  %sworkframe doctor%s  %sworkframe update%s  %sworkframe version%s\n' \
    "$GRN" "$N" "$GRN" "$N" "$GRN" "$N" "$GRN" "$N"
  printf '    %sworkframe dashboard%s  %sworkframe doctor --fix%s  %sworkframe completion <bash|zsh|fish>%s\n' \
    "$GRN" "$N" "$GRN" "$N" "$GRN" "$N"

  printf '\n  %sSelectors%s  %s(a workspace, named any of these ways)%s\n' "$W" "$N" "$DIM" "$N"
  printf '    %s<city>%s  %s<repo>/<task>%s  %s<repo>/<city>%s  %s<absolute path>%s\n' \
    "$GRN" "$N" "$GRN" "$N" "$GRN" "$N" "$GRN" "$N"

  printf '\n  %sNotes%s\n' "$W" "$N"
  printf '    %s• Destructive verbs require --yes without a terminal; they never assume consent.%s\n' "$DIM" "$N"
  printf '    %s• A workspace is task-owned; choose the agent harness inside the workspace.%s\n' "$DIM" "$N"
  printf '    %s• Exit 0 success, 3 refused-because-dirty, other non-zero failure.%s\n' "$DIM" "$N"
  printf '    %s• Use path, not cd: the optional shell integration makes cd change%s\n' "$DIM" "$N"
  printf '      %sdirectory instead of printing, under both names. path is never intercepted.%s\n' "$DIM" "$N"
  printf '    %s• status, repos, worktrees, list, archive, and restore offer JSON where documented.%s\n' "$DIM" "$N"
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
