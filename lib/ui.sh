#!/usr/bin/env bash
# UI: logo + landing, help text, gum helpers (with a plain fallback), progress.

# Controlling terminal for the wizard (prefer `tty` over bare /dev/tty).
_wiz_tty(){
  local t
  t=$(tty 2>/dev/null) || t=
  case "$t" in
    not\ a\ tty|'') t=/dev/tty;;
  esac
  printf '%s' "$t"
}

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
  if [ "${WT_PROFILE_TYPE:-local}" = local ]; then
    status="Local profile · editor ${EDITOR_CMD:-cursor}"
  else
    status="Shared profile · editor ${EDITOR_CMD:-cursor}"
  fi
  T[4]="${GRN}wt${N} ${DIM}v${ver}${N}"
  T[6]="${W}Isolated git worktrees from your terminal.${N}"
  T[7]="${DIM}${status}${N}"
  echo; local i; for i in "${!LOGO[@]}"; do printf '  %s%-28s%s  %s\n' "$GRN" "${LOGO[i]}" "$N" "${T[i]:-}"; done; echo
}

# Action-scoped help (Greptile layout): section titles at margin, commands indented.
_help(){
  _header
  local col=30
  sec(){ printf '  %s%s%s\n\n' "$W" "$1" "$N"; }
  cm(){ printf '    %s%-'${col}'s%s%s%s%s\n' "$CYN" "$1" "$N" "$DIM" "$2" "$N"; }
  sec WORK
  cm new      "Start a new worktree to work in."
  cm ide      "Open a worktree in $EDITOR_CMD (new IDE window)."
  cm cd       "Jump into a worktree in the terminal."
  cm list     "List active worktrees (or: wt list archived)."
  cm archive  "Put a worktree away — keeps the branch."
  cm restore  "Bring an archived worktree back."
  cm clone    "Add a repo from GitHub to the store."
  echo
  sec SETTINGS
  cm agents   "List, add, or remove configured agents."
  cm config   "Editor, org, profile, and shared stack."
  cm init     "Create a local or shared profile."
  cm doctor   "Check that everything's working."
  echo
  sec MORE
  cm rename   "Rename a worktree's branch."
  cm sync     "Pull the latest for every repo."
  cm clean    "Remove safe remote-deleted worktrees."
  cm remove   "Permanently delete an archived worktree or repo."
  cm update   "Refresh install / sync."
  echo
}

# ---- gum helpers (non-wizard pickers) ----
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
_input(){ if _has_gum; then _gum_env gum input --header "$1" --placeholder "${2:-}" --prompt "❯ " --prompt.foreground "$GUMC"; else printf '  %s%s%s ' "$B" "$1" "$N" >&2; local v; read -r v; printf '%s' "$v"; fi; }
_confirm(){ if _has_gum; then _gum_env gum confirm "$1"; else printf '  %s %s[y/N]%s ' "$1" "$DIM" "$N" >&2; local a; read -r a; case "$a" in y|Y) return 0;; *) return 1;; esac; fi; }

# ---- wizard menu (no gum) — exact truecolor, greptile layout ----
# stdin lines:  value<TAB>title<TAB>description
#   section:    __hdr__<TAB>WORK<TAB>
#   command:    new<TAB>new<TAB>start a new worktree
_wiz_section(){ printf '__hdr__\t%s\t\n' "$1"; }
_wiz_item(){ printf '%s\t%s\t%s\n' "$1" "$1" "$2"; }

