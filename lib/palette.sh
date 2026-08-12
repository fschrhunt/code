#!/usr/bin/env bash
# Palette — monochrome terminal output. Workframe keeps decoration out of data
# output; color only improves diagnostics for terminals that explicitly allow it.
# shellcheck disable=SC2034

_color_on(){
  case "${WORKFRAME_COLOR:-}" in
    0) return 1;;
    1) return 0;;
  esac
  [ -z "${NO_COLOR:-}" ] && [ -t 1 ]
}

if _color_on; then
  B=$'\e[1m'; N=$'\e[0m'
  W=$'\e[38;2;255;255;255m'
  DIM=$W; GRN=$W; ACID_BG=; CYN=$W; YEL=$W; RED=$W; AC=$W
else
  B= N= W= DIM= GRN= ACID_BG= CYN= YEL= RED= AC=
fi

ok(){ printf '%s%s\n' "$W" "$*"; }
warn(){ printf '%s%s\n' "$W" "$*" >&2; }
err(){ printf '%s%s\n' "$W" "$*" >&2; }
die(){ err "$*"; exit 1; }
banner(){ :; }
