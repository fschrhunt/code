#!/usr/bin/env bash
# palette — Workframe truecolor themes
#
# Color vars are consumed by ui/frontend/backend; when this file is linted
# alone shellcheck cannot see those uses.
# shellcheck disable=SC2034

# WORKFRAME_THEME may be `dark`, `light`, or `auto` (the default). Auto uses
# COLORFGBG when a terminal provides it, then safely prefers the dark theme.
# Terminal background detection is not standardized, so an explicit theme is
# always available for terminals that do not export COLORFGBG.
_theme(){
  case "${WORKFRAME_THEME:-auto}" in
    dark|light) printf '%s' "$WORKFRAME_THEME";;
    ""|auto)
      local background=${COLORFGBG:-}
      background=${background##*;}
      case "$background" in
        7|9|15) printf 'light';;
        *) printf 'dark';;
      esac
      ;;
    *) printf 'dark';;
  esac
}

WORKFRAME_THEME_RESOLVED=$(_theme)
if [ "$WORKFRAME_THEME_RESOLVED" = light ]; then
  # Deep hues retain contrast on white and pale terminal backgrounds.
  GUM_TEAL="#006d77"
  GUM_GREY="#5f6368"
  GUM_WHITE="#111827"
  GUM_ACID="#536000"
  _WF_DIM_RGB='95;99;104'
  _WF_ACCENT_RGB='83;96;0'
  _WF_TEAL_RGB='0;109;119'
  _WF_TEXT_RGB='17;24;39'
  _WF_YELLOW_RGB='134;84;0'
  _WF_RED_RGB='186;26;26'
else
  # Bright hues retain contrast on black and dark terminal backgrounds.
  GUM_TEAL="#5ecacb"
  GUM_GREY="#aaaaaa"
  GUM_WHITE="#ffffff"
  GUM_ACID="#f0fb29"
  _WF_DIM_RGB='170;170;170'
  _WF_ACCENT_RGB='240;251;41'
  _WF_TEAL_RGB='94;202;203'
  _WF_TEXT_RGB='255;255;255'
  _WF_YELLOW_RGB='252;186;3'
  _WF_RED_RGB='255;119;117'
fi
GUMC="$GUM_ACID"

# Detection is captured once, at source time, so the decision below stays a pure
# function of (WORKFRAME_COLOR, stdout-is-a-terminal) and can be tested without a
# TTY.
_WF_STDOUT_TTY=0; [ -t 1 ] && _WF_STDOUT_TTY=1
# WORKFRAME_COLOR forces color off (0) or on (1) regardless of the TTY; unset
# falls back to detection. NO_COLOR follows the community convention. An
# explicit WORKFRAME_COLOR setting wins so callers can intentionally override
# a shell-wide NO_COLOR preference.
_color_on(){
  case "${WORKFRAME_COLOR:-}" in
    0) return 1;;
    1) return 0;;
  esac
  [ -z "${NO_COLOR:-}" ] || return 1
  [ "$_WF_STDOUT_TTY" = 1 ]
}
if _color_on; then
  B=$'\e[1m'; N=$'\e[0m'
  # Direct truecolor — do not go through 256-color approximation.
  DIM=$'\e[38;2;'"$_WF_DIM_RGB"'m'
  GRN=$'\e[38;2;'"$_WF_ACCENT_RGB"'m'
  ACID_BG=$'\e[48;2;'"$_WF_ACCENT_RGB"'m'
  CYN=$'\e[38;2;'"$_WF_TEAL_RGB"'m'
  W=$'\e[1;38;2;'"$_WF_TEXT_RGB"'m'
  YEL=$'\e[38;2;'"$_WF_YELLOW_RGB"'m'
  RED=$'\e[38;2;'"$_WF_RED_RGB"'m'
  AC=$GRN
else B= N= DIM= GRN= ACID_BG= CYN= W= YEL= RED= AC=; fi
ok(){   printf '  %s✓%s %s\n' "$GRN" "$N" "$*"; }
warn(){ printf '  %s•%s %s\n' "$YEL" "$N" "$*"; }
err(){  printf '  %s✗%s %s\n' "$RED" "$N" "$*" >&2; }
die(){  err "$*"; exit 1; }
banner(){ printf '\n  %s%s%s\n' "$W" "${1:-}" "$N"; }
