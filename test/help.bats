#!/usr/bin/env bats

load helper

@test "help output byte-matches the golden fixture" {
  local output_file="$BATS_TEST_TMPDIR/help.out"
  "$WORKSPACES" help > "$output_file"
  diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$output_file"
}

@test "help describes only repositories and sibling task worktrees" {
  run "$WORKSPACES" help
  [ "$status" -eq 0 ]
  [[ "$output" == *'workspaces new <repo> <task>'* ]]
  [[ "$output" == *'siblings, such as pi-fix-auth'* ]]
  [[ "$output" != *'archive'* ]]
  [[ "$output" != *'agent'* ]]
}
