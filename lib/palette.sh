#!/usr/bin/env bash
# palette — workframe truecolor theme
#
# Color vars are consumed by ui/frontend/backend; when this file is linted
# alone shellcheck cannot see those uses.
# shellcheck disable=SC2034

# Commands / examples teal  #5ecacb = RGB(94,202,203)
# Descriptions grey         #aaaaaa = RGB(170,170,170)
# Section headers / hover   #ffffff = RGB(255,255,255)
# Brand accent acid         #f0fb29 = RGB(240,251,41)
GUM_TEAL="#5ecacb"
GUM_GREY="#aaaaaa"
GUM_WHITE="#ffffff"
GUM_ACID="#f0fb29"
GUMC="$GUM_ACID"

# Detection is captured once, at source time, so the decision below stays a pure
# function of (WORKFRAME_COLOR, stdout-is-a-terminal) and can be tested without a
# TTY.
_WF_STDOUT_TTY=0; [ -t 1 ] && _WF_STDOUT_TTY=1
# WORKFRAME_COLOR forces color off (0) or on (1) regardless of the TTY; unset
# falls back to detection. An explicit 0 must win over an attached terminal so
# agents and log capture can get clean, escape-free output.
_color_on(){
  case "${WORKFRAME_COLOR:-}" in
    0) return 1;;
    1) return 0;;
  esac
  [ "$_WF_STDOUT_TTY" = 1 ]
}
if _color_on; then
  B=$'\e[1m'; N=$'\e[0m'
  # Direct truecolor — do not go through 256-color approximation
  DIM=$'\e[38;2;170;170;170m'
  GRN=$'\e[38;2;240;251;41m'
  ACID_BG=$'\e[48;2;240;251;41m'
  CYN=$'\e[38;2;94;202;203m'
  W=$'\e[1;38;2;255;255;255m'
  YEL=$'\e[38;5;179m'; RED=$'\e[38;5;174m'; AC=$GRN
else B= N= DIM= GRN= ACID_BG= CYN= W= YEL= RED= AC=; fi
ok(){   printf '  %s✓%s %s\n' "$GRN" "$N" "$*"; }
warn(){ printf '  %s•%s %s\n' "$YEL" "$N" "$*"; }
err(){  printf '  %s✗%s %s\n' "$RED" "$N" "$*" >&2; }
die(){  err "$*"; exit 1; }
banner(){ printf '\n  %s%s%s\n' "$W" "${1:-}" "$N"; }
