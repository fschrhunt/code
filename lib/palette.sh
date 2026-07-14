#!/usr/bin/env bash
# palette — exact Greptile CLI RGB (sampled from screenshot glyph interiors)

# Commands / examples teal  #5ecacb = RGB(94,202,203)
# Descriptions grey         #aaaaaa = RGB(170,170,170)
# Section headers / hover   #ffffff = RGB(255,255,255)
# Logo / title mint         #3adea1 = RGB(58,222,161)
GUM_TEAL="#5ecacb"
GUM_GREY="#aaaaaa"
GUM_WHITE="#ffffff"
GUM_MINT="#3adea1"
GUMC="$GUM_MINT"

if [ -t 1 ] || [ "${WT_COLOR:-0}" = 1 ]; then
  B=$'\e[1m'; N=$'\e[0m'
  # Direct truecolor — do not go through 256-color approximation
  DIM=$'\e[38;2;170;170;170m'
  GRN=$'\e[38;2;58;222;161m'
  CYN=$'\e[38;2;94;202;203m'
  W=$'\e[1;38;2;255;255;255m'
  YEL=$'\e[38;5;179m'; RED=$'\e[38;5;174m'; AC=$GRN
else B= N= DIM= GRN= CYN= W= YEL= RED= AC=; fi
ok(){   printf '  %s✓%s %s\n' "$GRN" "$N" "$*"; }
warn(){ printf '  %s•%s %s\n' "$YEL" "$N" "$*"; }
err(){  printf '  %s✗%s %s\n' "$RED" "$N" "$*" >&2; }
die(){  err "$*"; exit 1; }
banner(){ printf '\n  %s%s%s\n' "$W" "${1:-}" "$N"; }
