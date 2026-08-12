#!/usr/bin/env bash
# Palette — preserve the terminal's own foreground and background. Workframe
# has no semantic color states; machine-readable commands never use attributes.
# shellcheck disable=SC2034

B= N= W= DIM= GRN= ACID_BG= CYN= YEL= RED= AC=

ok(){ printf '%s\n' "$*"; }
warn(){ printf '%s\n' "$*" >&2; }
err(){ printf '%s\n' "$*" >&2; }
die(){ err "$*"; exit 1; }
banner(){ :; }