_wizard_pick(){
  local h="${1:-what would you like to do?}"
  local -a vals=() titles=() descs=()
  local v t d
  while IFS=$'\t' read -r v t d || [ -n "${v:-}" ]; do
    [ -z "${v:-}" ] && continue
    vals+=("$v"); titles+=("$t"); descs+=("$d")
  done
  local n=${#vals[@]}
  [ "$n" -gt 0 ] || return 1

  # land on first real command
  local idx=0
  while [ "$idx" -lt "$n" ] && [ "${vals[idx]}" = "__hdr__" ]; do idx=$((idx+1)); done
  [ "$idx" -lt "$n" ] || return 1

  local tty lines=0 key
  tty=$(_wiz_tty)

  _wiz_move(){
    local dir=$1 j=$idx
    while true; do
      j=$((j + dir))
      [ "$j" -lt 0 ] && j=$((n-1))
      [ "$j" -ge "$n" ] && j=0
      [ "${vals[j]}" != "__hdr__" ] && { idx=$j; return; }
      [ "$j" = "$idx" ] && return
    done
  }

  _wiz_draw(){
    local i=0
    printf '  %s%s%s\n\n' "$DIM" "$h" "$N" > "$tty"
    lines=2
    for ((i=0; i<n; i++)); do
      if [ "${vals[i]}" = "__hdr__" ]; then
        [ "$i" -gt 0 ] && { printf '\n' > "$tty"; lines=$((lines+1)); }
        printf '  %s%s%s\n' "$W" "${titles[i]}" "$N" > "$tty"
        lines=$((lines+1))
      elif [ "$i" = "$idx" ]; then
        printf '  %s❯ %-10s %s%s\n' "$W" "${titles[i]}" "${descs[i]}" "$N" > "$tty"
        lines=$((lines+1))
      else
        printf '    %s%-10s%s %s%s%s\n' "$CYN" "${titles[i]}" "$N" "$DIM" "${descs[i]}" "$N" > "$tty"
        lines=$((lines+1))
      fi
    done
  }

  # Read bytes after ESC. macOS /bin/bash 3.2 rejects fractional read -t (0.05);
  # use integer -t 1 for "byte follows ESC?" then blocking reads for the rest.
  _wiz_read_esc(){
    local n1 c seq= rc
    if IFS= read -rsn1 -t 1 n1 < "$tty" 2>/dev/null; then
      rc=0
    else
      rc=$?
    fi
    [ "$rc" -ne 0 ] && { WIZ_ESC=; return; }
    case "$n1" in
      '[')
        while IFS= read -rsn1 c < "$tty"; do
          seq+="$c"
          case "$c" in
            [A-Za-z~]) break;;
          esac
        done
        WIZ_ESC="[$seq"
        ;;
      O) # application-cursor mode: ESC O A/B/C/D
        IFS= read -rsn1 c < "$tty" || c=
        WIZ_ESC="O$c"
        ;;
      *) WIZ_ESC="$n1";;
    esac
  }

  _wiz_drain_pending(){
    local old junk n=0
    old=$(stty -f "$tty" -g 2>/dev/null) || return
    stty -f "$tty" -icanon time 0 min 0 2>/dev/null || { stty -f "$tty" "$old" 2>/dev/null; return; }
    while IFS= read -rsn1 junk < "$tty" 2>/dev/null; do n=$((n+1)); done
    stty -f "$tty" "$old" 2>/dev/null
  }

  _wiz_drain_paste(){
    # Consume bracketed paste until ESC [ 201 ~
    local c
    while IFS= read -rsn1 c < "$tty"; do
      if [ "$c" = $'\e' ]; then
        _wiz_read_esc
        case "$WIZ_ESC" in
          \[201~) return;;
        esac
      fi
    done
  }

  printf '\e[?25l' > "$tty"
  _wiz_draw
  while true; do
    IFS= read -rsn1 key < "$tty" || { printf '\e[?25h' > "$tty"; return 1; }
    case "$key" in
      $'\e')
        _wiz_read_esc
        case "$WIZ_ESC" in
          \[A|\[D|OA|OD) _wiz_move -1; _wiz_drain_pending;;
          \[B|\[C|OB|OC) _wiz_move 1; _wiz_drain_pending;;
          \[200~) _wiz_drain_paste; continue;;
          \[*)
            case "${WIZ_ESC: -1}" in
              A|D) _wiz_move -1; _wiz_drain_pending;;
              B|C) _wiz_move 1; _wiz_drain_pending;;
              *) continue;;
            esac
            ;;
          *) continue;;
        esac
        ;;
      k|K) _wiz_move -1; _wiz_drain_pending;;
      j|J) _wiz_move 1; _wiz_drain_pending;;
      q|Q|$'\x03') printf '\e[?25h' > "$tty"; return 1;;
      $'\n'|$'\r')
        printf '\e[?25h' > "$tty"
        printf '%s' "${vals[idx]}"
        return 0
        ;;
      *)
        # Any unexpected printable = drain the flood, do not accept
        _wiz_drain_pending
        continue
        ;;
    esac
    printf '\e[%dA\e[0J' "$lines" > "$tty"
    _wiz_draw
  done
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
