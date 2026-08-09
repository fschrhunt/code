#!/usr/bin/env bats
# Prompting is gated on stdin + stderr, never stdout.
#
# Every prompt helper renders to stderr and reads stdin, so a caller may capture
# its result with $( ) — which makes stdout a pipe even in a fully interactive
# session. Gating on stdout made `workframe new` refuse to prompt for an agent
# and die with the non-interactive usage error. These tests pin the seam without
# needing a real terminal.

load helper

_load_libs() {
  local lib="${BATS_TEST_DIRNAME}/../lib"
  WORKFRAME_COLOR=0
  # shellcheck source=../lib/config.sh
  . "$lib/config.sh"
  # shellcheck source=../lib/palette.sh
  . "$lib/palette.sh"
  # shellcheck source=../lib/ui.sh
  . "$lib/ui.sh"
  # shellcheck source=../lib/agents.sh
  . "$lib/agents.sh"
}

@test "_interactive ignores stdout and reports false without a terminal" {
  _load_libs
  declare -F _interactive >/dev/null
  # bats attaches no terminal to any descriptor.
  run _interactive
  [ "$status" -ne 0 ]
}

@test "resolve_agent prompts when its result is captured by command substitution" {
  _load_libs
  VALID_AGENTS="alpha beta"
  # Stand in for a terminal; the picker itself is exercised by command helpers.
  _interactive() { return 0; }
  _choose() { printf 'beta'; }
  # The regression: stdout here is a pipe, exactly as in `agent=$(_resolve_agent …)`.
  local picked
  picked=$(_resolve_agent "")
  [ "$picked" = "beta" ]
}

@test "resolve_agent still refuses without a terminal instead of guessing" {
  _load_libs
  VALID_AGENTS="alpha beta"
  # Real _interactive, no terminal: the usage error must still win.
  local picked="" rc=0
  picked=$(_resolve_agent "" 2>/dev/null) || rc=$?
  [ "$rc" -ne 0 ]
  [ -z "$picked" ]
}

@test "resolve_agent prefers an explicit name over prompting" {
  _load_libs
  VALID_AGENTS="alpha beta"
  _interactive() { return 0; }
  _choose() { printf 'beta'; }
  local picked
  picked=$(_resolve_agent "alpha")
  [ "$picked" = "alpha" ]
}

@test "input discards stdout when the prompt program fails" {
  _load_libs
  # A crashing gum prints a panic trace to stdout and exits non-zero; that trace
  # must never be returned as though the user had typed it.
  _has_gum() { return 0; }
  _gum_env() { printf 'Caught panic:\n\nruntime error: makeslice: len out of range\n'; return 2; }
  local answer
  answer=$(_input "Workframe root" "/tmp/fallback")
  [ "$answer" = "/tmp/fallback" ]
}

@test "input keeps a successful answer" {
  _load_libs
  _has_gum() { return 0; }
  _gum_env() { printf 'typed-value'; }
  local answer
  answer=$(_input "Workframe root" "/tmp/fallback")
  [ "$answer" = "typed-value" ]
}

@test "WORKFRAME_COLOR=0 forces plain output even with a terminal on stdout" {
  _load_libs
  declare -F _color_on >/dev/null
  _WF_STDOUT_TTY=1
  WORKFRAME_COLOR=0
  run _color_on
  [ "$status" -ne 0 ]
}

@test "WORKFRAME_COLOR=1 forces color without a terminal" {
  _load_libs
  _WF_STDOUT_TTY=0
  WORKFRAME_COLOR=1
  run _color_on
  [ "$status" -eq 0 ]
}

@test "unset WORKFRAME_COLOR falls back to terminal detection" {
  _load_libs
  unset WORKFRAME_COLOR
  unset NO_COLOR
  _WF_STDOUT_TTY=1
  run _color_on
  [ "$status" -eq 0 ]
  _WF_STDOUT_TTY=0
  run _color_on
  [ "$status" -ne 0 ]
}

@test "NO_COLOR disables automatic color but an explicit setting wins" {
  _load_libs
  _WF_STDOUT_TTY=1
  unset WORKFRAME_COLOR
  NO_COLOR=1
  run _color_on
  [ "$status" -ne 0 ]
  WORKFRAME_COLOR=1
  run _color_on
  [ "$status" -eq 0 ]
}

@test "light and dark themes select distinct accessible truecolor palettes" {
  local lib="${BATS_TEST_DIRNAME}/../lib/palette.sh"
  run bash -c "WORKFRAME_COLOR=1 WORKFRAME_THEME=light . '$lib'; printf '%s|%s|%s' \"\$W\" \"\$GRN\" \"\$ACID_BG\""
  [ "$status" -eq 0 ]
  [ "$output" = $'\e[1;38;2;17;24;39m|\e[38;2;83;96;0m|\e[48;2;83;96;0m' ]
  run bash -c "WORKFRAME_COLOR=1 WORKFRAME_THEME=dark . '$lib'; printf '%s|%s|%s' \"\$W\" \"\$GRN\" \"\$ACID_BG\""
  [ "$status" -eq 0 ]
  [ "$output" = $'\e[1;38;2;255;255;255m|\e[38;2;240;251;41m|\e[48;2;240;251;41m' ]
}

@test "first-run next steps name real command forms" {
  local frontend="${BATS_TEST_DIRNAME}/../lib/frontend.sh"
  local hint found=0
  while read -r hint; do
    [ -n "$hint" ] || continue
    found=$((found + 1))
    [[ "$hint" == workframe\ * ]] \
      || { echo "next-steps hint is not a command: $hint"; return 1; }
  done < <(awk '/^_print_next_steps\(\)/{f=1} f&&/^}/{f=0} f' "$frontend" \
    | sed -n 's/.*%s\(workframe [^%]*\)%s.*/\1/p')
  [ "$found" -eq 3 ]
}
