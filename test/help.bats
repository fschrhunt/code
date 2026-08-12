#!/usr/bin/env bats

load helper

@test "help output byte-matches the golden fixture" {
  local out="$BATS_TEST_TMPDIR/help.out"
  WORKFRAME_COLOR=0 "$WORKFRAME" help > "$out"
  diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$out"
}

@test "help lists the task-only workspace contract and migration command" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *'workframe new <repo> <task>'* ]]
  [[ "$output" == *'workframe migrate [--yes]'* ]]
  [[ "$output" != *'help --agent'* ]]
}
