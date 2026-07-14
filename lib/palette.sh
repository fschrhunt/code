#!/usr/bin/env bash
# palette + status printers (Greptile-style: green accent, cyan commands, bold-white heads)

GUMC=78
if [ -t 1 ] || [ "${WT_COLOR:-0}" = 1 ]; then
  B=$'\e[1m'; N=$'\e[0m'; DIM=$'\e[38;5;244m'; GRN=$'\e[38;5;78m'; CYN=$'\e[38;5;81m'
  W=$'\e[1;97m'; YEL=$'\e[38;5;179m'; RED=$'\e[38;5;174m'; AC=$GRN
else B= N= DIM= GRN= CYN= W= YEL= RED= AC=; fi
ok(){   printf '  %s✓%s %s\n' "$GRN" "$N" "$*"; }
warn(){ printf '  %s•%s %s\n' "$YEL" "$N" "$*"; }
err(){  printf '  %s✗%s %s\n' "$RED" "$N" "$*" >&2; }
die(){  err "$*"; exit 1; }
banner(){ printf '\n  %s%s%s\n' "$W" "${1:-}" "$N"; }
